# Translation check

Step-by-step instructions for whoever translates: [TRANSLATION-GUIDE.md](TRANSLATION-GUIDE.md). This page explains how the check works.

Every text of the product must exist in the languages the project works in. The check finds the texts that have no translation, lists them on demand, lets the developer type the missing translations right into the list or into an Excel file, and can refuse the release of a task or request while a text is missing. It also lists two kinds of texts that SE63 cannot translate as they are: hardcoded texts in the source code, and entries of text tables that exist in one language only. Whether a translation is *correct* is a second, separate step: GitHub Copilot can review the texts in the pull request, see "Correctness: Copilot" below.

The translation check is optional. It does nothing until required languages are set, and nothing at release while its mode is `OFF` (the default).

## How it works

The texts are read with the engine of SE63 (LXE), the same that translators use. Every object is expanded into its translation objects (`LXE_OBJ_EXPAND_TRANSPORT_OBJ`), and each of them is read as pairs of source and target text (`LXE_OBJ_TEXT_PAIR_READ`). So every kind of text is read in the same way: field labels and fixed values, messages, text pools of programs and classes, GUI status and titles, OTR, transactions, Web Dynpro and FLP configurations, documentation. Nothing per object type has to be programmed; which of the SE63 types are required is one list (see "Which texts").

The source language is the original language of the object: the logon language of the developer who created it (`TADIR-MASTERLANG`, shown in SE80 and in the column Source of the report). It is not necessarily the same for every object: a product that was first developed in German and later in English has objects of both. For every required language other than the source language, each source text is compared with its translation:

| Status | Meaning | Blocks the release in mode BLOCK |
|---|---|---|
| missing EN, missing DE | the text has no translation in that language | yes |
| same as source EN, ... | the translation is the same as the source text | no, only shown on demand: product terms such as "Customizing" often stay English in German on purpose |
| not readable EN, ... | SE63 could not read the object in this language | no, only shown on demand |

The language in the status is the language the translation is missing in; the text that exists is in the column Source text, in the source language.

## Which texts

Only the texts the user sees when the product runs are required. Development itself may be in one language only: a class description or a method description that nobody but a developer reads does not need a translation.

| Checked (seen when the product runs) | SE63 type |
|---|---|
| messages | `MESS` |
| text elements: text symbols, selection texts, program titles | `RPT1` to `RPT8` |
| GUI status and titles | `CA1` to `CA7` |
| screen texts | `SRT1` to `SRT8` |
| field labels of data elements (screens, ALV columns) | `DTEL` |
| F1 help of data elements | `DE` |
| dialog texts (popups) | `DT` |
| fixed values of domains (dropdowns) | `VALU` |
| transaction texts (menu, Fiori launchpad) | `TRAN` |
| OTR texts | `SOTR`, `LOTR` |
| maintenance dialogs (SM30 title) | `TOBJ` |
| Web Dynpro and its configurations | `WDYN`, `WD`, `WC`, `VW` |
| labels of the elements of a CDS view (`@EndUserText`, Fiori apps) | `DDLT` |
| UI texts of a metadata extension (Fiori annotations) | `TLGS`, name `DDLX...`, part `06` |
| title and subtitle of a launchpad tile (app descriptor item) | `TLGS`, name `UIAD...` |

`TLGS` is one SE63 type for the texts of many repository objects. Its object name starts with the object type (4 characters), then the object name (40), then the part of the object (2); the check decides by the object type and the part.

Not checked, because only developers see them: descriptions of classes, interfaces, methods and attributes (`CLAS`, `INTF`), function groups and function modules with their documentation (`LBT1`, `FNC1`, `FU`, `CAD1`, `CAD4`), tables, structures, table types, views, domains, foreign keys, indexes, lock objects, search helps (`TABT`, `TABS`, `TTYP`, `VIEW`, `DOMA`, `DO`, `BEZD`, `INDX`, `ENQU`, `SHLP`), screen descriptions (`SRH1` to `SRH8`), packages, message classes, SET/GET parameters, variants (`DEVC`, `MSAG`, `SGPA`, `VARI`), descriptions of CDS views (`DDLS`) and of UI5 or BSP applications (`BSP`), and the other `TLGS` texts (descriptions of metadata extensions, OData models and services `IWMO`/`IWSV`, authorization object classes `SUSC`, Web Dynpro application configurations `WDCA`, ...). The report shows them with "Also descriptions"; the release check never asks for them.

