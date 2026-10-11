# Installing on a system that already has transports

A development system that has been running for years has released transports and open ones. This page says what the tools do with each, and the order that makes the first weeks smooth. It describes what the code does; it has not yet been run on a customer system, so check the first release by hand.

## What the tools do not do

- **Released transports are not replayed.** The push reads the *current* state of the objects of a transport, not the state at the time it was released. Pushing an old request today would write today's objects under the old request number, which is wrong. So there is no commit or pull request per historic transport. The history in Git starts at the first release after the installation.
- **Old content is not merged automatically.** What is on GitHub before the first release is what you put there in step 2 below.

## What the tools do with each case

| Situation | What happens |
|---|---|
| Object released long ago, not changed since | Nothing. It is part of the starting content (step 2). |
| Task released **after** the installation | The objects of that task are compared with the review branch. Changed files are committed to `review/<request>` and a pull request is opened. If every file is identical to what is already there, the job logs "nothing to push" and writes no commit. |
| Request with **no** released task yet, still open | Nothing until its tasks are released. Then as in the row above. |
| Request that is still open and has tasks **released before** the installation | Those tasks were never pushed. Releasing the *remaining* tasks pushes only their own objects. At the release of the **request** the check compares *all* objects of the request: what is on neither the review branch nor the base branch is pushed to the review branch by a job, and the release is refused with "`<n>` file(s) not reviewed yet". Get that pull request approved, then release the request again. This happens once per such request. |
| Object that is in an open task or request while the baseline runs | The baseline skips it ("work in progress"). It reaches GitHub with the release of that task, through its own review. |
| Transport of copies | Never pushed. |
| Request that must go out without review | `#NOREVIEW` in its short text. See [WORKFLOW.md](WORKFLOW.md). |

## Recommended order

1. **Install and set up** as in [INSTALL.md](INSTALL.md), steps 1 to 8. Do not enable the strict branch rule yet (step 9 of INSTALL): use the `basic` ruleset of `github-protect-master.sh` first.
2. **Put the current state of the packages on GitHub.** The repository must exist and have a base branch, so create it with an initial commit (a README) if it is new; whether abapGit can push into a completely empty repository has not been tested. Then either
   - stage and push everything once in `ZABAPGIT` (the repository you linked in step 8), or
   - run `ZTR_PUSH_TRANSPORT` with the option "Baseline" (`P_BASELN`). It compares every object of the packages with GitHub, writes what differs or is missing, and also the content that abapGit does not write (table rows, variants, profiles; see [NOT-IN-GIT.md](NOT-IN-GIT.md)) to the branch `review/CONTENT-BASELINE`, and opens a pull request. It lists what nothing can write. Merge that pull request as an initial import: nobody can review thousands of files, so an admin merges it.
3. **Turn on the review rule** with `github-protect-master.sh <owner> review <repository>`, only after the initial content is on the base branch.
4. **Tick** "Refuse requests with entries that cannot be written to Git" in `ZTR_SETUP` only when the baseline shows no gaps.
5. **Tell the developers with open requests** about the one-time extra review in the row "released before the installation". Their first request release will be refused with the list of files; this is expected.
6. **Test with one real task** (INSTALL, "End-to-end test") before everybody starts.

## Questions that come up

- *Will the push of an open transport say "no changes"?* Yes, for every file that is already identical on the branch; if all are identical the job ends with "nothing to push" and no pull request is added.
- *Does the baseline run again?* Only when you start it. Run it again after a big change that bypassed the tools, for example a client copy or a transport import from another system into a package under Git.
- *Is the baseline a security or consistency risk?* It writes only to a review branch. The base branch changes when its pull request is merged.
