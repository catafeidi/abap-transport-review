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

## Translations

Skip this part if the product has one language only. The SAP release check (`ZTR_TRANSL_CHECK`) can make sure that a text exists in every required language; the review checks whether the texts are **right**.

Where texts are in abapGit files:

| File | Text | Language key |
|---|---|---|
| `*.tran.xml` | `TSTCT/TTEXT`, also inside `I18N_TPOOL` | `SPRSL` |
| `*.dtel.xml` | `DD04V/DDTEXT`, `REPTEXT`, `SCRTEXT_S/M/L`, also inside `I18N_LANGS` / `DD04_TEXTS` | `DDLANGUAGE` |
| `*.doma.xml` | `DD01V/DDTEXT`, fixed values `DD07V/DDTEXT` | `DDLANGUAGE` |
| `*.tabl.xml` | `DD02V/DDTEXT` | `DDLANGUAGE` |
| `*.msag.xml` | `T100/TEXT` | `SPRSL` |
| `*.prog.xml`, `*.fugr.xml`, `*.clas.xml` | text pool `TPOOL`, also `I18N_TPOOL` | `LANGUAGE` / `SPRAS` |
| `*.wdcc.xml` | `WDY_CONFIG_COMPT/DESCRIPTION`, `WDY_CONFIG_DATT/DESCRIPTION` | `LANGU` |
| `content/tables/*.json` | text columns of text tables | `language`, `spras`, `langu` |

`D` is German, `E` is English (SAP one-character language keys).

Comment on:

1. **Language matches the key.** A text under `D` must be German, under `E` English. A text in the wrong language under a key is an error.
2. **Glossary.** Use the terms of `.github/translation-glossary.md`. A term listed there as staying untranslated is correct and must not be flagged.
3. **Same text in two languages.** Flag it only when the glossary does not allow it.
4. **Languages changed together.** When a pull request changes the text of an object in one language, the other languages must change in the same pull request, unless the meaning did not change.
5. **Placeholders and markup.** `&1` to `&4`, `&`, `%s`, `&&`, HTML tags and line breaks must be the same in source and translation.
6. **Style.** The form of address the product uses (for example formal `Sie` in German), correct compound nouns and special characters (`ä`, `ö`, `ü`, `ß`, not `ae`, `oe`, `ue`, `ss`).
7. **Consistency.** The same object has the same name everywhere: transaction text, tile title and the title of the application must match in each language.
8. **Length.** A translation must fit the field (for example 36 characters for a transaction text, 20 for a short field label). Point out a translation that is much longer than the source.
9. **Product names** stay as they are.

Fixes are made in SAP and pushed again, never with "Commit suggestion" on GitHub: the next push from SAP would overwrite them.
