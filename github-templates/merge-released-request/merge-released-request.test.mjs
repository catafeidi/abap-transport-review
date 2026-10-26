// Run with: node --test .github/scripts/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, createVerify, createHmac } from 'node:crypto';
import { appJwt, readRequest, signedText, signatureOf, checkSignature, notReady, run } from './merge-released-request.mjs';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const pem = privateKey.export({ type: 'pkcs1', format: 'pem' });
const SHA = 'a'.repeat(40);
const SECRET = 'shared-secret-of-sap';
const NOW = 1_800_000_000;

/** An event as the SAP report sends it: the fields, the time and the signature over them. */
function signed(over = {}, secret = SECRET) {
  const fields = { request: 'DEVK901853', pull_request: 24, sha: SHA, timestamp: NOW - 5, commit_title: 'DEVK901853 text (#24)', commit_message: 'body\nsecond line', ...over };
  const want = { request: fields.request, number: fields.pull_request, sha: fields.sha, timestamp: fields.timestamp, title: fields.commit_title, message: fields.commit_message };
  return { ...fields, signature: over.signature ?? signatureOf(secret, want) };
}
const good = signed();

test('the JWT is RS256, names the app, lives five minutes and its signature verifies', () => {
  const jwt = appJwt(123456, pem, 1_000_000);
  const [h, b, s] = jwt.split('.');
  assert.deepEqual(JSON.parse(Buffer.from(h, 'base64url')), { alg: 'RS256', typ: 'JWT' });
  assert.deepEqual(JSON.parse(Buffer.from(b, 'base64url')), { iat: 999_940, exp: 1_000_300, iss: '123456' });
  assert.ok(createVerify('RSA-SHA256').update(`${h}.${b}`).verify(publicKey, Buffer.from(s, 'base64url')));
});

test('the signature is HMAC-SHA256 over the fields in a fixed order, the message last (the ABAP report builds the same text)', () => {
  const want = readRequest(good);
  assert.equal(signedText(want), `DEVK901853\n24\n${SHA}\n${NOW - 5}\nDEVK901853 text (#24)\nbody\nsecond line`);
  assert.equal(signatureOf(SECRET, want), createHmac('sha256', SECRET).update(signedText(want), 'utf8').digest('hex'));
  // a fixed vector, so the ABAP side can be checked against it
  assert.equal(signatureOf('key', { request: 'DEVK900001', number: 1, sha: 'b'.repeat(40), timestamp: 1700000000, title: 'T (#1)', message: 'M' }),
    createHmac('sha256', 'key').update('DEVK900001\n1\n' + 'b'.repeat(40) + '\n1700000000\nT (#1)\nM').digest('hex'));
});

test('the event is checked before anything is asked of GitHub', () => {
  assert.equal(readRequest(good).number, 24);
  for (const bad of [{ request: 'DEVK90185' }, { request: 'devk901853' }, { request: 'DEVK901853; rm -rf' }, { pull_request: 0 }, { pull_request: '24' },
    { sha: 'abc' }, { sha: 'A'.repeat(40) }, { timestamp: 0 }, { timestamp: '1800000000' }, { signature: 'abc' }, { signature: 'g'.repeat(64) },
    { commit_title: 'a\nb' }, { commit_title: '' }, { commit_title: 'x'.repeat(251) }, { commit_message: 'x'.repeat(60001) }]) {
    assert.throws(() => readRequest({ ...good, ...bad }), /not valid/, JSON.stringify(bad).slice(0, 40));
  }
  assert.throws(() => readRequest(null), /not valid/);
  const noTitle = { ...good }; delete noTitle.commit_title;
  assert.throws(() => readRequest(noTitle), /commit_title/);
});

test('a valid, recent signature passes, upper-case hex too', () => {
  checkSignature(readRequest(good), SECRET, NOW);
  checkSignature(readRequest({ ...good, signature: good.signature.toUpperCase() }), SECRET, NOW);
  checkSignature(readRequest(signed({ timestamp: NOW - 600 })), SECRET, NOW);       // exactly at the limit
  checkSignature(readRequest(signed({ timestamp: NOW + 60 })), SECRET, NOW);        // a clock a minute ahead
});

