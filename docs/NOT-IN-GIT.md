# What a transport carries beyond repository objects

abapGit turns repository objects into files under `src/`. A transport carries more: table rows, report variants, authorization profiles, texts, SAP Note entries. These have no abapGit file. Class `ZCL_TR_CONTENT` writes them as JSON under `content/`, in the same commit and the same pull request, so that they are reviewed too. abapGit ignores the folder, because the repositories start in `/src/`.

| Entry of the transport | File |
|---|---|
| Table rows: `TABU`, `TDAT`, `VDAT`, `CDAT` (views and clusters as their tables) | `content/tables/<table>.json`: the rows of every key that was transported, sorted by key, without the client. A row deleted on the system leaves the file |
| Logical transport objects without an abapGit type, for example authorization profiles (`SUSP`) and object class assignments (`SUSK`) | their tables, from the definition in `OBJSL` (tables and key mask per object type), in the same table files |
| Old OTR texts (`SOTR`, per package) | rows of `SOTR_HEAD` and `SOTR_TEXT` of the concepts of the package |
| Report variants (`LIMU VARX`, `LANG VARI`) | `content/variants/<report>.<variant>.json`: header, texts and values |
| ALV layouts | rows of `LTDX` (they travel as `TABU LTDX`) |
| SAP Note implementations (`NOTE`, `CINS`, `CORR`) | `content/notes/<object>.<name>.json`: note number and version, not SAP's code |
| Anything else | not written; listed under "Not in Git" in the pull request and in the job log |

The repository of an entry is the one whose package owns it: the table, the profile, the program of a variant. Rows of an SAP table go with the object their key names, and anything without an owner goes where the other objects of the same transport go.

Transports of copies are never pushed.

The release check compares these files like source files: a changed row, variant or profile needs an approved pull request before the release.

## Credentials

In every table file, fields whose name, data element or domain contains CRED, PASS, PWD, SECRET, TOKEN or PRIVATE are blanked (the class has a short list of further field names for the same purpose). This is a best-effort deny-list on names: a credential in a field with an ordinary name is not found, and variant values are not masked. Review `content/` before a repository is made public.

## Not in Git

Every pull request lists the entries of its request that nothing could write, so the reviewer checks them on the system. With the STVARV parameter `ZTR_REQUIRE_COMPLETE` = `X` (tick "Refuse requests with entries that cannot be written to Git" in `ZTR_SETUP`) such a request is refused at release with "not everything can go to Git". Switch it on once the baseline shows no gaps.

What abapGit itself cannot write depends on its version and on the release of your system. When abapGit is updated, run the repository view once: objects that a newer version can serialize show up as new files and the list gets shorter.

Some entries are outside Git by nature: for example client-specific customizing that travels in customizing requests and is not a repository object. In a review, look at the object list of the request on the system as well as at the pull request.

## Baseline

`ZTR_PUSH_TRANSPORT` with the baseline option and no task or request compares every object of the package tree with GitHub (anything changed or missing there goes along) and writes the content above for everything already in the packages: objects without abapGit type, the rows of the tables SAP marks as delivered content (delivery class E, S, G) plus the tables you list on purpose in the STVARV select option `ZTR_CONTENT_TABLES`, and the variants and ALV layouts of the programs. It pushes to `review/CONTENT-BASELINE` and opens a pull request. With "Test run" it only lists what would be written and what nothing can write: that list is the completeness report, and it must be empty before `ZTR_REQUIRE_COMPLETE` is switched on.

## Bringing `content/` into another system

abapGit pulls only `src/`. A change that arrives through Git (an upport from another line, a change from another repository) therefore brings its classes and tables with the pull, but not its table rows, variants and notes. Report `ZTR_APPLY_CONTENT` (class `ZCL_TR_CONTENT_APPLY`) does that part:

1. Create the workbench request for the change (start its text with the issue key, see [JIRA.md](JIRA.md)) and run the abapGit pull of the changed objects into it.
2. Run `ZTR_APPLY_CONTENT` without "Write": per file it lists the rows or variants that are new, different, equal and only on this system. Nothing is changed.
3. Run it again with "Write" and the same request in "Request or task" (or with that field empty and a text, which creates a request with a task of the current user). For every table and variant, the keys are recorded in the request first; only then the rows are written and committed. The request travels on like any other.

