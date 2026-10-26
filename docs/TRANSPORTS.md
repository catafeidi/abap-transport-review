# Building transports: step by step for developers

How a change travels from the development system to Git, to the test systems and to the customer, and what each step expects from you. The details behind each step are in [WORKFLOW.md](WORKFLOW.md) (Git, review, merge), [TRANSLATION-GUIDE.md](TRANSLATION-GUIDE.md) (translating), [ATC-AT-RELEASE.md](ATC-AT-RELEASE.md) (code checks) and [NOT-IN-GIT.md](NOT-IN-GIT.md) (what a transport carries beyond objects).

This is one way of working with the tools, written as rules for a team. Adapt it to your landscape.

## In short

1. One issue, one workbench request: the short text starts with the issue key.
2. Work in the task. Translate your texts in the task.
3. Release the **task** when it is ready for review: the pull request opens by itself.
4. Fix review comments in a **new task** of the same request, release it.
5. After the approval, release the **request**: it is merged into the base branch by itself.
6. Systems import in the order of the base branch, always "Import all".
7. A transport for a customer carries `#DELIVERY` in its short text and is built from released, reviewed and translated work only.

## Before you start (once)

- Log in to GitHub on the development system: SE38, `ZTR_GITHUB_LOGIN` (in ADT: class `ZCL_TR_CONSOLE_LOGIN`, F9). Without it, nothing with objects under Git can be released. See [GITHUB-LOGIN.md](GITHUB-LOGIN.md).
- You need write access to the GitHub repositories of the packages you change.

## 1. Create the request

| Field | Rule |
|---|---|
| Type | workbench request (customizing requests go the same way) |
| Short text | `ABC-123 What the change does`: the issue key first ([JIRA.md](JIRA.md)). Markers (below) go at the end |
| Target | the one SE09 proposes for the package |
| One issue | one request. Do not mix two issues in one request |
| One product line | one namespace. A namespace is usually a product line that is delivered on its own, so the release check refuses a task or request whose objects come from two namespaces. Objects without a namespace (Z, Y) do not count |

