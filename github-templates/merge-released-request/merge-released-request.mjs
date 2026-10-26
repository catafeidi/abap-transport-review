// Squash-merges the pull request of a request that was released on the SAP system.
//
// SAP is the only way to a merge. The release job on SAP merges with the token of the developer who releases;
// only repository admins may update the default branch (ruleset "master merged only by SAP release or an admin"),
// so for everybody else GitHub refuses. The job then sends a repository_dispatch event "sap-request-released" and
// this script merges with the token of the GitHub App, which the ruleset trusts. The rule "master only through
// reviewed pull requests" still applies to the app.
//
// Anybody with write access can send such an event, so the event carries a signature: HMAC-SHA256, made on SAP with a
// secret that only SAP and the environment "sap-merge" know, over the request, the pull request, the commit, the time and the
// text of the squash commit. Without a valid and recent signature nothing is merged, whoever sends the event.
// Also checked:
//   - the pull request is the open one of review/<request>, from this repository, into the default branch
//   - its head is the commit SAP judged (a later commit is not approved and must not slip in)
//   - approved, no open review comment, no failing or running check
// Nothing from the event is put into a shell command; it is only read here as data.

import { createHmac, createSign, timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const API = 'https://api.github.com';
const REQUEST = /^[A-Z][A-Z0-9]{2}K\d{6}$/;
const SHA = /^[0-9a-f]{40}$/;
const MAX_TITLE = 250;
const MAX_MESSAGE = 60000;
const SIGNATURE = /^[0-9a-fA-F]{64}$/;
/** An event older than this (or from the future by more than a minute) is not accepted, so a copy of one cannot be sent again later. */
const MAX_AGE_SECONDS = 600;
const MAX_AHEAD_SECONDS = 60;

const b64url = value => Buffer.from(value).toString('base64url');

/** JWT of the GitHub App, valid for five minutes. */
export function appJwt(appId, privateKey, now = Math.floor(Date.now() / 1000)) {
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const body = b64url(JSON.stringify({ iat: now - 60, exp: now + 300, iss: String(appId) }));
  const signature = createSign('RSA-SHA256').update(`${head}.${body}`).sign(privateKey).toString('base64url');
  return `${head}.${body}.${signature}`;
}

/** The part of the event that counts, checked and cleaned. Title and message of the squash commit come from SAP and are signed with the rest. */
export function readRequest(payload) {
  const p = payload ?? {};
  const fail = what => { throw new Error(`The event is not valid: ${what}.`); };
  if (!REQUEST.test(String(p.request ?? ''))) fail('request is not a transport number');
  if (!Number.isInteger(p.pull_request) || p.pull_request < 1) fail('pull_request is not a number');
  if (!SHA.test(String(p.sha ?? ''))) fail('sha is not a commit');
  if (!Number.isInteger(p.timestamp) || p.timestamp < 1) fail('timestamp is not a number');
  if (!SIGNATURE.test(String(p.signature ?? ''))) fail('signature is missing or not 64 hexadecimal characters');
  const title = String(p.commit_title ?? ''), message = String(p.commit_message ?? '');
  if (title.length === 0 || title.length > MAX_TITLE || /[\r\n]/.test(title)) fail('commit_title is empty, too long or has line breaks');
  if (message.length > MAX_MESSAGE) fail('commit_message is too long');
  return { request: p.request, number: p.pull_request, sha: p.sha, timestamp: p.timestamp, signature: p.signature.toLowerCase(), title, message };
}

/**
 * What SAP signs: the fields in this order, one per line (the message last, so its own line breaks cannot shift a field).
 * The ABAP report builds the same text; both sides must stay identical.
 */
export function signedText(want) {
  return [want.request, String(want.number), want.sha, String(want.timestamp), want.title, want.message].join('\n');
}

export const signatureOf = (secret, want) => createHmac('sha256', secret).update(signedText(want), 'utf8').digest('hex');

/** Throws unless the event was signed with the shared secret and is recent. */
export function checkSignature(want, secret, now = Math.floor(Date.now() / 1000)) {
  if (!secret) throw new Error('The shared secret of SAP is not set up for this workflow (SAP_EVENT_SECRET is missing in the environment).');
  const expected = Buffer.from(signatureOf(secret, want), 'hex');
  const given = Buffer.from(want.signature, 'hex');
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) throw new Error('The signature of the event is not valid. Only the release on SAP may ask for a merge.');
  if (now - want.timestamp > MAX_AGE_SECONDS) throw new Error(`The event is older than ${MAX_AGE_SECONDS / 60} minutes and is not accepted again.`);
  if (want.timestamp - now > MAX_AHEAD_SECONDS) throw new Error('The event is dated in the future. Check the clock of the SAP system.');
}