| Field on the screen | Meaning |
|---|---|
| Package of the abapGit repository (`P_PACK`) | the package that the repository is linked to in abapGit on this system. The report takes the online repository with exactly this package and stops if there is none |
| Branch to read content/ from (`P_BASE`) | the Git branch, without `refs/heads/`. Default `master`, which holds the reviewed state. It is fetched fresh from GitHub; abapGit's selected branch of the repository is put back afterwards |
| Request or task (not released) (`P_TRKORR`) | where the changes are recorded. Only used with "Write". A request is resolved to your own open task in it; a task is used directly. Released ones are refused |
| Text of a new request (Jira key first) (`P_TEXT`) | only with "Write" and an empty request field: a workbench request with this text and a task for you is created first |
| Write (`P_WRITE`) | off (default) = test run, nothing is changed. On = write the rows and variants and record them in the request |
| Delete (`P_DEL`) | only together with "Write": rows that only this system has are removed from the table and recorded in the request. Off (default) = they are only listed |

The list shows one line per file: kind (T table, V variant, N note), name, and the counts new, different, same, only here, then the result (`written`, the message, or `FAILED:` with the reason). A failed file is rolled back and reported without stopping the others.

| File | Behaviour |
|---|---|
| `content/tables/<table>.json` | Compared by key. New row: inserted. Different row: overwritten. Row only on the system: listed, removed only with "Delete". Written into the logon client, because a file holds no client. Credential fields are never taken from Git: an existing row keeps the system's values, a new row gets them blank (fill them by hand; the report says so). Tables that are not transparent tables on the system are skipped with a message Only tables that the tools themselves write to Git are accepted: a transparent table of a package under Git (STVARV `ZTR_PACKAGES`) with delivery class E, S or G, or listed in `ZTR_CONTENT_TABLES`; any other file is skipped with a message. Writing needs `S_TABU_NAM` activity 02 for the table, and `S_TABU_CLI` for a client-independent table. |
| `content/variants/<report>.<variant>.json` | Created or changed through the standard variant function modules when the report exists on the system; written as stored records when it does not. Client-independent variants (`%` or `&` in the name) are skipped Only variants of a report in a package under Git, or product variants that match `ZTR_VARIANT_PATTERN` in the package `ZTR_VARIANT_PACKAGE`; others are skipped. For a report that exists, a file without readable values is skipped. Writing needs `S_TABU_NAM` activity 02 for `VARID`, `VARI` and `VARIT`. |
| `content/notes/<entry>.json` | Only reported: note missing or older here, to be implemented in SNOTE |

Limits: a table is read completely, so the report is meant for delivered and customizing tables, not for large application tables. Rows of a key longer than the transport key allows (a string key field) cannot be recorded and fail that table. The deletions of a file are rows missing in it: with "Delete" off, a row removed on the source system stays on the target.

## The files under `content/`

Names are written as abapGit writes them: lower case, `/` becomes `#`, a space becomes `_`. A table `/NAMESPACE/TABLE` is `content/tables/#namespace#table.json`.

**Table file.** A JSON array, one object per row, field names in lower case, sorted by key. The client field is present and empty, because Git holds the delivered content and not the client it came from. Credential fields are present and empty. Rows of the keys a transport carried are in the file; rows of other keys already in Git stay.

```json
[
  { "property": "DEBUG",   "group": "Support", "type": "CHAR1" },
  { "property": "KEEP_DAYS", "group": "Support", "type": "INT4" }
]
```

**Variant file** `content/variants/<report>.<variant>.json`: an object with `header` (the variant header, without the user and the time stamps that change with every save), `texts` (the variant texts per language) and `values` (the selection values as `RS_VARIANT_CONTENTS` returns them). When the system that wrote the file does not have the report, `raw_values` holds the stored records instead of `values`.

```json
{ "header": { "report": "ZREPORT", "variant": "TEST", "mlangu": "E" },
  "texts":  [ { "langu": "E", "report": "ZREPORT", "variant": "TEST", "vtext": "testing" } ],
  "values": [ { "selname": "P_FILE", "kind": "P", "sign": "I", "option": "EQ", "low": "x" } ] }
```

**Note file** `content/notes/<object>.<name>.json`: `pgmid`, `object`, `obj_name`, `note` and `version`. It records which note in which version was implemented, not SAP's code.

## gCTS

gCTS keeps everything a transport keeps, including table rows and variants, in its own JSON per object, because it works from the transport export and not from the repository objects. It needs a recent SAP_BASIS release and has no review step before the release. It is an option for moving released transports between systems, not a replacement for the files above.