**No object in two open requests.** If the object you want to change is already in another open request (yours or a colleague's), the release of your request is refused later ([WORKFLOW.md](WORKFLOW.md), "Release order"). Both requests are then refused, each because of the other. Agree with the owner of the other request who changes the object, or put the work into one request: SE09, Merge Requests, the other request into yours.

**Documentation of the request.** SE09, request, Documentation: write what changed and why. It is copied into the pull request and into the commit on the base branch.

## 2. Work in the task

- Change the objects. SAP puts them into your task.
- When the translation check is set up: every text the user sees (messages, text elements, screens, field labels, ...) needs every required language. Translate them **in your task**: `ZTR_TRANSL_REPORT` with your task, "Enter translations", Save ([TRANSLATION-GUIDE.md](TRANSLATION-GUIDE.md), way A). Many texts: the Excel file (way B).
- No hardcoded texts: a text in `MESSAGE '...'`, `WRITE '...'` or a popup cannot be translated. Use the message class of the package or a text symbol. The translation report lists the hardcoded ones.

## 3. Release the task: review

Release the **task**, not the request (SE09: select the task, Release).

What the release does:

| Check or step | What it expects | When it refuses |
|---|---|---|
| GitHub login (`ZTR_RELEASE_CHECK`) | you are logged in | not logged in: run the login report |
| Translation check (`ZTR_TRANSL_CHECK`) | the texts of your objects exist in the required languages | mode BLOCK and a text missing. The popup offers "Translate" |
| Object check, ATC | no findings of priority 1 and 2 | when ATC is set to block ([ATC-AT-RELEASE.md](ATC-AT-RELEASE.md)) |
| Push to Git | — | never refuses; job `GIT_REVIEW_<request>` pushes to `review/<request>` and opens the pull request in your name |

The translation check looks at the **whole object** as it is on the system, not only at what you changed: an old untranslated text of the class you touched is listed too. Translate it in the same task: the translations then travel with your change.

## 4. Review

- The pull request lists your request, your tasks and the SE09 documentation. Colleagues from `CODEOWNERS` are asked for a review.
- Fix comments **on the development system**, in a new task of the same request (SAP creates it when you change the object again), and release that task. Never edit on GitHub: the next push overwrites it.
- Each new task adds a commit to the same pull request and cancels an approval given before.

## 5. Release the request: merge

After the approval and with all comments resolved, release the **request**.

| Check | When it refuses | What to do |
|---|---|---|
| Review | an object differs from the approved pull request, or the pull request is not approved | release a new task / get the approval |
| Up to date | the pull request is behind the base branch | "Update branch" on the pull request, or release a new task, then the request again |
| Release order | an object is also in another open request | merge the two requests in SE09 (Merge Requests), then release |
| Translation check | as for the task | translate in a task of this request |

Then job `GIT_MERGE_<request>` squashes and merges the pull request into the base branch. The Git log of the base branch is the list of requests.

## 6. Imports into the test systems

- The transport routes follow the transport layer of the packages: development to the test systems, then on.
- Import **in the order of the base branch**, always with "Import all". Never pick single requests out of the queue: a request can hold only a part of an object, and another order gives a combination that never existed on the development system.

## 7. A transport for a customer

A transport that goes to a customer (a hotfix as a transport of copies, a correction transport, a delivery request) is built **from released, reviewed and merged work only**. Who builds it and on which system is your delivery process. The request itself follows these rules:

1. **Short text** with the issue key and `#DELIVERY`, for example `ABC-123 Hotfix 3 #DELIVERY`.
2. **Never change or translate in it.** It only collects what is ready. If a text is missing, its release is refused with an error message (whatever the mode, also for a transport of copies) and **no** "Translate" is offered: translate in a development request, release that one, then rebuild the delivery.
3. **Tag the commit** on the base branch that the delivery was built from, with the request number in the tag message, so that a later fix can start from exactly what the customer has.

## Markers in the short text

Each tool reads only its own marker. Markers can be combined; put them at the end of the short text.

| Marker | Read by | Effect | Use for |
|---|---|---|---|
| `#DELIVERY` | translation check | a missing translation always refuses the release, without "Translate"; nothing is recorded into it; a transport of copies is checked too | every transport that goes to a customer |
| `#NOREVIEW` | Git workflow | the request is released without the review check and is not merged; the pull request stays open for an admin | emergencies only |
| `#NOTRANSL` | translation check | the request and its tasks are released without the translation check; wins over `#DELIVERY` | emergencies only |

Example of a delivery that has to leave in an emergency before its review: `ABC-123 Hotfix for customer X #DELIVERY #NOREVIEW`. The markers stay visible in the request, so the exception is documented where it happened.

## Bringing a hotfix back into development

A fix made on a separate hotfix system comes back into development **through Git**, never by importing the hotfix request into the development system: a branch from the tag of the delivered version, a pull request into the base branch, then an abapGit pull on the development system into a new request of the same issue. Table rows and variants of the fix: `ZTR_APPLY_CONTENT` ([NOT-IN-GIT.md](NOT-IN-GIT.md), "Bringing `content/` into another system").

## When something is refused

| Message | What to do |
|---|---|
| `<user> is not logged in to GitHub` | `ZTR_GITHUB_LOGIN`, then release again |
| `pull request <number> is not approved yet` | get the review, then release the request |
| `<x>` is also in `<y>` ... Both requests wait for each other | SE09, Merge Requests: `<y>` into your request, then release again |
| the pull request is behind the base branch | "Update branch" on GitHub, then release again |
| `<request>: N text(s) without translation ...` | "Translate", or `ZTR_TRANSL_REPORT` with your task |
| `... Delivery: translate in the development requests.` | the delivery is missing a translation: translate in a development request, release it, rebuild the delivery |
| another push is running | wait a minute, release again |
| release in the background refused | SM37, job `RELEASE OF <request>`: the reason is in the last line of its log |