The list is method `IS_RUNTIME_TYPE` of `ZCL_TR_TRANSL_CHECK`; the names of the SE63 types are in table `LXE_ATTOBT`.

**Texts of UI5 apps.** A UI5 app is a BSP application (`WAPA`); its texts are `i18n*.properties` files of the application. An app deployed to the SAPUI5 ABAP repository can be translated two ways, and both count: the language file in the app, or SE63 (the repository keeps the texts of `i18n.properties` in `/UI5/TREP_TEXT_T` and serves `i18n_de.properties` from the German translation at runtime). Class `ZCL_TR_TRANSL_UI5` reads both through the API of the repository (`/UI5/IF_UI5_REP_DT`, `/UI5/IF_UI5_REP_TEXTS_RT`), which knows its path mapping and line format; a classic BSP application without it is skipped:

- Per bundle (`i18n/i18n`, or another name such as `messagebundle`) the file without language is the text of the original language of the app (TADIR). When an app has none, the file of its original language is used (`messagebundle_en.properties`). A bundle without texts (only comments) needs nothing.
- A required language needs its file: `i18n_de.properties` or `i18n_de_DE.properties` for German, `zh_CN` (or `zh`) for Chinese, `zh_TW` for Chinese (traditional), `he` or `iw` for Hebrew; the code is the ISO code of `T002`. Pseudo languages such as `en_US_sappsd` never count.
- In the file of the language or in SE63, every key of the original with a text must have a text. Keys marked as never translated (`#NOTR` in the comment before them) do not count; when a key comes twice, the last text counts, as in Java.
- A part of the file name is a language only when `T002` knows the code (or the old codes `iw`, `in`), so `app_ui.properties` is the bundle `app_ui`.

A missing language is one line ("UI5 file missing DE", the text says how many texts it would hold); a missing or empty key is one line per key ("UI5 text missing DE", column Where = key and file). The list shows them with "Texts of UI5 apps" under "Show also", only in the list without "Enter translations": they are translated in the i18n file of the app or in SE63 for the app, not in the editable list. The release check counts them like the other missing texts (object `WAPA`); "Translate" is offered only when other texts are missing as well.

Not covered: literals in XML views or JavaScript, launchpad catalogs and groups kept as Customizing (`/UI2/` tables), texts typed into an OData model in SEGW instead of coming from a data element.

Only objects of the packages under Git are checked: objects in a package that matches the pattern of the system (STVARV `ZTR_PACKAGES`). Local objects (`$...`) never.

The objects run on 7.40 and on S/4HANA unchanged. The XCO library (`XCO_CP_I18N`) would be an alternative on newer releases, but it does not exist on 7.40, so the tools use LXE everywhere and stay one code base.

## The objects

| Object | What it does |
|---|---|
| Class `ZCL_TR_TRANSL_CHECK` | The check: settings, objects of a task or request, of packages or of a namespace, findings, the length rule of a translation |
| Class `ZCL_TR_TRANSL_FILE` | The missing texts as an Excel file (.xlsx) or as CSV files (UTF-8, `;`), and back; the Excel file is built with `CL_ABAP_ZIP` and read with iXML |
| Class `ZCL_TR_TRANSL_HARDCODED` | Hardcoded texts: literals in the source code that the user sees |
| Class `ZCL_TR_TRANSL_TABLE_TEXTS` | Entries of tables with a language key that exist in one required language and not in another |
| Class `ZCL_TR_TRANSL_UI5` | The i18n files of UI5 apps (`WAPA`): missing language files, missing or empty keys |
| Report `ZTR_TRANSL_REPORT` | The list of the findings ("run all"), ALV; with "Enter translations" the translations are typed into the list and saved, written as SE63 does and recorded in the request; download and upload of the Excel file, from the selection screen or with the buttons of the editable list (own GUI status `TRANSLATION_LIST`, a copy of `STANDARD_FULLSCREEN` of `SAPLSLVC_FULLSCREEN`) |
| BAdI implementation `ZTR_TRANSL_CHECK` (`CTS_REQUEST_CHECK`), class `ZCL_IM_TR_TRANSL_CHECK` | The check at the release of a task or request |
| Report `ZTR_SETUP`, block "Translation check at release" | Writes the settings and shows their state |