test('every field is covered: change one after signing and it is refused', () => {
  for (const change of [{ request: 'DEVK901854' }, { pull_request: 25 }, { sha: 'b'.repeat(40) }, { timestamp: NOW - 4 }, { commit_title: 'other (#24)' }, { commit_message: 'other body' }]) {
    assert.throws(() => checkSignature(readRequest({ ...good, ...change }), SECRET, NOW), /signature of the event is not valid/, JSON.stringify(change).slice(0, 40));
  }
});

test('a wrong secret, no secret, an old event and a future event are refused', () => {
  assert.throws(() => checkSignature(readRequest(signed({}, 'another-secret')), SECRET, NOW), /not valid/);
  assert.throws(() => checkSignature(readRequest(good), '', NOW), /not set up/);
  assert.throws(() => checkSignature(readRequest(good), undefined, NOW), /not set up/);
  assert.throws(() => checkSignature(readRequest(signed({ timestamp: NOW - 601 })), SECRET, NOW), /older than 10 minutes/);
  assert.throws(() => checkSignature(readRequest(signed({ timestamp: NOW + 61 })), SECRET, NOW), /future/);
});

test('readiness: approved, no open comment, checks success or none', () => {
  assert.equal(notReady({ reviewDecision: 'APPROVED', unresolved: 0, checks: 'SUCCESS' }), null);
  assert.equal(notReady({ reviewDecision: 'APPROVED', unresolved: 0, checks: null }), null);
  assert.match(notReady({ reviewDecision: 'REVIEW_REQUIRED', unresolved: 0, checks: 'SUCCESS' }), /not approved/);
  assert.match(notReady({ reviewDecision: null, unresolved: 0, checks: 'SUCCESS' }), /no review/);
  assert.match(notReady({ reviewDecision: 'APPROVED', unresolved: 2, checks: 'SUCCESS' }), /2 review comment/);
  for (const c of ['PENDING', 'FAILURE', 'ERROR', 'EXPECTED']) assert.match(notReady({ reviewDecision: 'APPROVED', unresolved: 0, checks: c }), /checks are/);
});

/** A fake GitHub: records every call, answers what the test sets up. */
function github(over = {}) {
  const calls = [];
  const pull = { state: 'open', merged: false, title: 'DEVK901853 text', body: 'pr body', user: { login: 'author' }, head: { ref: 'review/DEVK901853', sha: SHA, repo: { full_name: 'O/R' } }, base: { ref: 'master' }, ...over.pull };
  const fetchImpl = async (url, init) => {
    const path = url.replace('https://api.github.com', '');
    const key = `${init.method} ${path.split('?')[0]}`;
    calls.push({ key, auth: init.headers.authorization, body: init.body ? JSON.parse(init.body) : undefined });
    const ok = (data, status = 200) => new Response(JSON.stringify(data), { status });
    if (key === 'GET /repos/O/R/installation') return ok({ id: 77 });
    if (key === 'POST /app/installations/77/access_tokens') return ok({ token: 'ghs_TOKEN' });
    if (key === 'GET /repos/O/R/pulls/24') return ok(pull);
    if (key === 'POST /graphql') return ok({ data: { repository: { pullRequest: { reviewDecision: 'APPROVED', reviewThreads: { nodes: [{ isResolved: true }] },
      commits: { nodes: [{ commit: { statusCheckRollup: { state: 'SUCCESS' } } }] }, ...over.graph } } } });
    if (key === 'PUT /repos/O/R/pulls/24/merge') return over.mergeStatus ? ok({ message: 'Repository rule violations found' }, over.mergeStatus) : ok({ sha: 'b'.repeat(40), merged: true });
    if (key === 'DELETE /repos/O/R/git/refs/heads/review/DEVK901853') return new Response(null, { status: over.deleteStatus ?? 204 });
    return ok({ message: 'unexpected ' + key }, 404);
  };
  return { fetchImpl, calls };
}
const env = { REPOSITORY: 'O/R', APP_ID: '1', APP_PRIVATE_KEY: pem, SAP_EVENT_SECRET: SECRET };
const event = (payload = good, sender = 'author') => ({ client_payload: payload, sender: { login: sender }, repository: { default_branch: 'master' } });
const go = (g, ev = event(), e = env) => run({ env: e, event: ev, fetchImpl: g.fetchImpl, now: NOW, log: () => {} });

