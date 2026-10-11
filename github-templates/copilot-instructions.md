# Instructions for the review of pull requests

Copy this file to `.github/copilot-instructions.md` of the product repository and adapt it. It is a starting point for GitHub Copilot code review; it does not replace the review of a colleague.

This repository holds ABAP code in the abapGit layout (folder `src/`). The code must be valid for SAP NetWeaver 7.40 SP08.

Look for, and comment on:

- Syntax that is not valid on 7.40 SP08, for example `FINAL( )` declarations and the type `int8`.
- Behaviour that is wrong or unclear: unhandled exceptions, `sy-subrc` not checked after a call that can fail, `SELECT` in a loop, `SELECT *` where a few fields are needed.
- Missing authority checks where data is read or changed for a user.
- Names or comments that do not follow the Clean ABAP guide (<https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md>): long methods, many parameters, flags that change behaviour.
- Missing or weak ABAP Unit tests for new logic.
- Secrets, tokens, passwords, host names or personal data in code, in content files under `content/` or in test data.

Say what is wrong and why, and suggest a change. Do not comment on style that the abaplint workflow already reports.