`CTS_REQUEST_CHECK` is a multiple-use BAdI. `ZTR_TRANSL_CHECK` runs next to `ZTR_RELEASE_CHECK`; each of the two can refuse a release, and neither knows about the other. `ZTR_DISABLED = X` switches both off.

## Settings

All in STVARV, written by `ZTR_SETUP` (block "Translation check at release", then "Write the settings"). A pull of the tools does not change them.

| STVARV | Kind | Meaning | Default |
|---|---|---|---|
| `ZTR_TRANSL_LANGUAGES` | select option, one row per language (I EQ) | the required languages, e.g. `D` and `E` | none: the check does nothing |
| `ZTR_TRANSL_MODE` | parameter | `OFF`, `INFORM` or `BLOCK` | `OFF` |
| `ZTR_TRANSL_EXCLUDE` | select option (EQ, CP) | object names that are never checked, e.g. `ZCL_*_TEST`, an internal tool or a deprecated report | none |
| `ZTR_TRANSL_RECORD` | parameter | `X`: at every release the translations of the released objects are recorded in the task (see "Recording at release"). Works also with mode `OFF` | not set: no recording |

A language is added later by adding a row to `ZTR_TRANSL_LANGUAGES` (in `ZTR_SETUP` or directly in STVARV). Nothing else changes. From that moment every release asks for that language too, so run the report for the new language first and translate what it lists.

## Report ZTR_TRANSL_REPORT

| Field | Meaning |
|---|---|
| Task or request | its objects and those of its tasks, exactly as the release check sees them |
| Namespaces (run all) | every object whose name starts with one of them, in any package that is not local. Filled with the namespaces of the package pattern, for example `/MYNS/` for `/MYNS/*` |
| Packages (if no namespace) | every object of the packages that match the pattern |
| Languages | empty: the required languages from STVARV |
| Show also | translations that are the same as the source text; objects SE63 could not read; descriptions that only developers see (see "Which texts"); hardcoded texts, table entries and texts of UI5 apps (all ticked by default, only in the list without "Enter translations"; the hardcoded texts also go into the sheet "Hardcoded texts" of the downloaded file) |
| Enter translations | the column Translation can be typed in; Save writes the translations |
| Excel or CSV file | "No file" shows the list; "Download" writes the texts to translate as an .xlsx file, or with "As CSV files" as CSV files; "Upload" reads a translated Excel or CSV file into the editable list (see "Translating in an Excel file") |
| Record in | the task or request the translations are recorded in, so that they are transported. Empty: the task or request above. With neither, Save asks for a request (standard dialog of the transport organizer); Cancel there writes nothing |

The first of task, namespaces, packages that is filled is used. Without "Enter translations" nothing is changed by the report. The title of the list counts the missing texts and the texts that are the same as the source.

Namespace or package: the namespace is the complete answer to "is the product translated", because it also finds an object of the namespace that sits in a package outside the pattern. The package selection is there for a part of the product. A system without a namespace (packages `Z*`) uses the package selection.

## Translating in the list

