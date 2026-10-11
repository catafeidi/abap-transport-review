// Turns the abaplint result into GitHub annotations for the files changed by the pull request.
// Usage: node abaplint-changed-files.js <base sha>
// Fails (exit 1) when a changed file has a finding; findings in other files are only counted.
const fs = require("fs");
const { execSync } = require("child_process");

const base = process.argv[2];
const changed = new Set(
  execSync(`git diff --name-only ${base} HEAD`, { encoding: "utf8" })
    .split("\n").map(f => f.trim()).filter(f => f.startsWith("src/")));

// abaplint exits with 1 when it finds anything, so the workflow cannot rely on its exit
// code. A run that produced no JSON array (download failed, tool crashed, bad config)
// must fail the check, never pass as "no findings".
const raw = fs.existsSync("abaplint-result.json") ? fs.readFileSync("abaplint-result.json", "utf8") : "";
const start = raw.indexOf("[");
let issues;
try {
  issues = JSON.parse(raw.slice(start));
} catch (e) {
  issues = undefined;
}
if (start < 0 || !Array.isArray(issues)) {
  console.log("::error title=abaplint 7.40::abaplint produced no result, the sources were NOT checked");
  console.log(raw.slice(0, 2000));
  process.exit(2);
}

const relative = file => {
  const path = String(file).split(String.fromCharCode(92)).join("/");
  const at = path.indexOf("src/");
  return at < 0 ? path : path.slice(at);
};

let inChanged = 0;
let elsewhere = 0;
for (const issue of issues) {
  const file = relative(issue.file);
  if (!changed.has(file)) {
    elsewhere++;
    continue;
  }
  inChanged++;
  const text = `${issue.key}: ${issue.description}`.replace(/\r?\n/g, " ");
  console.log(`::error file=${file},line=${issue.start.row},col=${issue.start.col},title=abaplint 7.40::${text}`);
}

const summary = [
  "## abaplint 7.40",
  "",
  `Files changed by this pull request: ${changed.size}`,
  `Findings in changed files: ${inChanged}`,
  `Findings in other files (existing, for information): ${elsewhere}`,
  ""
].join("\n");
if (process.env.GITHUB_STEP_SUMMARY) {
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary + "\n");
}
console.log(summary);
process.exit(inChanged > 0 ? 1 : 0);
