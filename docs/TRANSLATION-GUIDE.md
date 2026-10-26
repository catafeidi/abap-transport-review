# Translating with ZTR_TRANSL_REPORT: step by step

This guide is for everybody who translates texts of the product: developers, a product owner, a translator. It says what to run and what to type. How the check works inside, its settings and the check at release are in [TRANSLATION-CHECK.md](TRANSLATION-CHECK.md).

The examples use German (`D`) and English (`E`) as the required languages; any other set works the same way.

## In short

`ZTR_TRANSL_REPORT` lists every text of the product that has no translation, and lets you translate it in one of two ways:

| Way | When | What you do |
|---|---|---|
| **A. In the list** | you work in SAP GUI and have a few dozen texts | tick "Enter translations", type the translations into the list, Save |
| **B. Excel or CSV file** | many texts, a translator without SAP, a translation tool, or translating with AI | Download, fill the file, Upload, check the list, Save |

Both end the same way: **Save** writes the translations exactly as SE63 does and records them in your request, so that they are transported. Nothing is written before Save.

A third way finds you by itself: when you release a task with missing texts, the release check offers "Translate now", which opens the editable list of exactly that task, with the buttons of way B in its toolbar.

## Before you start

**Once per system** (normally done already): report `ZTR_SETUP`, block "Translation check at release": required languages, for example `D` and `E`, mode as agreed by the team, "Write the settings". If the report later says "No language to check", this step is missing.

**Every time:**

1. A **workbench request** for the translations, with the issue key in its short text (SE09, Create; or use the request of the change you are working on). If you forget it, Save asks for one with the standard request dialog; Cancel there writes nothing.
2. Your user needs to be able to run SE38 programs, to own a task in that request, and to translate (as for SE63).

## Way A: translate in the list

1. SE38, `ZTR_TRANSL_REPORT`, F8 to the selection screen.
2. **What to check**, one of:
   - *Task or request*: the objects of one request, or
   - *Packages*: for example `ZMY_PACKAGE`. **First delete the rows in "Namespaces"** if there are any: they are filled in by default when your package pattern is a namespace, and namespaces win over packages.
   - *Namespaces*: everything (for example `/MYNS/`), takes minutes.
3. *Languages*: leave empty (the required languages from the settings), or type the languages you want.
4. Block **Translate in the list**: tick *Enter translations*. *Record in*: your request.
5. Block **Excel or CSV file**: leave *No file: show the list*.
6. F8. The list shows one line per missing text and language:

   | Column | Meaning |
   |---|---|
   | Status | `missing EN`: the text has no English translation |
   | Kind of text | where the text appears, see "Kinds of text" below |
   | Language | the language the translation is for |
   | Source text | the text as it exists, in its original language |
   | **Translation** | type here |
   | Max. length | the longest translation SAP can store for this text |
   | Length, light, Length check | how long your text is: green `OK`, red `Too long by N` |

7. Type the translations. Press **Enter** or move to another cell: Length and the light update. A red light means the text will not be saved; shorten it.
8. **Save** (the disk button of the list). The message says how many translations were written and in which request. Saved lines show `saved`.
9. Run the report again with the same selection: what you translated is gone from the list.

Texts you do not want to translate yet: leave the cell empty. Only typed cells are saved.

## Way B: translate in an Excel file

### 1. Download

1. `ZTR_TRANSL_REPORT`, the same selection as in way A, steps 2 and 3. *Enter translations* is not needed for the download.
2. Block **Excel or CSV file**: *Download the texts to translate as an Excel file*. For CSV files instead, also tick *As CSV files instead* (see "CSV instead of Excel" below). F8.
3. Choose where to save the file. The message says how many texts it holds.

With *Hardcoded texts in the source code* ticked under **Show also** (the default), the file has a second sheet, **Hardcoded texts**: one line per text written directly in the code, with type, object, include, line, kind and the text, and two columns to fill, *Proposed English* and *Proposed German*. These texts cannot be uploaded: a developer moves each one into a message or a text symbol (see "Fixing hardcoded texts") and uses the proposals for its texts. The upload reads only the first sheet.

**All texts of a product line in one file:** leave *Task or request* empty and keep one namespace in *Namespaces*, for example only `/MYNS/`, then a second run with only `/MYNSREP/`. A whole namespace takes a few minutes.

### 2. Fill the file

The file has one line per missing text and language:

| Column | |
|---|---|
| Type, Object | where the text belongs |
| Kind of text | where the text appears (message, field label, dropdown value, ...), see "Kinds of text" |
| Source language | the language the source text is written in (DE, EN, ...) |
| Source text | the text to translate |
| Proposed source text | optional: a better wording of the source text itself (yellow, can be typed in) |
| Target language | the language to translate into (EN, DE, ...) |
| **Translation** | the translation (yellow, can be typed in) |
| Max. length | the limit for this text |
| Length, Length check | filled by Excel: `OK` or `Too long by N`; a text that is too long turns red, and Excel warns when you enter one |

Rules:

- Type only into **Translation** and, when needed, **Proposed source text**. The sheet is protected so that nothing else changes; the hidden columns find the text again in SAP. Do not unprotect the sheet, do not add, delete or sort rows by copying them elsewhere. Filtering by Target language is fine.
- Leave a cell empty if you do not translate that text; it is skipped.
- Keep placeholders exactly as they are: `&1`, `&2`, `&`, `%1`.
- Use the terms of your glossary (template: [github-templates/translation-glossary.md](../github-templates/translation-glossary.md)). Product names and some product terms stay untranslated on purpose.
- Save as `.xlsx` (Excel's normal format). Keep the file name if you like; the report does not care about it.

**With AI** (Claude, Copilot, ...): give it the file and the glossary, and ask for example:

> Fill the column "Translation" of this Excel file. Translate the column "Source text" (written in the language of the column "Source language") into the language in the column "Target language". Respect "Max. length" (number of characters) for each line; if the text does not fit, shorten it without losing the meaning. Keep placeholders such as &1 and & unchanged. Use the glossary for product terms; terms listed as staying untranslated stay as they are. Formal address. If a source text has a typo or an unclear wording, write the corrected source text into "Proposed source text" on that line. Do not change any other column and do not add or remove rows. Return the file as .xlsx.

Then read the result before uploading: the AI is the translator, you are the reviewer.

### CSV instead of Excel

Excel can change a value it thinks it recognises, for example a date or a number. The Excel file of the report prevents that: every cell is text. A translation tool (Trados, memoQ, Phrase, ...) or a text editor often works better with CSV. With *As CSV files instead* (or **Download CSV** in the toolbar of the editable list) the report writes:

- `translations_<scope>.csv`: the same columns as the Excel file, without Length and Length check, and with every column visible (the last five find the text again in SAP: do not change them);
- `translations_<scope>_hardcoded.csv` next to it, when there are hardcoded texts: the columns of the sheet "Hardcoded texts".

The files are UTF-8 with byte order mark. Every value is in quotes, and the values are separated by semicolons. A CSV file has no colours, no length check and no protection. So check Max. length yourself, and change only *Translation* and *Proposed source text*.

**Do not open a CSV file in Excel by double-click.** That is exactly when Excel changes values (dates, leading zeros, text starting with `=`) and can break umlauts. To look at it in Excel anyway, use *Data > From Text/CSV*, set every column to Text, and save it again as *CSV UTF-8*. Better: use the Excel file in Excel.

The upload reads both formats: an `.xlsx` file, or a CSV file in UTF-8 separated by semicolons, commas or tabs.

**When the source text itself is wrong** (a typo, an unclear wording, a term outside the glossary): type the better wording into **Proposed source text** on that line. As soon as it differs from the source text, both cells turn orange, so every proposed change is visible; filter the column *Proposed source text* to see only those lines. A proposal longer than Max. length turns red.

A proposal is **never written** by the upload: the source text belongs to the object (the message, the program, the data element) in its original language, and changing it is a change of the object. The upload shows the proposals in a popup list (Object, Kind of text, Source text now, Proposed source text), once per text, also when it was typed on the line of each target language. Export that list (button of the list) and give it to a developer, who changes the objects in a task: SE91 for a message, the text elements for a program or class, and so on, logged on in the source language. After that change the existing translations of that text must be checked by hand, because they were made for the old wording; the report does not list them, since they are not missing.

### 3. Upload and save

1. `ZTR_TRANSL_REPORT`. Block **Excel or CSV file**: *Upload a translated Excel or CSV file into the editable list*, *File to upload*: the file (F4 opens the file dialog). *Record in*: your request.
2. F8. The report checks the objects of the file again and opens the editable list, already filled with the translations of the file. **Nothing is written yet.**
3. Look at the list: lights, texts. Correct a cell if needed.
4. **Save**. From here it is exactly way A, step 8.

**From the list itself.** The editable list (way A) has three buttons in its toolbar: **Download Excel** and **Download CSV** write the lines of the list as the file of step 1, with what you have typed so far; **Upload file** asks for an Excel or CSV file and puts its translations into the lines of the list. As above, nothing is written until Save; the message says how many translations were taken, how many were left out because the source text changed, and how many are not in the list.

The title of the list tells you what happened to the file:

| Title says | Meaning |
|---|---|
| `N translation(s) to save` | lines of the file that will be written on Save |
| `M left out (source text changed)` | the source text was changed in SAP after the download: download again for these |
| `K not missing any more` | translated in the meantime (by someone else, or an earlier upload) |

## Kinds of text

The column *Kind of text* says where a text appears, so that it can be worded for its place. The SE63 type next to it (in the list, hidden in the file) is for developers.

| Kind of text | Where the user sees it | Hint |
|---|---|---|
| Message (status bar or popup) | the line at the bottom of the screen, or a popup | a full sentence; keep `&1`, `&2`, `&` |
| Text in a program (text symbol) | anything a program writes: list titles, popup lines, column texts | as long as Max. length allows |
| Selection screen field label | the label in front of a field on a selection screen | short, no sentence |
| Program title | the title bar of a report | short |
| List heading | the heading of a classic list | short |
| Screen text (label, frame, button) | labels, frames and buttons of a screen (dynpro) | often very short |
| Menu, button or title (GUI status) | menu entries, toolbar buttons, function keys, window titles | very short; one word if possible |
| Field label (screen, table column) | the label of a field wherever it is used, also as column heading in lists | four lengths exist (short to long); each line has its own Max. length |
| F1 help of a field | the help text when the user presses F1 | a sentence or a short paragraph |
| Dialog text (popup) | the text of a popup | a sentence |
| Value in a dropdown list | an entry of a dropdown or value help | short noun |
| Transaction name (menu, launchpad tile) | SAP menu, favourites, launchpad tiles | short, use the glossary term |
| Web or UI text (OTR) | texts of web user interfaces | as for screen texts |
| Title of a maintenance view (SM30) | the title of a table maintenance screen | short |
| Web Dynpro screen text | texts of Web Dynpro applications | as for screen texts |
| Field label of a CDS view (Fiori app) | labels of fields and columns in Fiori apps built on the CDS view | short, as for field labels |
| UI text of a CDS view (Fiori annotation) | headers, labels and object names of a Fiori elements app ("Object", "Objects") | short; singular and plural come as two lines |
| Launchpad tile (title, subtitle) | title and subtitle of a tile in the Fiori launchpad | short, use the glossary term |
| Hardcoded text in the source code | not translatable as it is | a developer moves it into a message or a text symbol |
| Entry of a text table (SM30) | an entry of a customizing table | translated in SM30 or SE63 |
| Other (SE63 type ...) | rare types | ask a developer where it appears |

## Way C: at release

When the check at release is switched on (mode INFORM or BLOCK) and you release a task with missing texts, a popup names them and offers **Translate now**. It opens the editable list of the missing texts of what you release; Save records the translations in it. Then:

- **In the list:** translate, Save, leave the list (Back). The release stops with "translations saved. Release ... again": release again, and the check passes.
- **With an Excel or CSV file** (many texts, a translation tool, or AI):
  1. **Download Excel** (or **Download CSV**) in the toolbar of the list, save the file. Back: the release is refused in mode BLOCK (in INFORM it goes on), because the texts are still missing.
  2. Fill the file as in way B.
  3. Release again, **Translate now**, **Upload file** and the file. Check the list, Save, Back. Release once more: nothing is missing any more, and the release goes through.

After "Translate now" the release always stops, also when you leave the list without Save; release again when you are ready. The release that comes back from the list cannot go on, because it would not carry the translations just saved. Details: [TRANSLATION-CHECK.md](TRANSLATION-CHECK.md), "At release".

## Hardcoded texts and table entries

Without *Enter translations* and without a file, the list also shows two kinds of lines that cannot be translated by typing:

| Status | What it is | What to do |
|---|---|---|
| `hardcoded: message`, `hardcoded: screen text`, ... | a text written directly in the source code, e.g. `MESSAGE 'No entries selected' TYPE 'E'`. SAP cannot translate it | a developer moves it into a message of the message class or a text symbol, then it is translated like any other text. Double-click the line: the source opens at the line (column Where) |
| `hardcoded: text constant` | a constant with words in it | check whether a user sees it; many are technical and stay |
| `table entry missing EN` | an entry of a text table (column Where = its key) exists in one language but not in English | translate it in the maintenance view (SM30) logged on in English, or in SE63, and record it in the request |

Uncheck *Hardcoded texts* and *Entries of text tables* under **Show also** to hide them.

## Fixing hardcoded texts

There is no automatic fix: the report sees *that* a literal is shown, not *how* it should be shown. Which message class, whether a message or a text symbol fits, which parts become `&1` to `&4`, whether the user sees it at all: that needs the code around it. A developer decides; AI can propose. The fix is a code change in a task and goes through the normal review.

### The rules

| Found | Fix |
|---|---|
| `MESSAGE 'text' TYPE 'E'` / `'W'` / `'I'` / `'S'` | a message of the message class the program already uses (`MESSAGE-ID` of the report, or the class of the package). First look for an existing message with the same meaning; otherwise the next free number. Variable parts become `&1` to `&4`: `MESSAGE e101(zmy_messages) WITH name.` |
| `MESSAGE 'text' TYPE 'X'` (short dump) | the user reads it only in ST22. Use a message number, so that the dump text is translated (`MESSAGE x100(zmy_messages) WITH sy-repid.`), or an exception class. Changing the type (for example to `E`) changes the behaviour: only on purpose |
| `MESSAGE e001(00) WITH 'text' ...`, `MESSAGE ID '00' ...` | its own message in the message class of the package |
| `WRITE 'text'`, popup texts (`POPUP_TO_CONFIRM`, ...), ALV and SALV column texts | a text symbol: `'Text'(101)` or `TEXT-101`, in the text pool of the program or class |
| `CONSTANTS ... VALUE 'text with words'` | find where it is used; only if the user sees it, as above. Most are technical and stay |
| a text that is a leftover from development (`tbd`, `test`, ...) | delete the statement |

After the code change:

1. Enter the texts of the new message or text symbol in **every** required language: the message in SE91 (or the text symbol in the text elements), then `ZTR_TRANSL_REPORT` with the task, "Enter translations", for the other languages.
2. Run the report for the package again: the line is gone from the hardcoded texts.
3. Release the task. The pull request shows the code change and the new texts.

### With AI

Give the AI the sheet **Hardcoded texts** of the downloaded file (or export the hardcoded lines from the list: ALV, Export, Spreadsheet) together with read access to the system (or the sources of the objects) and these rules. The AI can also fill *Proposed English* and *Proposed German* in that sheet. Example prompt:

> For each line of this list (object, include, line, text), read the source at that line and propose the change that makes the text translatable, following the rules in docs/TRANSLATION-GUIDE.md, "Fixing hardcoded texts". Prefer an existing message of the message class the program uses; propose a new message only when none fits, with its text in every required language and the next free number. For TYPE 'X' keep the dump unless told otherwise. Do not change anything on the system: return one proposal per line with the old statement, the new statement, the message or text symbol to create (with all texts), and a one-line reason. Mark lines you would leave as they are, with the reason.

Then review every proposal like any code change, apply it in your task, enter the texts, release.

## After saving

1. Release your task (SE09). The Git workflow pushes the translations to the review branch like any other change; the pull request shows them as changed files.
2. Run the report once more for the same selection: the list should be empty, or only show what you left on purpose.

## Status and lights

| What you see | Meaning |
|---|---|
| `missing EN` / `missing DE` | no translation in that language |
| `same as source EN` | the translation equals the source text; shown with *Show also: same as source*. Fine for product terms, otherwise translate |
| `not readable` | SE63 could not read the object; shown with *Show also*; translate it in SE63 |
| `saved` | written in this session |
| green light, `OK` | fits the maximum length |
| red light, `Too long by N` | N characters too long: not saved |

## When something does not work

| Message | What to do |
|---|---|
| `No language to check: enter languages, or set them with report ZTR_SETUP` | type the languages in *Languages*, or run `ZTR_SETUP` once |
| `No request in "Record in": Save asks for one` | fine: Save opens the request dialog. Or enter the request in *Record in* and run again |
| `No request chosen: nothing was written` | you cancelled the request dialog; Save again and choose a request |
| `... Nothing to show` | nothing is missing for that selection; check that "Namespaces" is empty when you select packages |
| `No translation was typed` | Save found no typed cell |
| `...: 0 translation(s) to save ... Nothing to save` (upload) | the file has no line with a translation for a text that is still missing |
| `The file is not an Excel file (.xlsx)` | the .xlsx file is damaged; save it again in Excel as .xlsx (not .xls) |
| `The file is not in UTF-8: save it as "CSV UTF-8" ...` | the CSV file was saved in another code page; save it as *CSV UTF-8* (Excel) or with encoding UTF-8 (text editor, translation tool) |
| `The file has no column "Translation" ...` | the file is not one from the download; download again |
| popup after Save: `N translation(s) written, M not` | the popup names the first problem: usually a text that is too long |

## Another language

Type it into *Languages*, for example `D`, `E`, `P`. Every missing text then gets one line per language, in the list and in the file, and Save writes each language. Do not add it to the settings of `ZTR_SETUP` unless every release must ask for it. The source text of a line is the original language of the object.