1. `ZTR_TRANSL_REPORT`, the task or request (or namespaces), tick "Enter translations", "Record in" = the request of the change.
2. The list shows every missing text: object, kind of text, language, source text, maximum length, and an empty column Translation. Type the translations. When a cell is left (or Enter is pressed), the columns Length and Length check and the light show whether the text fits: green "OK", red "Too long by N". The SAP GUI list cannot react to every key stroke.
3. Save (the standard button of the list). For every translation object and language the report reads the current texts, puts in the typed ones and writes them back with `LXE_OBJ_TEXT_PAIR_WRITE`, exactly as SE63 saves. Then it gets the transport entries of the translation (`LXE_OBJ_CREATE_TRANSPORT_SE63`, `LANG` entries) and appends them to the request (`TR_APPEND_TO_COMM_OBJS_KEYS`).
4. The saved lines show "saved". A translation longer than its maximum length is not written, keeps its red light, and a popup names it.

The maximum length is the one SE63 returns for each text (`LXE_PCX_S1-UNITMLT`): a short field label has another limit than a message or a text symbol. 0 means no limit. The length is counted in characters (method `EXCEEDED_BY` of `ZCL_TR_TRANSL_CHECK`), as Excel's `LEN` does.

## Translating in an Excel file

For a translator without SAP access, or to translate with AI:

1. `ZTR_TRANSL_REPORT` with the scope (task, namespaces or packages), "Download the texts to translate as an Excel file". The file has one line per missing text (and per text that is the same as its source, with "Show also"): type, object, kind of text, target language, source text, Translation, Max. length, Length, Length check.
2. Only the column Translation can be typed in: the sheet is protected (without password). Length (`=LEN`) and Length check are formulas, a text that is too long turns red, and Excel warns when one is entered. The columns that find the text again in SAP (SE63 type and name, text key, customer number, language key) are hidden; do not change them.
3. Translate. With AI: give it the file and the glossary (`github-templates/translation-glossary.md`, adapted to your product), and tell it to respect Max. length.
4. `ZTR_TRANSL_REPORT`, "Upload a translated Excel or CSV file into the editable list", the file, "Record in" = the request. The report checks the objects of the file again and opens the editable list with the translations of the file in it. Nothing is written yet.
5. Check the list (lights), correct what is needed, Save. Saving is exactly as in "Translating in the list".

A line whose source text was changed in SAP since the download is left out; a text that was translated in the meantime is not in the list any more. The title of the list counts both.

For a translation tool or a text editor, "As CSV files" (toolbar of the editable list: "Download CSV") writes the same lines as CSV instead. The format is UTF-8 with byte order mark, every value in quotes, separated by semicolons. The hardcoded texts go into a second file, `<name>_hardcoded.csv`. CSV has no formulas, colours or protection. The upload decides by the content: a ZIP file is read as Excel, anything else as CSV in UTF-8, with semicolons, commas or tabs as separator. The columns are found by their heading, as in the Excel file.

Long texts (documentation) cannot be typed in the list; translate them in SE63.

## Hardcoded texts

A literal in the source code that the user sees cannot be translated: SE63 does not know it. The report lists them with status "hardcoded" and the include and line in the column Where; a double click opens the source code there. What is found:

| Kind | Example |
|---|---|
| message | `MESSAGE 'No entries selected' TYPE 'E'`, or a string template |
| message 00 | `MESSAGE e001(00) WITH ...`, `MESSAGE ID '00' ...`: the variables carry the text |
| message text | a literal with words after `WITH` of a message |
| list output | a literal in `WRITE` (not an edit mask) |
| title | a literal after `WITH` of `SET TITLEBAR` |
| screen text | a literal given to a parameter or field that is shown: popups (`TITEL`, `TITLEBAR`, `TEXT_QUESTION`, `TXT1`, ...), ALV (`COLTEXT`, `SCRTEXT_*`, `GRID_TITLE`, ...), SALV (`SET_LONG_TEXT`, `SET_LIST_HEADER`, ...), `TEXT` |
| text constant | `CONSTANTS ... VALUE 'text with words'`: for review, many are technical |

Not listed: literals with a text symbol (`'Text'(001)`), names such as `/MYNS/BUTTON_ON`, URLs, markup. A literal that is first put into a variable and shown later is not found: the list is a help for the review, not a proof.

