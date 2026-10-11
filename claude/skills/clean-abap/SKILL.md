---
name: clean-abap
description: Use when writing, generating, or modifying ABAP code, or when reviewing / code-reviewing ABAP objects (classes, function modules, programs, includes, interfaces, transports). Applies SAP's Clean ABAP style guide. Triggers on ABAP, SAP, .abap source, SE80/SE24/SE37/ADT objects, and transport reviews.
---

# Clean ABAP

Apply SAP's [Clean ABAP](https://github.com/SAP/styleguides/blob/main/clean-abap/CleanABAP.md) style guide when producing or reviewing ABAP. The full guide is bundled at `reference/CleanABAP.md` — open it for exact rule wording, rationale, and edge cases. The checklist below is the working subset; the bundled guide is authoritative.

## Two modes

**Generating / modifying ABAP** → follow the checklist by default. Match the surrounding code's existing conventions where they conflict with a purely cosmetic rule, but prefer Clean ABAP for anything that affects correctness, safety, or readability.

**Reviewing ABAP** → report each issue as:

```
[Severity High/Medium/Low] short title — `offending snippet` (line N) — Clean ABAP rule — one-line concrete fix
```

Group repeated trivial issues into one finding with 2-3 examples. Separate genuine defects from style. Verify a claim against the source before reporting it (e.g. an active object cannot contain a syntax error — `=>` inside a logical expression is the obsolete `>=` operator, not a typo). When unsure of the exact rule wording, check `reference/CleanABAP.md`.

## Checklist

### Naming
- No Hungarian / type-encoding prefixes (`lv_`, `lt_`, `ls_`, `lo_`, `gv_`, `gt_`, `mo_`, `mt_`, `l_`, `r_`, `i_`…). Use meaningful names.
- Booleans read as predicates: `is_`, `has_`, `was_`. A `has_x` that holds three values (`'Y'/'N'/' '`) is wrong — make it a real flag or enum.
- No cryptic or digit-leading names (`1st_plugin`). Descriptive over abbreviated.

### Modern constructs (avoid the obsolete form)
- `NEW #( )` not `CREATE OBJECT`.
- Functional call `obj->meth( )` / `cls=>meth( )` not `CALL METHOD`.
- String templates `|{ a }_{ b }|` not `CONCATENATE`.
- Inline `DATA(x) = …` / `FINAL(x)` not a separate `DATA:` block far away.
- `VALUE`/`CORRESPONDING`/`FOR`/`REDUCE` and table expressions `tab[ key = … ]` / `line_exists( )` / `line_index( )` instead of manual work-area loops and `READ TABLE … BINARY SEARCH` where a sorted/hashed table fits.
- No `TYPE-POOLS`, no header-line internal tables (`… OCCURS 0 WITH HEADER LINE`), no `MOVE`/`COMPUTE` keywords, no `TRANSLATE … TO UPPER CASE` (use `to_upper( )`).

### Methods & signatures
- A method does one thing; keep it short. Watch for 1000-line "god routines."
- Few parameters (aim ≤ 3). Prefer `RETURNING` over a single `EXPORTING`.
- No boolean input parameters that select behavior — split the method instead.
- Avoid optional/defaulted parameters that hide complexity.

### Control flow
- Return/exit early; avoid deep `IF` nesting.
- `CASE` over long `ELSEIF` ladders.
- No empty/`WHEN OTHERS` branches that silently swallow.

### Error handling
- Class-based exceptions, not numeric return codes or `sy-subrc` propagation.
- After calling a procedural FM with `EXCEPTIONS … OTHERS = n`, actually evaluate `sy-subrc` and raise — don't ignore it. Never rely on `sy-subrc` after a *functional* method call.
- Don't catch `cx_root` broadly; catch specific exceptions.
- No empty `CATCH`, no `IF sy-subrc <> 0.` blocks containing only a comment, no `* Implement suitable error handling here` left behind.
- Don't misuse `MESSAGE … TYPE 'X'` for control flow.

### SQL
- Explicit field list, never `SELECT *`.
- Always a `WHERE`; use `SELECT SINGLE` / `UP TO 1 ROWS` for one row instead of `SELECT … ENDSELECT` + `EXIT`.
- No `SELECT` inside loops.

### Constants, literals, booleans
- No magic numbers / character literals (`'A'`, `'B'`, `'T'`, `'2'`, `100`, `'PREVIEW OF'`) — route through a typed constants interface of the project.
- Constants should be typed to their real DDIC domain, not bare `STRING`/`C`; group related constants with `CONSTANTS BEGIN OF …`.
- Use `abap_true` / `abap_false` / `abap_bool`, not `= 'X'` / `= space`.

### Comments & dead code
- Delete commented-out code and dangling commented conditions (`… CO '456789'. "ABC-123 AND` with the operand commented out).
- No `*&---*` divider banners or "what" comments; express intent in code.
- Remove leftover `BREAK-POINT`, unused variables/field-symbols, and outdated header banners.

### DRY
- Extract duplicated blocks (repeated export/zip logic, copy-pasted reports) into a shared method/class.

## When the checklist isn't enough
Open `reference/CleanABAP.md` and search for the relevant section (it has anchors like "Prefer functional to procedural language constructs", "Use exceptions", "Avoid encodings"). Cite that section in reviews.
