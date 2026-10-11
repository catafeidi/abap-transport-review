# Contributing

Thank you for helping. Everybody can take part: report a problem, tell us about an object that is not supported, improve the documentation, or change the code.

## Report a problem or an unsupported object

Open an issue and choose the form that fits: [new issue](https://github.com/catafeidi/abap-transport-review/issues/new/choose).

- **An object or entry that is not written to Git.** The pull request lists it under "Not in Git". Tell us the object type, your abapGit version and your SAP release, so that we can see whether it can be supported.
- **A bug.** Say what you did, what you expected and what happened, with the message or the job log.
- **An idea.** Say which problem it solves.

Do not put names of companies, hosts, users, tokens or customer data into an issue. Remove them from messages and logs first.

Reports from other SAP releases than the ones listed in [Supported systems](README.md#supported-systems) are especially welcome: say which release you used and whether it worked.

## Change something

1. Fork the repository and create a branch for your change.
2. Make the change.
   - **Documentation:** edit the Markdown files.
   - **ABAP:** the code is in the abapGit layout under `src/`. The easiest way is to pull your fork into a development system with abapGit, change the objects there and push the branch.
3. Check it:
   - ABAP must be valid for **ABAP 7.40 SP08**. A source can be compiled on a system without creating anything with `scripts/syntax-check.py`.
   - The check `abaplint 7.40` runs on every pull request. It must pass.
   - Add or update ABAP Unit tests for logic you change. Tests that write to the database must have the risk level `DANGEROUS`.
   - Follow [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md): small methods, clear names, no commented-out code.
4. Open a pull request. Say **what** changed, **why**, and **how you checked it** (system release, tests run). The template asks for it.
5. A maintainer reviews it. Please answer remarks on the pull request. A change is merged when a maintainer has approved it and the checks have passed.

Keep a pull request small and about one thing. Use English, and the terms of SAP, HTTP and Clean ABAP: do not invent new names for known things.

## Rules

- No secrets, and no names of companies, hosts, systems or people in code, tests, documentation or examples. Use placeholders such as `ABC-123`, `<owner>` and `my-abap-repo`.
- Anything the tools write to GitHub or to the system must be explained in the documentation.
- Be respectful. Disagree about the code, not about people.

## Licence

By contributing you agree that your contribution is licensed under the [MIT licence](LICENSE) of this project.
