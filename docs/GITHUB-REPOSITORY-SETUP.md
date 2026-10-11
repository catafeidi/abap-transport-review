# GitHub repository setup

What a repository needs on GitHub so that the workflow works, and what is only recommended. One repository per package (or package tree) under Git, linked in abapGit.

Marks used below: **required** = the tools do not work or the review can be bypassed without it; **recommended** = works without, but you should do it.

## Branch model

| Branch | Purpose | Lifetime |
|---|---|---|
| base branch (`master`) | The codebase in development. One commit per merged request. | permanent |
| `review/<request>` | One request under review, as a pull request into the base branch | until merged |
| `review/CONTENT-BASELINE` | The result of `ZTR_PUSH_TRANSPORT` with the baseline option | until merged |

Rules:

- Squash merging only. The commit on the base branch is the request: title `<request> <request text>`, message = the description of the pull request.
- Fixes are made in the SAP system, never on GitHub: the next push from the system overwrites a change made on a review branch.
- Tags, release branches and hotfix branches are up to you; the tools do not create them. To push once to another branch, run `ZTR_PUSH_TRANSPORT` by hand with that branch in `P_BASE`.

## Repository settings

| Setting | Value | Why | |
|---|---|---|---|
| Default branch | `master` | `ZTR_PUSH_TRANSPORT` uses `master` as the base branch unless `P_BASE` says otherwise. With `P_BASE` empty the default branch of the repository is used | required, or change the default of `P_BASE` |
| The base branch exists | at least one commit | the review branch is created from it | required |
| Allow squash merging | on | the merge by the tool is a squash merge | required |
| Allow merge commits, rebase merging | off | squash is the only method the review rules allow | recommended |
| Squash commit: default message | "Pull request title" and "Pull request description" | the tool sends title and message itself; this only matters for a merge by hand | recommended |
| Automatically delete head branches | on | the review branch is gone after the merge | recommended |
| `.abapgit.xml` at the root | folder logic `Prefix`, starting folder `/src/` | abapGit reads it when the repository is linked. Template: `github-templates/abaplint-new-repository/abapgit.xml` | recommended |
| Visibility | private is typical | the code of your system | recommended |

With the GitHub CLI:

```bash
gh repo edit <owner>/<repository> --default-branch master \
  --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
  --delete-branch-on-merge
gh api -X PATCH repos/<owner>/<repository> \
  -f squash_merge_commit_title=PR_TITLE -f squash_merge_commit_message=PR_BODY
```

## Protect the base branch: rulesets

Rulesets (Settings, Rules, Rulesets) are what makes the review binding. The script `github-templates/github-protect-master.sh` creates them.

```bash
bash github-protect-master.sh <owner> basic  <repository> [<repository> ...]
bash github-protect-master.sh <owner> review <repository> [<repository> ...]
```

| Argument | Meaning |
|---|---|
| `<owner>` | the GitHub user or organization |
| `basic` or `review` | which ruleset (below) |
| `<repository> ...` | one or more repository names under the owner |

It needs the GitHub CLI (`gh`) logged in with the admin role on the repositories. It can be run again: a ruleset of the same name is updated to the definition in the script.

| Ruleset | What it does | |
|---|---|---|
| `basic`: "No deletion, no force push" | the default branch and `release/*` branches cannot be deleted or force-pushed. Normal pushes still work | recommended |
| `review`: "Default branch only through reviewed pull requests" | changes reach the default branch only through a pull request with **one approval**; a new commit on the pull request dismisses an approval given before; **all review conversations must be resolved**; only **squash** merging is allowed; code owner review is **not** required (`require_code_owner_review` is `false` in the script: any colleague with write access may approve; change it to `true` to make the owners mandatory) | required (or an equivalent rule you set by hand) |

Run `review` only after the default branch has its first content: until then nobody could push it directly. With the rule in place, a request released without a merged pull request cannot be pushed to the base branch: the job is cancelled and the review branch with its pull request stays open until somebody reviews and merges it.

A pull request needs an approval from somebody other than the person who opened it, so make sure a second reviewer exists before switching `review` on.

**Status checks** are not in the script. If you add a required status check to the ruleset (for example the abaplint workflow of `github-templates/`), the tools respect it: while a required check has not passed, GitHub does not report the pull request as mergeable, so the release of the request is refused.

<!-- screenshot, see docs/images/README.md
![Ruleset settings](images/10-ruleset-settings.png)
*What to look at: the pull request rule with one required approval, resolved conversations and squash as the only merge method.*
-->

### Optional: only the release merges

Script `github-templates/github-restrict-merge.sh` adds a second ruleset, "Default branch merged only by SAP release or an admin" (rule: restrict updates on the default branch). Its bypass list is the repository role Admin and your GitHub App. An approver, or any other person with write access, can then not press Merge on GitHub: the merge happens when the author releases the request, or an admin merges by hand. This is what keeps the base branch free of unreleased work: without the rule, an approved pull request could be merged while the request is still open, and a new task added to the request afterwards would be released after the merge.

