# Templates for a product repository

Copy what you need into the repository that holds your ABAP package.

| File | Goes to | For |
|---|---|---|
| `CODEOWNERS` | `.github/CODEOWNERS` | reviewers requested on every pull request |
| `copilot-instructions.md` | `.github/copilot-instructions.md` | what GitHub Copilot code review should look for, if you turn it on: the code, and the translations of the texts (language, glossary, placeholders), see `docs/TRANSLATION-CHECK.md` |
| `translation-glossary.md` | `.github/translation-glossary.md` | the agreed terms per language, used by Copilot and by whoever translates; an example to replace with your own terms |
| `abaplint/` | `abaplint.json`, `.github/workflows/abaplint.yml`, `.github/abaplint-changed-files.js` | a repository with existing code: 7.40 SP08 syntax check, only the files changed by the pull request fail |
| `abaplint-new-repository/abaplint.json`, `abaplint.yml`, `abaplint-annotate.js` | `abaplint.json`, `.github/workflows/abaplint.yml`, `.github/abaplint-annotate.js` | a repository that starts empty: 7.40 SP08 syntax, every finding fails |
| `abaplint-new-repository/abaplint-cloud.json`, `abaplint-core.yml` | `abaplint-cloud.json`, `.github/workflows/abaplint.yml` | additionally for code that must also run in ABAP Cloud: statements, object types and SAP objects outside ABAP Cloud and 7.40 |
| `abaplint-new-repository/abaplint-clean.json` | `abaplint-clean.json` | the Clean ABAP rules, job `clean-abap`; run `abaplint <file> --fix` with only `align_parameters` to align parameters automatically |
| `abaplint-sap-package.json` | table `ZABAPLINT_PACK`, field JSON, per package | the same rules for the check inside SAP (Code Inspector and ATC), without `unused_variables`, `prefer_inline`, `unused_methods` and `unused_types`, which are wrong when the check sees one object alone |
| `abaplint-new-repository/abapgit.xml` | `.abapgit.xml` | folder logic Prefix, language E, ABAP language version `ignore` |
| `github-protect-master.sh` | run on the workstation | rulesets "No deletion, no force push" (`basic`) and "Default branch only through reviewed pull requests" (`review`) |
| `github-restrict-merge.sh` | run on the workstation, after the GitHub App is installed on the repository | ruleset "Default branch merged only by SAP release or an admin" |
| `merge-released-request/` | `.github/workflows/merge-released-request.yml`, `.github/scripts/merge-released-request.mjs`, `.github/scripts/merge-released-request.test.mjs`; plus the environment `sap-merge` (default branch only), variable `MERGE_APP_ID`, secrets `MERGE_APP_PRIVATE_KEY` and `SAP_EVENT_SECRET` | every repository with the ruleset above: the release on SAP asks this workflow to merge, with an event signed by SAP (`docs/GITHUB-REPOSITORY-SETUP.md`, "The merge by workflow and the signed event") |

Repository settings that go with them: default branch `master`, squash merge only, delete the branch on merge, squash commit = title and description of the pull request. See `docs/GITHUB-REPOSITORY-SETUP.md`.

The two scripts need `gh` (GitHub CLI) logged in with the admin role on the repository. Both take the owner (user or organization) as first argument and can be run again safely.