The fix is in the code: a message of the message class of the package, or a text symbol; then the text is translated like the others. See [TRANSLATION-GUIDE.md](TRANSLATION-GUIDE.md), "Fixing hardcoded texts".

## Table entries

Tables with a language in their key (text tables of customizing, templates per language, ...) hold texts that SE63 does not list with the object. The report compares the entries of the current client per language and lists an entry that exists in one required language and not in another as "table entry missing EN"; the column Where holds the key of the entry. An entry in none of the required languages (a customer entry in another language) is not listed. Translate the entries in the maintenance view (SM30) in the logon language of the translation, or in SE63, and record them in the request.

## At release

| Mode | What happens when a text is missing |
|---|---|
| `OFF` | nothing |
| `INFORM` | in SAP GUI a popup names the missing texts and offers "Translate" or "Release"; elsewhere a message. The release goes on |
| `BLOCK` | in SAP GUI the same popup with "Translate" or "Cancel"; the release is refused while a text is still missing. In ADT an error message, in the background a cancelled job `RELEASE OF <request>` |

**From ADT.** ADT shows no popup and no message of a release that goes on. In mode `INFORM` a developer who releases from ADT therefore sees the missing texts only in the pull request: the Git push adds a section "Missing translations" to its description (see [WORKFLOW.md](WORKFLOW.md)). In mode `BLOCK` and with `#DELIVERY` ADT shows the error message of the refusal; "Translate" is not available there: run `ZTR_TRANSL_REPORT` in SAP GUI with the task, translate, Save, and release again.

"Translate" opens the editable list of `ZTR_TRANSL_REPORT` for exactly what is being released, with "Record in" = the task or request being released. The translations are typed into the list; or the developer downloads the texts as an Excel file with **Download Excel** in the toolbar of the list and, at the next release, puts the translated file into the list with **Upload Excel** (see TRANSLATION-GUIDE.md, "Way C"). When the list is left, this release stops, in every mode, with the message "<request>: translations saved. Release <request> again." (or how many texts are still missing). It has to: the release works on the object list it read before Save, so it would neither carry nor push the translations just recorded. The developer releases again; with everything translated the check passes, and the translations are released and pushed to GitHub together with the task.

When a request (not a task) is released and translated this way, the translations land in the request itself. The Git release check then sees files that are not reviewed yet, pushes them to the review branch and refuses the release once; release it again after the approval. Translating at the release of the task avoids that.

The check runs for workbench and customizing tasks and requests, never for transports of copies (except with `#DELIVERY`). A task is checked with its own objects, a request with all of them.

**Delivery to customers:** `#DELIVERY` in the short text of the request (its tasks follow it). A missing translation then always refuses the release, in every mode (also `OFF`), with an error message and without "Translate": translations are made in the development requests, never in a delivery. Nothing is recorded into it. A transport of copies with `#DELIVERY` is checked too; other transports of copies are not. See [TRANSPORTS.md](TRANSPORTS.md), "A transport for a customer".

Way out for an emergency: `#NOTRANSL` in the short text of the request. The request and its tasks are released without the check, also with `#DELIVERY`. The marker stays visible in the request, like `#NOREVIEW`. The markers can be combined; each tool reads only its own.

If the check itself fails, the release is not refused; the developer gets an information message.

## Introducing it on a system

1. Pull the tools (`ZABAPGIT`, this repository, Pull). `ZTR_TRANSL_CHECK` comes active, but does nothing while the mode is `OFF`.
2. `ZTR_SETUP`: required languages (for example `D`, `E`), mode `OFF`, "Write the settings". The block "Translation check at release" must show the BAdI implementation as active and the languages.
3. `ZTR_TRANSL_REPORT` with the namespaces (or packages): this is the translation debt of today. Translate it, or put objects that are never translated into `ZTR_TRANSL_EXCLUDE`.
4. Mode `INFORM` for some weeks: developers see what is missing at every release.
5. Mode `BLOCK` once the report of step 3 is empty.