test('merges with the token of the app, squash, at the released commit, with the title and message from SAP, then removes the branch', async () => {
  const g = github();
  const r = await go(g);
  assert.equal(r.merged, true);
  const merge = g.calls.find(c => c.key.startsWith('PUT'));
  assert.deepEqual(merge.body, { merge_method: 'squash', sha: SHA, commit_title: 'DEVK901853 text (#24)', commit_message: 'body\nsecond line' });
  assert.equal(merge.auth, 'Bearer ghs_TOKEN');
  const tokenCall = g.calls.find(c => c.key.includes('access_tokens'));
  assert.deepEqual(tokenCall.body, { repositories: ['R'], permissions: { contents: 'write', pull_requests: 'write' } });
  assert.match(tokenCall.auth, /^Bearer eyJ/);                   // the JWT, only for the two token calls
  assert.ok(g.calls.some(c => c.key.startsWith('DELETE')));
});

test('an event without a valid signature never reaches GitHub, whoever sends it', async () => {
  const forged = [
    ['no signature', { ...good, signature: undefined }, /not valid/],
    ['signed with another secret', signed({}, 'guess'), /signature of the event is not valid/],
    ['changed after signing', { ...good, commit_message: 'my own text' }, /signature of the event is not valid/],
    ['a copy sent again later', signed({ timestamp: NOW - 3600 }), /older than 10 minutes/],
  ];
  for (const [name, payload, re] of forged) {
    const g = github();
    await assert.rejects(go(g, event(payload, 'developer')), re, name);
    assert.deepEqual(g.calls, [], `${name}: the app was used although the event was not signed by SAP`);
  }
  const g = github();
  await assert.rejects(go(g, event(), { ...env, SAP_EVENT_SECRET: '' }), /not set up/);
  assert.deepEqual(g.calls, []);
});

test('the sender of the event does not matter when the signature is valid', async () => {
  assert.equal((await go(github(), event(good, 'SomeoneElse'))).merged, true);
});

test('a pull request merged already is left alone', async () => {
  const g = github({ pull: { merged: true, state: 'closed' } });
  assert.deepEqual(await go(g), { merged: true, already: true });
  assert.ok(!g.calls.some(c => c.key.startsWith('PUT')));
});

test('everything that is not exactly the released request is refused and nothing is merged', async () => {
  const cases = [
    ['closed', { pull: { state: 'closed' } }, /is closed, not open/],
    ['another branch', { pull: { head: { ref: 'review/DEVK900001', sha: SHA, repo: { full_name: 'O/R' } } } }, /not for review\/DEVK901853/],
    ['a fork', { pull: { head: { ref: 'review/DEVK901853', sha: SHA, repo: { full_name: 'X/R' } } } }, /another repository/],
    ['another base', { pull: { base: { ref: 'dev' } } }, /not into master/],
    ['a newer commit', { pull: { head: { ref: 'review/DEVK901853', sha: 'c'.repeat(40), repo: { full_name: 'O/R' } } } }, /later commit is not approved/],
    ['not approved', { graph: { reviewDecision: 'REVIEW_REQUIRED' } }, /not approved/],
    ['open comment', { graph: { reviewThreads: { nodes: [{ isResolved: false }] } } }, /not resolved/],
    ['failing check', { graph: { commits: { nodes: [{ commit: { statusCheckRollup: { state: 'FAILURE' } } }] } } }, /checks are failure/],
  ];
  for (const [name, over, re] of cases) {
    const g = github(over);
    await assert.rejects(go(g), re, name);
    assert.ok(!g.calls.some(c => c.key.startsWith('PUT')), `${name}: merged anyway`);
  }
});

test('a refusal from GitHub is reported, and a missing key is said plainly', async () => {
  await assert.rejects(go(github({ mergeStatus: 405 })), /405.*rule violations/);
  await assert.rejects(go(github(), event(), { ...env, APP_PRIVATE_KEY: '' }), /not set up/);
  await assert.rejects(go(github(), event(), { ...env, REPOSITORY: 'bad' }), /owner\/name/);
});

test('a branch that is gone already after the merge is fine, another error is not hidden', async () => {
  assert.equal((await go(github({ deleteStatus: 422 }))).merged, true);
  assert.equal((await go(github({ deleteStatus: 404 }))).merged, true);
  await assert.rejects(go(github({ deleteStatus: 500 })), /500/);
});
