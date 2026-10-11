# Claude Code skills for ABAP work

| Skill | What it does |
|---|---|
| `skills/clean-abap` | A checklist and the bundled guide (SAP's Clean ABAP) that Claude Code applies when it writes or reviews ABAP |

## Use it

Copy the folder `skills/clean-abap` to `.claude/skills/` of the project (or `~/.claude/skills/` for all projects). Claude Code loads it automatically when ABAP is written or reviewed.

## Attribution

`skills/clean-abap/reference/CleanABAP.md` is SAP's **Clean ABAP** style guide, taken from <https://github.com/SAP/styleguides> (`clean-abap/CleanABAP.md`). It is an adoption of Robert C. Martin's *Clean Code* for ABAP. It is SAP's work, published under the **Creative Commons Attribution 3.0 (CC BY 3.0)** licence (<https://creativecommons.org/licenses/by/3.0/>, licence file of the SAP/styleguides repository); credit: SAP SE and the Clean ABAP contributors, <https://github.com/SAP/styleguides>. The copy here is included without changes to its text; its relative links point into the SAP repository and do not work from this copy. It is not covered by the MIT licence of this repository. `SKILL.md` and this README are a short checklist derived from that guide.

## Rules a team can add on top

The skill is the general guide. Rules of your own sit on top of it, and the machine checks them, not the skill. Examples:

- **Clean ABAP names without abbreviations, interfaces and constructor injection, only a composition root uses `NEW`, small single-purpose classes, unit tests with test doubles.** Checked by `github-templates/abaplint-new-repository/abaplint-clean.json` on GitHub and by the same rules in the abaplint client of the SAP system ([../docs/ABAPLINT-IN-SAP.md](../docs/ABAPLINT-IN-SAP.md), section 5).
- **Code that must run on 7.40 SP08 and in ABAP Cloud together:** no `int8`, no `FINAL( )`, no enumerations, no `RAISE EXCEPTION NEW`. The skill mentions `FINAL( )` as modern, but such code must not use it. abaplint does not catch `int8`, so a real syntax check on a 7.40 system is the gate.
- **Old code:** not checked against Clean ABAP when it would give thousands of findings; new code follows the guide, old code is not reformatted.
- **Names:** class and method names are at most 30 characters including the namespace.