/** Why a pull request is not ready, or null. `state` is the rollup of the checks on the head commit. */
export function notReady({ reviewDecision, unresolved, checks }) {
  if (reviewDecision !== 'APPROVED') return `it is not approved (${reviewDecision ?? 'no review'})`;
  if (unresolved > 0) return `${unresolved} review comment(s) are not resolved`;
  if (checks !== null && checks !== 'SUCCESS') return `the checks are ${String(checks).toLowerCase()}`;
  return null;
}

export async function run({ env, event, fetchImpl = fetch, now = Math.floor(Date.now() / 1000), log = console.log }) {
  const repo = String(env.REPOSITORY ?? '');
  if (!/^[\w.-]+\/[\w.-]+$/.test(repo)) throw new Error('REPOSITORY is not owner/name.');
  if (!env.APP_ID || !env.APP_PRIVATE_KEY) throw new Error('The GitHub App is not set up for this workflow (APP_ID or APP_PRIVATE_KEY is missing in the environment).');
  const want = readRequest(event.client_payload);
  checkSignature(want, env.SAP_EVENT_SECRET, now);   // before anything is asked of GitHub with the rights of the app
  const base = event.repository?.default_branch;

  const call = async (token, method, path, body) => {
    const res = await fetchImpl(`${API}${path}`, {
      method,
      headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'x-github-api-version': '2022-11-28', 'user-agent': 'sap-release-merge', ...(body ? { 'content-type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    let data = null; try { data = text ? JSON.parse(text) : null; } catch { /* not json */ }
    if (!res.ok) throw Object.assign(new Error(`${method} ${path} -> ${res.status} ${(data?.message ?? text).slice(0, 300)}`), { status: res.status });
    return data;
  };

  // Token of the app for this repository only, with the two rights the merge needs.
  const jwt = appJwt(env.APP_ID, env.APP_PRIVATE_KEY);
  const installation = await call(jwt, 'GET', `/repos/${repo}/installation`);
  const { token } = await call(jwt, 'POST', `/app/installations/${installation.id}/access_tokens`,
    { repositories: [repo.split('/')[1]], permissions: { contents: 'write', pull_requests: 'write' } });
  if (env.GITHUB_ACTIONS) log(`::add-mask::${token}`);

  const pull = await call(token, 'GET', `/repos/${repo}/pulls/${want.number}`);
  if (pull.merged) { log(`Pull request #${want.number} is merged already.`); return { merged: true, already: true }; }
  if (pull.state !== 'open') throw new Error(`Pull request #${want.number} is ${pull.state}, not open.`);
  if (pull.head.ref !== `review/${want.request}`) throw new Error(`Pull request #${want.number} is for ${pull.head.ref}, not for review/${want.request}.`);
  if (pull.head.repo?.full_name !== repo) throw new Error(`Pull request #${want.number} comes from another repository.`);
  if (base && pull.base.ref !== base) throw new Error(`Pull request #${want.number} goes into ${pull.base.ref}, not into ${base}.`);
  if (pull.head.sha !== want.sha) throw new Error(`The head of pull request #${want.number} is ${pull.head.sha.slice(0, 8)}, SAP released ${want.sha.slice(0, 8)}. A later commit is not approved; nothing was merged.`);

  const [owner, name] = repo.split('/');
  const g = await call(token, 'POST', '/graphql', {
    query: 'query($owner:String!,$name:String!,$n:Int!){repository(owner:$owner,name:$name){pullRequest(number:$n){reviewDecision reviewThreads(first:100){nodes{isResolved}} commits(last:1){nodes{commit{statusCheckRollup{state}}}}}}}',
    variables: { owner, name, n: want.number },
  });
  const pr = g?.data?.repository?.pullRequest;
  if (!pr) throw new Error(`GitHub did not return pull request #${want.number}.`);
  const why = notReady({
    reviewDecision: pr.reviewDecision,
    unresolved: pr.reviewThreads.nodes.filter(t => !t.isResolved).length,
    checks: pr.commits.nodes[0]?.commit?.statusCheckRollup?.state ?? null,
  });
  if (why) throw new Error(`Pull request #${want.number} is not merged: ${why}.`);

  const merged = await call(token, 'PUT', `/repos/${repo}/pulls/${want.number}/merge`, {
    merge_method: 'squash', sha: want.sha,
    commit_title: want.title,
    commit_message: want.message,
  });
  log(`Pull request #${want.number} (${want.request}) squashed and merged as ${String(merged.sha).slice(0, 8)}, sent by ${event.sender?.login ?? 'unknown'}.`);

  // The repository may delete merged branches itself; a branch that is gone already is fine.
  try { await call(token, 'DELETE', `/repos/${repo}/git/refs/heads/review/${want.request}`); }
  catch (e) { if (e.status !== 404 && e.status !== 422) throw e; }
  return { merged: true, sha: merged.sha };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
    await run({ env: { ...process.env, REPOSITORY: process.env.GITHUB_REPOSITORY }, event });
  } catch (e) {
    console.error(`::error::${String(e.message).replace(/\r?\n/g, ' ')}`);
    process.exit(1);
  }
}