```bash
bash github-restrict-merge.sh <owner> <github-app-id> <repository> [<repository> ...]
```

| Argument | Meaning |
|---|---|
| `<owner>` | the GitHub user or organization |
| `<github-app-id>` | the numeric App ID on the settings page of the GitHub App |
| `<repository> ...` | one or more repositories |

Run it after the App is installed on the repository: GitHub refuses the ruleset while the App is not installed there. With this ruleset GitHub reports every pull request as blocked, approved or not. The release check then asks GitHub directly (approved, mergeable, commit that was judged, all conversations resolved, checks of that commit not failed) and counts the pull request as approved only if all of that holds. Whether GitHub accepts the merge of a **user** token of the App through this bypass for a developer who is not an admin is not proven by this repository. If the merge is refused, remove the ruleset and merge by hand or rely on the `review` ruleset alone.

## CODEOWNERS

`CODEOWNERS` decides who GitHub asks to review a pull request. In this workflow it makes the review request automatic: when the tool opens the pull request, GitHub requests a review from the listed owners.

- **Where:** `.github/CODEOWNERS` in the product repository, on the base branch. The template is `github-templates/CODEOWNERS`.
- **Syntax:** one rule per line, a path pattern followed by one or more owners (`@user` or `@organization/team`). The last matching pattern wins. The template has one line for the whole repository:

```
*  @owner-one  @owner-two
```

Replace `@owner-one @owner-two` with the GitHub names of your reviewers. To add a reviewer, add the name to that line through a pull request. Patterns for parts of the repository work as in any `CODEOWNERS` file, for example `/src/zcl_* @team-name`.
- **The author is never asked.** With two names each developer gets the other one.
- **Mandatory or not:** the rule of the script does not require the approval of a code owner. Any colleague with write access may approve. Set `require_code_owner_review` to `true` in the script to make the owners mandatory.
- **Re-requests:** when a further task of the request is pushed to an open pull request, the tool asks GitHub to request the review again from everybody who was asked or has reviewed.

<!-- screenshot, see docs/images/README.md
![Review requested from the code owners](images/09-codeowners-review-request.png)
*What to look at: the owners listed as requested reviewers on the pull request.*
-->

## The GitHub App

Required. The token of each developer is issued by an App, and only sees the repositories the App is installed on. Permissions: Contents (read and write), Pull requests (read and write), Metadata (read-only). Device flow on, expiring user tokens off, no webhook. Installed on every repository under Git. Full steps and the login of the developers: [GITHUB-LOGIN.md](GITHUB-LOGIN.md).

Every developer needs write access to the repositories.

## Required and recommended, in one list

| | |
|---|---|
| required | GitHub App installed on the repositories, every developer with write access |
| required | default branch `master` with a first commit; squash merging allowed |
| recommended | `.abapgit.xml` at the root |
| required | a rule that the default branch changes only through an approved pull request (`review`) |
| recommended | `basic` ruleset, delete head branches on merge, merge commits and rebase off |
| recommended | `.github/CODEOWNERS` |
| recommended | abaplint workflow and other checks from `github-templates/` as required status checks |
| optional | `github-restrict-merge.sh` |

## Commands to look at the state

```bash
gh repo view <owner>/<repository> --json defaultBranchRef,squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,deleteBranchOnMerge
gh api repos/<owner>/<repository>/rulesets --jq '.[] | "\(.name) (\(.enforcement))"'
gh pr list --repo <owner>/<repository>
```

## AI-assisted review with GitHub Copilot (optional)

GitHub Copilot code review can review every pull request automatically and leave comments on the diff. It needs a Copilot licence for the user or organization. It is a first reviewer that answers immediately; its review is a comment and does not replace the approval of a person that the ruleset requires.

1. Turn it on for the repository: in the rulesets (or in the Copilot settings of the repository) enable the automatic Copilot code review of pull requests. The labels change from time to time; follow GitHub's page [Using GitHub Copilot code review](https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/copilot-code-review).
2. Tell it what to look for: copy [`github-templates/copilot-instructions.md`](../github-templates/copilot-instructions.md) to `.github/copilot-instructions.md` and adapt it. GitHub describes the instruction files in [Using custom instructions to unlock the power of Copilot code review](https://docs.github.com/en/copilot/tutorials/customize-code-review). Check there from which branch of the pull request the file is read.
3. Judge the comments for ABAP yourself for a few weeks before you rely on them: how useful they are for ABAP depends on your instructions.

The checks that need no licence, abaplint on GitHub, are in [`github-templates/`](../github-templates/README.md).
