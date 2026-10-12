# Screenshots

> The guides contain each screenshot as a hidden block (an HTML comment that starts with `screenshot, see docs/images/README.md`). When you add a picture to this folder, open the guide named in the table below and remove the `<!--` and `-->` lines around its image, so that it shows.


**The guides in `docs/` and the README refer to the files listed here.** The pictures 01, 02, 03, 06, 07, 08, 11, 12, 13, 14 and 15 are in this folder and shown in the guides. 04, 05, 09 and 10 are still missing; their blocks stay hidden in the guides until the file is added. Do not add placeholder images: a missing file is better than a wrong one.

The pictures in this folder were taken on a development system and then edited: every system name, host, user, organization, repository, request, task and ticket name was covered and replaced by a neutral name (`<owner>`, `my-abap-repo`, `DEVK900104`, `ABC-123`, `ZTR_*`), so that no real name is left. They show the real screens, with those names replaced. Edit new pictures the same way.

## Rules for every screenshot

- Take it from a test system with a test package, a test repository and test users.
- PNG, about 1200 px wide, only the part of the screen that matters.
- **Blank out or replace:** system names and system IDs, host names and IP addresses, user names and e-mail addresses (SAP and GitHub), organization and repository names, GitHub App names and IDs, request and task numbers if they identify a real project, ticket numbers and ticket text, tokens and device codes that are still valid.
- Use the neutral names of the guides where you can: owner `<owner>`, repository `my-abap-repo`, issue key `ABC-123`, package `Z*`.

## The files

| File | Used in | It must show | Blank out |
|---|---|---|---|
| `01-setup-report-green-lights.png` | README, INSTALL step 6 | the output of `ZTR_SETUP` after "Write the settings": the lines for abapGit, the user exit, the release check, GitHub over SSL, the device flow, the login, with green lights and no red one | system ID, GitHub login, repository names, user name |
| `02-login-popup-device-flow.png` | INSTALL step 7, GITHUB-LOGIN | the popup of `ZTR_GITHUB_LOGIN` with the code and the address | the code (use a code that has already expired or been used), user name |
| `03-task-release-progress-or-popup.png` | WORKFLOW | the release of a task in SAP GUI finishing, with the status bar or the popup the developer sees; if there is only a status message, show that | system ID, user name, request and task numbers |
| `04-express-document-with-pr-link.png` | WORKFLOW | the express document in the SAP inbox (or its popup): subject "`<request>`: pull request `<n>` waits for approval" and the link in the text | system ID, user name, repository name in the link, request text |
| `05-sm37-job-log.png` | WORKFLOW, INSTALL step 11 | SM37 with the job `GIT_REVIEW_<request>` finished and its job log: the line `GitHub account: ...`, the pushed files and "pull request opened" with the link | user name, system ID, repository name, GitHub login, request number |
| `06-pull-request-on-github.png` | WORKFLOW | the pull request on GitHub: title `<request> <request text>`, the description with the task list and "Documentation from SAP", the author as the developer | organization and repository names, GitHub logins, ticket text |
| `07-pr-title-with-jira-key.png` | JIRA | the pull request title with the request number followed by the issue key `ABC-123` | organization and repository names, GitHub logins; use a made-up key |
| `08-jira-development-panel.png` | JIRA | the Development panel of a Jira issue listing the pull request and the commits | site name, project name, issue text, people |
| `09-codeowners-review-request.png` | GITHUB-REPOSITORY-SETUP | a pull request with the owners listed as requested reviewers | organization, repository, GitHub logins |
| `10-ruleset-settings.png` | GITHUB-REPOSITORY-SETUP | the ruleset "Default branch only through reviewed pull requests": one required approval, resolved conversations, squash as the only merge method | organization and repository names |
| `11-request-release-refused-pending-review.png` | WORKFLOW | the popup "Release refused" after releasing a request before the approval, with the reason "pull request `<n>` is not approved yet" and the link | system ID, user name, request number, repository name in the link |
| `12-setup-selection-screen.png` | INSTALL step 6 | the selection screen of `ZTR_SETUP`: the block "GitHub workflow", the block "abaplint client" and the box "Write the settings above" | client ID of the GitHub App, package pattern, abaplint host |
| `13-login-report-selection.png` | GITHUB-LOGIN | the selection screen of `ZTR_GITHUB_LOGIN` with the three actions | SAP user name |
| `14-eclipse-release-not-logged-in.png` | GITHUB-LOGIN | the Problems view of Eclipse (ADT) after a release by a developer who is not logged in: the user, the system and the report to run | SAP user name, system ID |
| `15-eclipse-release-refused-message.png` | WORKFLOW | the Problems view of Eclipse (ADT) after the release of a request whose pull request is not approved | request number |

## Where the links are

```
README.md                                 01
docs/INSTALL.md                           01, 02, 05, 12
docs/GITHUB-LOGIN.md                      02, 13, 14
docs/WORKFLOW.md                          03, 04, 05, 06, 11, 15
docs/JIRA.md                              07, 08
docs/GITHUB-REPOSITORY-SETUP.md           09, 10
```