## Translations must also be transported

A translation made in SE63 is only transported when SE63 records it in a request (`LANG` entries, or the object itself). A translation that exists on the development system but is in no request passes this check and still never reaches the next system. Rules for the team:

- Put every translation into the request of the change: either SE63 records it there (when recording is switched on for the translation environment), or SLXT collects the translations into a request afterwards. `ZTR_TRANSL_REPORT` always records what it saves.
- The pull request shows translations as changed files (`TSTCT`, `DD04T`, `T100`, text pools, `WDY_CONFIG_COMPT`). A translation that is on the system but not in the pull request is not transported.

## Recording at release

The check reads the texts on the system, not what the task carries. A translation made in SE63 or SM30 and recorded in no request passes the check and never reaches another system, and a task with only code parts of an object (`LIMU METH`, `REPS`, `CPRI`) does not carry the texts of the object.

Most entries carry their texts themselves, in all languages: a whole object (`R3TR`), a text pool (`LIMU REPT`), a message (`LIMU MESS`), a screen (`LIMU DYNP`), a GUI status (`LIMU CUAD`). The gap is a task that holds a program or class **only as code** (`LIMU REPS`, `METH`, `CPRI`, `CPUB`, `CPRO`, `CINC`, `CLSD`, `CDEF`, `FUNC`, `INTD`): it does not carry the text elements of that program or class.

With `ZTR_TRANSL_RECORD = X` the release check closes exactly that gap, at the release of a **task** (not of a request, whose tasks did it): for every program, class or function group that the task holds only as code, the translations of its **text pool** (SE63 types `RPT1` to `RPT8`) in the required languages are recorded in the task, as the `LANG` entries SE63 makes (`LXE_OBJ_CREATE_TRANSPORT_SE63`), only where at least one text is translated. Nothing else is recorded: messages, screens, statuses, data elements travel with their own entries. An object whose text pool or whole object is in **another open request** is skipped with a message, so that no text of a change still in work is shipped early. Never into a `#DELIVERY` request. The Git push is unchanged: a `LANG` entry stands for its object. A failure or a skip is a message only; the release is never refused for it.

The switch is off by default. Test it on your system first (entries added during the release, locks with other open requests, size of large tasks). Report `ZTR_SETUP`, block "Translation check at release", "At release: record the existing translations in the task".

Translations saved with `ZTR_TRANSL_REPORT` are always recorded: with neither "Record in" nor a task or request, Save asks for a request, and Cancel writes nothing.

## Correctness: Copilot

The SAP check knows whether a translation exists, not whether it is right. That is the job of the review of the pull request, where GitHub Copilot can review with repository instructions:

| File in the product repository | From | Content |
|---|---|---|
| `.github/copilot-instructions.md` | `github-templates/copilot-instructions.md` | how translations look in abapGit files and what to check: the language of every text matches its language key, both languages present, placeholders kept, glossary terms used |
| `.github/translation-glossary.md` | `github-templates/translation-glossary.md` | the agreed terms per language, including the terms that stay untranslated. The team extends it in pull requests |

Copilot only sees the files of the pull request, so it reviews new and changed texts. That a text exists in every language at all is made sure in SAP, before the push.

## Limits

- Writing goes through the same functions SE63 uses, with the authorizations of the developer's session; it is a tool of the development system.
- The check reads what is on the system now, not what is in the request: see "Translations must also be transported".
- Long texts (documentation) are read by SE63 like short texts where its API allows; the report lists an object it could not read as "not readable" on demand.
- A "run all" over a whole namespace reads every object through SE63 and takes minutes; run it in the background for large namespaces.
- Download, upload and the length columns need SAP GUI; in the background only the list is produced.
- Table entries: at most 50,000 rows per table are read.
- `LXE_OBJ_EXPAND_TRANSPORT_OBJ` and `LXE_OBJ_TEXT_PAIR_READ` are not released APIs of SAP. They are the functions SE63 itself uses and are stable since many releases; a change after an upgrade would show at the first run of the report.
