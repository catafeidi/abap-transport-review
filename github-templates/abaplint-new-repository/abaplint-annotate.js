// Turns an abaplint result into GitHub annotations. Every finding fails the check.
// Usage: node abaplint-annotate.js <result file> <title>
const fs = require("fs");

const resultFile = process.argv[2];
const title = process.argv[3] || "abaplint";

// abaplint exits with 1 when it finds anything, so the workflow cannot rely on its exit
// code. A run that produced no JSON array (download failed, tool crashed, bad config)
// must fail the check, never pass as "no findings".
const raw = fs.existsSync(resultFile) ? fs.readFileSync(resultFile, "utf8") : "";
const start = raw.indexOf("[");
let issues;
try {
  issues = JSON.parse(raw.slice(start));
} catch (e) {
  issues = undefined;
}
if (start < 0 || !Array.isArray(issues)) {
  console.log(`::error title=${title}::abaplint produced no result, the sources were NOT checked`);
  console.log(raw.slice(0, 2000));
  process.exit(2);
}

const relative = file => {
  const path = String(file).split(String.fromCharCode(92)).join("/");
  const at = path.indexOf("src/");
  return at < 0 ? path : path.slice(at);
};

for (const issue of issues) {
  const text = `${issue.key}: ${issue.description}`.replace(/\r?\n/g, " ");
  console.log(`::error file=${relative(issue.file)},line=${issue.start.row},col=${issue.start.col},title=${title}::${text}`);
}

const summary = [`## ${title}`, "", `Findings: ${issues.length}`, ""].join("\n");
if (process.env.GITHUB_STEP_SUMMARY) {
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary + "\n");
}
console.log(summary);
process.exit(issues.length > 0 ? 1 : 0);
