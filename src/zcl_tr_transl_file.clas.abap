"! The missing translations as an Excel file (.xlsx) or as CSV files, and
"! back.
"!
"! The file is built as Office Open XML with CL_ABAP_ZIP, and read with
"! iXML: no other library is needed on the system.
"!
"! One line per text. Visible: type, object, kind of text, source
"! language, source text, target language, Translation, Max. length,
"! Length, Length check. Length and Length
"! check are formulas, and a translation that is too long is red, so the
"! translator sees it while typing. The columns that find the text again
"! (SE63 type and name, text key, customer number, language key) are
"! hidden, and the sheet is protected: only Translation and Proposed
"! source text can be changed.
"!
"! Proposed source text, next to the source text, is where a translator
"! proposes a better wording of the source text itself. A proposal that
"! differs from the source text marks both cells orange. Reading returns
"! the proposals as SOURCE_CHANGES, once per text; they are never
"! written: changing a source text is a change of the object, made by a
"! developer.
"!
"! With hardcoded texts a second sheet "Hardcoded texts" follows: one
"! line per literal in the source code that the user sees, with where it
"! is, and two columns to type in, Proposed English and Proposed German.
"! A developer moves such a text into a message or a text symbol and uses
"! the proposals there; the sheet is never read back.
"!
"! Reading takes the columns by their heading, so the order does not
"! matter. Both the strings Excel keeps in a table of their own and the
"! strings written in the cell are read.
"!
"! The same lines can be written as CSV files instead (for a translation
"! tool or a text editor, where nothing reformats a value): UTF-8 with
"! byte order mark, every value in quotes, separated by semicolons; the
"! hardcoded texts go into a CSV file of their own. A CSV file has no
"! formulas, colours or protection. Reading accepts semicolons, commas or
"! tabs as separator, so a file saved again by another program is read
"! too, but it must stay UTF-8.
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_source_change,
        object      TYPE trobjtype,
        obj_name    TYPE trobj_name,
        text_kind   TYPE zcl_tr_transl_check=>ty_finding-text_kind,
        lxe_type    TYPE lxeobjtype,
        lxe_name    TYPE lxeobjname,
        text_key    TYPE lxetextkey,
        source_text TYPE string,
        proposed    TYPE string,
      END OF ty_source_change.
    TYPES ty_source_changes TYPE STANDARD TABLE OF ty_source_change WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_read_result,
        lines          TYPE zcl_tr_transl_check=>ty_findings,
        source_changes TYPE ty_source_changes,
        error          TYPE string,
      END OF ty_read_result.

    CONSTANTS:
      BEGIN OF heading,
        object          TYPE string VALUE `Type`,
        obj_name        TYPE string VALUE `Object`,
        text_kind       TYPE string VALUE `Kind of text`,
        source_language TYPE string VALUE `Source language`,
        source_text     TYPE string VALUE `Source text`,
        proposed_source TYPE string VALUE `Proposed source text`,
        language        TYPE string VALUE `Target language`,
        target_text     TYPE string VALUE `Translation`,
        max_length      TYPE string VALUE `Max. length`,
        length          TYPE string VALUE `Length`,
        length_check    TYPE string VALUE `Length check`,
        lxe_type        TYPE string VALUE `SE63 type`,
        lxe_name        TYPE string VALUE `SE63 name`,
        text_key        TYPE string VALUE `Text key`,
        custmnr         TYPE string VALUE `Customer number`,
        language_key    TYPE string VALUE `Language key`,
      END OF heading.
    CONSTANTS:
      BEGIN OF hardcoded_heading,
        object           TYPE string VALUE `Type`,
        obj_name         TYPE string VALUE `Object`,
        include          TYPE string VALUE `Include`,
        line             TYPE string VALUE `Line`,
        kind             TYPE string VALUE `Kind`,
        text             TYPE string VALUE `Text in the code`,
        proposed_english TYPE string VALUE `Proposed English`,
        proposed_german  TYPE string VALUE `Proposed German`,
      END OF hardcoded_heading.

    "! The lines as an .xlsx file; the Translation column holds the
    "! translation of each line, if it has one. Hardcoded texts, if any, go
    "! into a second sheet.
    METHODS to_xlsx
      IMPORTING
        lines         TYPE zcl_tr_transl_check=>ty_findings
        hardcoded     TYPE zcl_tr_transl_hardcoded=>ty_findings OPTIONAL
      RETURNING
        VALUE(result) TYPE xstring.
    "! The lines of a file made by TO_XLSX, with the translations typed in
    "! it. Lines without SE63 name are left out. ERROR is set when the file
    "! is not such a file; then LINES is empty.
    METHODS from_xlsx
      IMPORTING
        file          TYPE xstring
      RETURNING
        VALUE(result) TYPE ty_read_result.
    "! The lines as a CSV file: UTF-8 with byte order mark, values in
    "! quotes, separated by semicolons. The same columns as the Excel file,
    "! without the formulas Length and Length check.
    METHODS to_csv
      IMPORTING
        lines         TYPE zcl_tr_transl_check=>ty_findings
      RETURNING
        VALUE(result) TYPE xstring.
    "! The hardcoded texts as a CSV file of their own, with the two columns
    "! for proposals; it is never read back.
    METHODS hardcoded_to_csv
      IMPORTING
        hardcoded     TYPE zcl_tr_transl_hardcoded=>ty_findings
      RETURNING
        VALUE(result) TYPE xstring.
    "! The lines of a CSV file made by TO_CSV. Semicolons, commas or tabs
    "! as separator, with or without quotes and byte order mark; the text
    "! must be UTF-8. ERROR as in FROM_XLSX.
    METHODS from_csv
      IMPORTING
        file          TYPE xstring
      RETURNING
        VALUE(result) TYPE ty_read_result.
    "! FROM_XLSX for an Excel file, FROM_CSV for any other file.
    METHODS from_file
      IMPORTING
        file          TYPE xstring
      RETURNING
        VALUE(result) TYPE ty_read_result.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cell,
        row    TYPE i,
        column TYPE string,
        value  TYPE string,
      END OF ty_cell.
    TYPES ty_cells TYPE SORTED TABLE OF ty_cell WITH UNIQUE KEY row column.
    TYPES:
      BEGIN OF ty_column,
        heading TYPE string,
        column  TYPE string,
      END OF ty_column.
    TYPES ty_columns TYPE SORTED TABLE OF ty_column WITH UNIQUE KEY heading.

    CONSTANTS spreadsheet_namespace TYPE string VALUE `http://schemas.openxmlformats.org/spreadsheetml/2006/main`.
    CONSTANTS sheet_part TYPE string VALUE `xl/worksheets/sheet1.xml`.
    CONSTANTS strings_part TYPE string VALUE `xl/sharedStrings.xml`.
    CONSTANTS sheet_name TYPE string VALUE `Translations`.
    CONSTANTS hardcoded_part TYPE string VALUE `xl/worksheets/sheet2.xml`.
    CONSTANTS hardcoded_sheet_name TYPE string VALUE `Hardcoded texts`.
    CONSTANTS csv_separator_written TYPE string VALUE `;`.
    " PK: the first two bytes of every ZIP file, so of every .xlsx file.
    CONSTANTS zip_signature TYPE x LENGTH 2 VALUE '504B'.
    " Cell styles of styles.xml: 0 text, 1 heading, 2 the editable Translation.
    CONSTANTS:
      BEGIN OF style,
        text        TYPE string VALUE `0`,
        heading     TYPE string VALUE `1`,
        translation TYPE string VALUE `2`,
      END OF style.

    METHODS content_types
      IMPORTING
        with_hardcoded TYPE abap_bool
      RETURNING
        VALUE(result)  TYPE string.
    METHODS package_relations
      RETURNING
        VALUE(result) TYPE string.
    METHODS workbook
      IMPORTING
        last_row           TYPE i
        last_hardcoded_row TYPE i
      RETURNING
        VALUE(result)      TYPE string.
    METHODS workbook_relations
      IMPORTING
        with_hardcoded TYPE abap_bool
      RETURNING
        VALUE(result)  TYPE string.
    METHODS styles
      RETURNING
        VALUE(result) TYPE string.
    METHODS sheet
      IMPORTING
        lines         TYPE zcl_tr_transl_check=>ty_findings
      RETURNING
        VALUE(result) TYPE string.
    METHODS heading_row
      RETURNING
        VALUE(result) TYPE string.
    METHODS hardcoded_sheet
      IMPORTING
        hardcoded     TYPE zcl_tr_transl_hardcoded=>ty_findings
      RETURNING
        VALUE(result) TYPE string.
    METHODS hardcoded_row
      IMPORTING
        finding       TYPE zcl_tr_transl_hardcoded=>ty_finding
        row           TYPE i
      RETURNING
        VALUE(result) TYPE string.
    METHODS data_row
      IMPORTING
        line          TYPE zcl_tr_transl_check=>ty_finding
        row           TYPE i
      RETURNING
        VALUE(result) TYPE string.
    METHODS text_cell
      IMPORTING
        reference     TYPE string
        value         TYPE csequence
        cell_style    TYPE string DEFAULT style-text
      RETURNING
        VALUE(result) TYPE string.
    METHODS utf8
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

    METHODS parse
      IMPORTING
        xml           TYPE xstring
      RETURNING
        VALUE(result) TYPE REF TO if_ixml_document.
    METHODS shared_strings
      IMPORTING
        zip           TYPE REF TO cl_abap_zip
      RETURNING
        VALUE(result) TYPE string_table.
    METHODS text_of
      IMPORTING
        element       TYPE REF TO if_ixml_element
      RETURNING
        VALUE(result) TYPE string.
    METHODS cells
      IMPORTING
        document      TYPE REF TO if_ixml_document
        strings       TYPE string_table
      RETURNING
        VALUE(result) TYPE ty_cells.
    METHODS cell_value
      IMPORTING
        cell          TYPE REF TO if_ixml_element
        strings       TYPE string_table
      RETURNING
        VALUE(result) TYPE string.
    METHODS child
      IMPORTING
        element       TYPE REF TO if_ixml_element
        name          TYPE string
      RETURNING
        VALUE(result) TYPE REF TO if_ixml_element.
    METHODS lines_of
      IMPORTING
        cells         TYPE ty_cells
      RETURNING
        VALUE(result) TYPE ty_read_result.
    METHODS value_at
      IMPORTING
        cells         TYPE ty_cells
        columns       TYPE ty_columns
        row           TYPE i
        heading       TYPE string
      RETURNING
        VALUE(result) TYPE string.

    METHODS csv_file
      IMPORTING
        rows          TYPE string_table
      RETURNING
        VALUE(result) TYPE xstring.
    METHODS csv_row
      IMPORTING
        values        TYPE string_table
      RETURNING
        VALUE(result) TYPE string.
    METHODS csv_separator
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    "! The values of a CSV text as cells: row 1 is the heading, the column
    "! is the number of the value in its row.
    METHODS csv_cells
      IMPORTING
        text          TYPE string
        separator     TYPE string
      RETURNING
        VALUE(result) TYPE ty_cells.
ENDCLASS.



CLASS zcl_tr_transl_file IMPLEMENTATION.


  METHOD to_xlsx.
    DATA(with_hardcoded) = xsdbool( hardcoded IS NOT INITIAL ).
    DATA(last_hardcoded_row) = COND i( WHEN with_hardcoded = abap_true THEN lines( hardcoded ) + 1 ).
    DATA(zip) = NEW cl_abap_zip( ).
    zip->add( name    = `[Content_Types].xml`
              content = utf8( content_types( with_hardcoded ) ) ).
    zip->add( name    = `_rels/.rels`
              content = utf8( package_relations( ) ) ).
    zip->add( name    = `xl/workbook.xml`
              content = utf8( workbook( last_row = lines( lines ) + 1 last_hardcoded_row = last_hardcoded_row ) ) ).
    zip->add( name    = `xl/_rels/workbook.xml.rels`
              content = utf8( workbook_relations( with_hardcoded ) ) ).
    zip->add( name    = `xl/styles.xml`
              content = utf8( styles( ) ) ).
    zip->add( name    = sheet_part
              content = utf8( sheet( lines ) ) ).
    IF with_hardcoded = abap_true.
      zip->add( name    = hardcoded_part
                content = utf8( hardcoded_sheet( hardcoded ) ) ).
    ENDIF.
    result = zip->save( ).
  ENDMETHOD.


  METHOD content_types.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">` &&
      `<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>` &&
      `<Default Extension="xml" ContentType="application/xml"/>` &&
      `<Override PartName="/xl/workbook.xml" ` &&
      `ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>` &&
      `<Override PartName="/xl/worksheets/sheet1.xml" ` &&
      `ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>` &&
      COND string( WHEN with_hardcoded = abap_true THEN
        |<Override PartName="/{ hardcoded_part }" | &&
        `ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>` ) &&
      `<Override PartName="/xl/styles.xml" ` &&
      `ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>` &&
      `</Types>`.
  ENDMETHOD.


  METHOD package_relations.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
      `<Relationship Id="rId1" ` &&
      `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" ` &&
      `Target="xl/workbook.xml"/>` &&
      `</Relationships>`.
  ENDMETHOD.


  METHOD workbook.
    " The filter of each heading row needs its range as a defined name.
    " Formulas are calculated when Excel opens the file. LAST_HARDCODED_ROW
    " is 0 when there is no sheet of hardcoded texts.
    DATA(sheets) = |<sheet name="{ sheet_name }" sheetId="1" r:id="rId1"/>|.
    DATA(names) = |<definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">| &&
                  |{ sheet_name }!$A$1:$K${ last_row }</definedName>|.
    IF last_hardcoded_row > 0.
      sheets = |{ sheets }<sheet name="{ hardcoded_sheet_name }" sheetId="2" r:id="rId3"/>|.
      names = |{ names }<definedName name="_xlnm._FilterDatabase" localSheetId="1" hidden="1">| &&
              |'{ hardcoded_sheet_name }'!$A$1:$H${ last_hardcoded_row }</definedName>|.
    ENDIF.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<workbook xmlns="{ spreadsheet_namespace }" | &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      |<sheets>{ sheets }</sheets>| &&
      |<definedNames>{ names }</definedNames>| &&
      `<calcPr calcId="0" fullCalcOnLoad="1"/>` &&
      `</workbook>`.
  ENDMETHOD.


  METHOD workbook_relations.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">` &&
      `<Relationship Id="rId1" ` &&
      `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ` &&
      `Target="worksheets/sheet1.xml"/>` &&
      `<Relationship Id="rId2" ` &&
      `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" ` &&
      `Target="styles.xml"/>` &&
      COND string( WHEN with_hardcoded = abap_true THEN
        `<Relationship Id="rId3" ` &&
        `Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" ` &&
        `Target="worksheets/sheet2.xml"/>` ) &&
      `</Relationships>`.
  ENDMETHOD.


  METHOD styles.
    " Style 2, the Translation column: text format (a translation such as
    " "1.10" stays text), light yellow, not locked by the sheet protection.
    " Differential formats: 0 the red of a text that is too long, 1 the
    " orange of a proposed change of the source text.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<styleSheet xmlns="{ spreadsheet_namespace }">| &&
      `<fonts count="2">` &&
      `<font><sz val="11"/><name val="Calibri"/></font>` &&
      `<font><b/><sz val="11"/><name val="Calibri"/></font>` &&
      `</fonts>` &&
      `<fills count="3">` &&
      `<fill><patternFill patternType="none"/></fill>` &&
      `<fill><patternFill patternType="gray125"/></fill>` &&
      `<fill><patternFill patternType="solid"><fgColor rgb="FFFFF2CC"/><bgColor indexed="64"/></patternFill></fill>` &&
      `</fills>` &&
      `<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>` &&
      `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` &&
      `<cellXfs count="3">` &&
      `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1">` &&
      `<alignment vertical="top" wrapText="1"/></xf>` &&
      `<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>` &&
      `<xf numFmtId="49" fontId="0" fillId="2" borderId="0" xfId="0" applyNumberFormat="1" applyFill="1" ` &&
      `applyAlignment="1" applyProtection="1"><alignment vertical="top" wrapText="1"/>` &&
      `<protection locked="0"/></xf>` &&
      `</cellXfs>` &&
      `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>` &&
      `<dxfs count="2">` &&
      `<dxf><font><b/><color rgb="FF9C0006"/></font>` &&
      `<fill><patternFill><bgColor rgb="FFFFC7CE"/></patternFill></fill></dxf>` &&
      `<dxf><font><color rgb="FF9C5700"/></font>` &&
      `<fill><patternFill><bgColor rgb="FFFFD8A8"/></patternFill></fill></dxf>` &&
      `</dxfs>` &&
      `</styleSheet>`.
  ENDMETHOD.


  METHOD sheet.
    " Columns: A type, B object, C kind of text, D source language, E source
    " text, F Proposed source text, G target language, H Translation, I Max.
    " length, J Length, K Length check; hidden: L SE63 type, M SE63 name,
    " N text key, O customer number, P language key. F and H can be typed
    " in; both are red when longer than Max. length.
    DATA(last_row) = lines( lines ) + 1.
    DATA(rows) = heading_row( ).
    LOOP AT lines INTO DATA(line).
      rows = rows && data_row( line = line row = sy-tabix + 1 ).
    ENDLOOP.

    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<worksheet xmlns="{ spreadsheet_namespace }" | &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      |<dimension ref="A1:P{ last_row }"/>| &&
      `<sheetViews><sheetView workbookViewId="0">` &&
      `<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>` &&
      `</sheetView></sheetViews>` &&
      `<sheetFormatPr defaultRowHeight="15"/>` &&
      `<cols>` &&
      `<col min="1" max="1" width="7" customWidth="1"/>` &&
      `<col min="2" max="2" width="32" customWidth="1"/>` &&
      `<col min="3" max="3" width="30" customWidth="1"/>` &&
      `<col min="4" max="4" width="10" customWidth="1"/>` &&
      `<col min="5" max="6" width="45" customWidth="1"/>` &&
      `<col min="7" max="7" width="10" customWidth="1"/>` &&
      `<col min="8" max="8" width="55" customWidth="1"/>` &&
      `<col min="9" max="10" width="11" customWidth="1"/>` &&
      `<col min="11" max="11" width="16" customWidth="1"/>` &&
      `<col min="12" max="16" width="14" hidden="1" customWidth="1"/>` &&
      `</cols>` &&
      |<sheetData>{ rows }</sheetData>| &&
      `<sheetProtection sheet="1" objects="1" scenarios="1" formatColumns="0" formatRows="0" ` &&
      `autoFilter="0" sort="0"/>` &&
      |<autoFilter ref="A1:K{ last_row }"/>| &&
      |<conditionalFormatting sqref="H2:H{ last_row } K2:K{ last_row }">| &&
      `<cfRule type="expression" dxfId="0" priority="1">` &&
      `<formula>AND($I2&gt;0,LEN($H2)&gt;$I2)</formula></cfRule></conditionalFormatting>` &&
      |<conditionalFormatting sqref="F2:F{ last_row }">| &&
      `<cfRule type="expression" dxfId="0" priority="2">` &&
      `<formula>AND($I2&gt;0,LEN($F2)&gt;$I2)</formula></cfRule></conditionalFormatting>` &&
      |<conditionalFormatting sqref="E2:F{ last_row }">| &&
      `<cfRule type="expression" dxfId="1" priority="3">` &&
      `<formula>AND($F2&lt;&gt;"",$F2&lt;&gt;$E2)</formula></cfRule></conditionalFormatting>` &&
      `<dataValidations count="2">` &&
      |<dataValidation type="custom" errorStyle="warning" allowBlank="1" showErrorMessage="1" | &&
      |errorTitle="Too long" error="The translation is longer than Max. length. SAP does not save it." | &&
      |sqref="H2:H{ last_row }"><formula1>OR($I2=0,LEN($H2)&lt;=$I2)</formula1></dataValidation>| &&
      |<dataValidation type="custom" errorStyle="warning" allowBlank="1" showErrorMessage="1" | &&
      |errorTitle="Too long" error="The proposed source text is longer than Max. length." | &&
      |sqref="F2:F{ last_row }"><formula1>OR($I2=0,LEN($F2)&lt;=$I2)</formula1></dataValidation>| &&
      `</dataValidations>` &&
      `<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>` &&
      `</worksheet>`.
  ENDMETHOD.


  METHOD heading_row.
    result =
      `<row r="1">` &&
      text_cell( reference = `A1` value = heading-object          cell_style = style-heading ) &&
      text_cell( reference = `B1` value = heading-obj_name        cell_style = style-heading ) &&
      text_cell( reference = `C1` value = heading-text_kind       cell_style = style-heading ) &&
      text_cell( reference = `D1` value = heading-source_language cell_style = style-heading ) &&
      text_cell( reference = `E1` value = heading-source_text     cell_style = style-heading ) &&
      text_cell( reference = `F1` value = heading-proposed_source cell_style = style-heading ) &&
      text_cell( reference = `G1` value = heading-language        cell_style = style-heading ) &&
      text_cell( reference = `H1` value = heading-target_text     cell_style = style-heading ) &&
      text_cell( reference = `I1` value = heading-max_length      cell_style = style-heading ) &&
      text_cell( reference = `J1` value = heading-length          cell_style = style-heading ) &&
      text_cell( reference = `K1` value = heading-length_check    cell_style = style-heading ) &&
      text_cell( reference = `L1` value = heading-lxe_type        cell_style = style-heading ) &&
      text_cell( reference = `M1` value = heading-lxe_name        cell_style = style-heading ) &&
      text_cell( reference = `N1` value = heading-text_key        cell_style = style-heading ) &&
      text_cell( reference = `O1` value = heading-custmnr         cell_style = style-heading ) &&
      text_cell( reference = `P1` value = heading-language_key    cell_style = style-heading ) &&
      `</row>`.
  ENDMETHOD.


  METHOD data_row.
    DATA(r) = |{ row }|.
    " The Translation and Proposed source text cells are written even when
    " empty: their style is what lets them be typed in.
    DATA(translation) = COND string(
      WHEN line-target_text IS INITIAL THEN |<c r="H{ r }" s="{ style-translation }"/>|
      ELSE text_cell( reference = |H{ r }| value = line-target_text cell_style = style-translation ) ).
    result =
      |<row r="{ r }">| &&
      text_cell( reference = |A{ r }| value = line-object ) &&
      text_cell( reference = |B{ r }| value = condense( line-obj_name ) ) &&
      text_cell( reference = |C{ r }| value = line-text_kind ) &&
      text_cell( reference = |D{ r }| value = zcl_tr_transl_check=>language_code( line-source_language ) ) &&
      text_cell( reference = |E{ r }| value = line-source_text ) &&
      |<c r="F{ r }" s="{ style-translation }"/>| &&
      text_cell( reference = |G{ r }| value = zcl_tr_transl_check=>language_code( line-language ) ) &&
      translation &&
      |<c r="I{ r }"><v>{ line-max_length }</v></c>| &&
      |<c r="J{ r }"><f>LEN(H{ r })</f></c>| &&
      |<c r="K{ r }" t="str"><f>IF(H{ r }="","",IF(AND(I{ r }&gt;0,LEN(H{ r })&gt;I{ r }),| &&
      |"Too long by "&amp;(LEN(H{ r })-I{ r }),"OK"))</f></c>| &&
      text_cell( reference = |L{ r }| value = line-lxe_type ) &&
      text_cell( reference = |M{ r }| value = line-lxe_name ) &&
      text_cell( reference = |N{ r }| value = line-text_key ) &&
      text_cell( reference = |O{ r }| value = line-custmnr ) &&
      text_cell( reference = |P{ r }| value = line-language ) &&
      `</row>`.
  ENDMETHOD.


  METHOD hardcoded_sheet.
    " Columns: A type, B object, C include, D line, E kind, F text in the
    " code, G Proposed English, H Proposed German. Only G and H can be
    " typed in.
    DATA(last_row) = lines( hardcoded ) + 1.
    DATA(rows) =
      `<row r="1">` &&
      text_cell( reference = `A1` value = hardcoded_heading-object           cell_style = style-heading ) &&
      text_cell( reference = `B1` value = hardcoded_heading-obj_name         cell_style = style-heading ) &&
      text_cell( reference = `C1` value = hardcoded_heading-include          cell_style = style-heading ) &&
      text_cell( reference = `D1` value = hardcoded_heading-line             cell_style = style-heading ) &&
      text_cell( reference = `E1` value = hardcoded_heading-kind             cell_style = style-heading ) &&
      text_cell( reference = `F1` value = hardcoded_heading-text             cell_style = style-heading ) &&
      text_cell( reference = `G1` value = hardcoded_heading-proposed_english cell_style = style-heading ) &&
      text_cell( reference = `H1` value = hardcoded_heading-proposed_german  cell_style = style-heading ) &&
      `</row>`.
    LOOP AT hardcoded INTO DATA(finding).
      rows = rows && hardcoded_row( finding = finding row = sy-tabix + 1 ).
    ENDLOOP.

    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<worksheet xmlns="{ spreadsheet_namespace }" | &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      |<dimension ref="A1:H{ last_row }"/>| &&
      `<sheetViews><sheetView workbookViewId="0">` &&
      `<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>` &&
      `</sheetView></sheetViews>` &&
      `<sheetFormatPr defaultRowHeight="15"/>` &&
      `<cols>` &&
      `<col min="1" max="1" width="7" customWidth="1"/>` &&
      `<col min="2" max="3" width="32" customWidth="1"/>` &&
      `<col min="4" max="4" width="7" customWidth="1"/>` &&
      `<col min="5" max="5" width="14" customWidth="1"/>` &&
      `<col min="6" max="8" width="50" customWidth="1"/>` &&
      `</cols>` &&
      |<sheetData>{ rows }</sheetData>| &&
      `<sheetProtection sheet="1" objects="1" scenarios="1" formatColumns="0" formatRows="0" ` &&
      `autoFilter="0" sort="0"/>` &&
      |<autoFilter ref="A1:H{ last_row }"/>| &&
      `<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>` &&
      `</worksheet>`.
  ENDMETHOD.


  METHOD hardcoded_row.
    DATA(r) = |{ row }|.
    " The two proposal cells are written empty: their style is what lets
    " them be typed in.
    result =
      |<row r="{ r }">| &&
      text_cell( reference = |A{ r }| value = finding-object ) &&
      text_cell( reference = |B{ r }| value = condense( finding-obj_name ) ) &&
      text_cell( reference = |C{ r }| value = condense( finding-include ) ) &&
      |<c r="D{ r }"><v>{ finding-line }</v></c>| &&
      text_cell( reference = |E{ r }| value = finding-kind ) &&
      text_cell( reference = |F{ r }| value = finding-text ) &&
      |<c r="G{ r }" s="{ style-translation }"/>| &&
      |<c r="H{ r }" s="{ style-translation }"/>| &&
      `</row>`.
  ENDMETHOD.


  METHOD text_cell.
    " A string written in the cell itself; leading and trailing blanks are kept.
    DATA(text) = escape( val = CONV string( value ) format = cl_abap_format=>e_xml_text ).
    result = |<c r="{ reference }" s="{ cell_style }" t="inlineStr"><is><t xml:space="preserve">{ text }</t></is></c>|.
  ENDMETHOD.


  METHOD utf8.
    result = cl_abap_codepage=>convert_to( source = text codepage = `UTF-8` ).
  ENDMETHOD.


  METHOD from_xlsx.
    DATA sheet_xml TYPE xstring.

    DATA(zip) = NEW cl_abap_zip( ).
    zip->load(
      EXPORTING
        zip             = file
      EXCEPTIONS
        zip_parse_error = 1
        OTHERS          = 2 ).
    IF sy-subrc <> 0.
      result-error = `The file is not an Excel file (.xlsx)`.
      RETURN.
    ENDIF.
    zip->get(
      EXPORTING
        name                    = sheet_part
      IMPORTING
        content                 = sheet_xml
      EXCEPTIONS
        zip_index_error         = 1
        zip_decompression_error = 2
        OTHERS                  = 3 ).
    IF sy-subrc <> 0.
      result-error = `The file has no first sheet`.
      RETURN.
    ENDIF.
    DATA(document) = parse( sheet_xml ).
    IF document IS NOT BOUND.
      result-error = `The first sheet of the file cannot be read`.
      RETURN.
    ENDIF.
    result = lines_of( cells( document = document strings = shared_strings( zip ) ) ).
  ENDMETHOD.


  METHOD parse.
    DATA(ixml) = cl_ixml=>create( ).
    DATA(factory) = ixml->create_stream_factory( ).
    DATA(document) = ixml->create_document( ).
    DATA(parser) = ixml->create_parser(
      stream_factory = factory
      istream        = factory->create_istream_xstring( xml )
      document       = document ).
    " Blanks at the start or end of a text are part of it.
    parser->set_normalizing( abap_false ).
    IF parser->parse( ) = 0.
      result = document.
    ENDIF.
  ENDMETHOD.


  METHOD shared_strings.
    " Excel keeps the strings of a saved file in a table of their own; a
    " cell of type s holds the index into it. A file that was never saved
    " by Excel has none.
    DATA strings_xml TYPE xstring.

    zip->get(
      EXPORTING
        name                    = strings_part
      IMPORTING
        content                 = strings_xml
      EXCEPTIONS
        zip_index_error         = 1
        zip_decompression_error = 2
        OTHERS                  = 3 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(document) = parse( strings_xml ).
    IF document IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(items) = document->get_elements_by_tag_name_ns( name = `si` uri = spreadsheet_namespace ).
    DO items->get_length( ) TIMES.
      DATA(item) = CAST if_ixml_element( items->get_item( sy-index - 1 ) ).
      APPEND text_of( item ) TO result.
    ENDDO.
  ENDMETHOD.


  METHOD text_of.
    " The text of a string item: all its t elements, the runs of a
    " formatted text one after the other; not the phonetic guide (rPh).
    DATA(texts) = element->get_elements_by_tag_name_ns( name = `t` uri = spreadsheet_namespace ).
    DO texts->get_length( ) TIMES.
      DATA(text) = texts->get_item( sy-index - 1 ).
      IF text->get_parent( )->get_name( ) = `rPh`.
        CONTINUE.
      ENDIF.
      result = result && text->get_value( ).
    ENDDO.
  ENDMETHOD.


  METHOD cells.
    DATA(cell_nodes) = document->get_elements_by_tag_name_ns( name = `c` uri = spreadsheet_namespace ).
    DO cell_nodes->get_length( ) TIMES.
      DATA(cell) = CAST if_ixml_element( cell_nodes->get_item( sy-index - 1 ) ).
      " A reference such as E12: column E, row 12.
      DATA(reference) = to_upper( cell->get_attribute( `r` ) ).
      DATA(digits_at) = find_any_of( val = reference sub = `0123456789` ).
      IF digits_at < 1.
        CONTINUE.
      ENDIF.
      DATA(column) = substring( val = reference len = digits_at ).
      DATA(row_text) = substring( val = reference off = digits_at ).
      IF row_text CN `0123456789`.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( row = CONV i( row_text ) column = column
                      value = cell_value( cell = cell strings = strings ) ) INTO TABLE result.
    ENDDO.
  ENDMETHOD.


  METHOD cell_value.
    CASE cell->get_attribute( `t` ).
      WHEN `s`.
        DATA(value_element) = child( element = cell name = `v` ).
        IF value_element IS BOUND.
          DATA(index_text) = value_element->get_value( ).
          IF index_text CO `0123456789` AND index_text IS NOT INITIAL.
            DATA(index) = CONV i( index_text ) + 1.
            READ TABLE strings INTO result INDEX index.
          ENDIF.
        ENDIF.
      WHEN `inlineStr`.
        DATA(inline) = child( element = cell name = `is` ).
        IF inline IS BOUND.
          result = text_of( inline ).
        ENDIF.
      WHEN OTHERS.
        " Numbers, booleans and the cached result of a formula.
        value_element = child( element = cell name = `v` ).
        IF value_element IS BOUND.
          result = value_element->get_value( ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD child.
    DATA(children) = element->get_elements_by_tag_name_ns( name = name uri = spreadsheet_namespace ).
    IF children->get_length( ) > 0.
      result = CAST if_ixml_element( children->get_item( 0 ) ).
    ENDIF.
  ENDMETHOD.


  METHOD lines_of.
    DATA columns TYPE ty_columns.
    DATA last_row TYPE i.

    LOOP AT cells INTO DATA(cell) WHERE row = 1.
      INSERT VALUE #( heading = condense( cell-value ) column = cell-column ) INTO TABLE columns.
    ENDLOOP.
    DATA(required_headings) = VALUE string_table( ( heading-target_text ) ( heading-lxe_type ) ( heading-lxe_name )
                                                  ( heading-text_key ) ( heading-language_key ) ).
    LOOP AT required_headings INTO DATA(required).
      IF NOT line_exists( columns[ heading = required ] ).
        result-error = |The file has no column "{ required }": download the file with report ZTR_TRANSL_REPORT|.
        RETURN.
      ENDIF.
    ENDLOOP.

    LOOP AT cells INTO cell.
      last_row = nmax( val1 = last_row val2 = cell-row ).
    ENDLOOP.
    DO last_row - 1 TIMES.
      DATA(row) = sy-index + 1.
      DATA(line) = VALUE zcl_tr_transl_check=>ty_finding(
        object      = value_at( cells = cells columns = columns row = row heading = heading-object )
        obj_name    = value_at( cells = cells columns = columns row = row heading = heading-obj_name )
        language    = value_at( cells = cells columns = columns row = row heading = heading-language_key )
        source_text = value_at( cells = cells columns = columns row = row heading = heading-source_text )
        target_text = value_at( cells = cells columns = columns row = row heading = heading-target_text )
        lxe_type    = value_at( cells = cells columns = columns row = row heading = heading-lxe_type )
        lxe_name    = value_at( cells = cells columns = columns row = row heading = heading-lxe_name )
        text_key    = value_at( cells = cells columns = columns row = row heading = heading-text_key )
        custmnr     = value_at( cells = cells columns = columns row = row heading = heading-custmnr ) ).
      DATA(max_length) = value_at( cells = cells columns = columns row = row heading = heading-max_length ).
      IF max_length CO `0123456789` AND max_length IS NOT INITIAL.
        line-max_length = max_length.
      ENDIF.
      IF line-lxe_name IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND line TO result-lines.

      " A proposed source text: once per text, whatever target language
      " line it was typed on. Files without the column have none.
      DATA(proposed) = value_at( cells = cells columns = columns row = row heading = heading-proposed_source ).
      IF proposed IS NOT INITIAL AND proposed <> line-source_text AND
         NOT line_exists( result-source_changes[ lxe_type = line-lxe_type
                                                 lxe_name = line-lxe_name
                                                 text_key = line-text_key ] ).
        APPEND VALUE #( object      = line-object
                        obj_name    = line-obj_name
                        text_kind   = value_at( cells = cells columns = columns row = row heading = heading-text_kind )
                        lxe_type    = line-lxe_type
                        lxe_name    = line-lxe_name
                        text_key    = line-text_key
                        source_text = line-source_text
                        proposed    = proposed ) TO result-source_changes.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD value_at.
    READ TABLE columns INTO DATA(column) WITH TABLE KEY heading = heading.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE cells INTO DATA(cell) WITH TABLE KEY row = row column = column-column.
    IF sy-subrc = 0.
      result = cell-value.
    ENDIF.
  ENDMETHOD.


  METHOD to_csv.
    DATA(rows) = VALUE string_table(
      ( csv_row( VALUE #( ( heading-object ) ( heading-obj_name ) ( heading-text_kind ) ( heading-source_language )
                          ( heading-source_text ) ( heading-proposed_source ) ( heading-language )
                          ( heading-target_text ) ( heading-max_length ) ( heading-lxe_type ) ( heading-lxe_name )
                          ( heading-text_key ) ( heading-custmnr ) ( heading-language_key ) ) ) ) ).
    " Proposed source text is empty: it is for the translator.
    LOOP AT lines INTO DATA(line).
      APPEND csv_row( VALUE #( ( CONV #( line-object ) )
                               ( condense( line-obj_name ) )
                               ( CONV #( line-text_kind ) )
                               ( zcl_tr_transl_check=>language_code( line-source_language ) )
                               ( CONV #( line-source_text ) )
                               ( `` )
                               ( zcl_tr_transl_check=>language_code( line-language ) )
                               ( CONV #( line-target_text ) )
                               ( |{ line-max_length }| )
                               ( CONV #( line-lxe_type ) )
                               ( CONV #( line-lxe_name ) )
                               ( CONV #( line-text_key ) )
                               ( CONV #( line-custmnr ) )
                               ( CONV #( line-language ) ) ) ) TO rows.
    ENDLOOP.
    result = csv_file( rows ).
  ENDMETHOD.


  METHOD hardcoded_to_csv.
    DATA(rows) = VALUE string_table(
      ( csv_row( VALUE #( ( hardcoded_heading-object ) ( hardcoded_heading-obj_name ) ( hardcoded_heading-include )
                          ( hardcoded_heading-line ) ( hardcoded_heading-kind ) ( hardcoded_heading-text )
                          ( hardcoded_heading-proposed_english ) ( hardcoded_heading-proposed_german ) ) ) ) ).
    LOOP AT hardcoded INTO DATA(finding).
      APPEND csv_row( VALUE #( ( CONV #( finding-object ) )
                               ( condense( finding-obj_name ) )
                               ( condense( finding-include ) )
                               ( |{ finding-line }| )
                               ( CONV #( finding-kind ) )
                               ( finding-text )
                               ( `` )
                               ( `` ) ) ) TO rows.
    ENDLOOP.
    result = csv_file( rows ).
  ENDMETHOD.


  METHOD csv_file.
    " The byte order mark tells every program that the text is UTF-8.
    DATA(text) = concat_lines_of( table = rows sep = cl_abap_char_utilities=>cr_lf ) && cl_abap_char_utilities=>cr_lf.
    DATA(content) = utf8( text ).
    CONCATENATE cl_abap_char_utilities=>byte_order_mark_utf8 content INTO result IN BYTE MODE.
  ENDMETHOD.


  METHOD csv_row.
    " Every value in quotes, a quote in it doubled: separators, line
    " breaks and blanks at the ends are then part of the value.
    DATA(quoted) = VALUE string_table( FOR value IN values
                                       ( |"{ replace( val = value sub = `"` with = `""` occ = 0 ) }"| ) ).
    result = concat_lines_of( table = quoted sep = csv_separator_written ).
  ENDMETHOD.


  METHOD from_csv.
    DATA start TYPE x LENGTH 3.

    DATA(content) = file.
    start = content.
    IF xstrlen( content ) >= 3 AND start = cl_abap_char_utilities=>byte_order_mark_utf8.
      SHIFT content LEFT BY 3 PLACES IN BYTE MODE.
    ENDIF.
    TRY.
        DATA(text) = cl_abap_codepage=>convert_from( source = content codepage = `UTF-8` ).
      CATCH cx_sy_conversion_codepage cx_parameter_invalid.
        result-error = `The file is not in UTF-8: save it as "CSV UTF-8" and upload it again`.
        RETURN.
    ENDTRY.
    result = lines_of( csv_cells( text = text separator = csv_separator( text ) ) ).
  ENDMETHOD.


  METHOD csv_separator.
    " The one that occurs most often in the heading row; a semicolon when
    " none does.
    DATA(first_row) = text.
    DATA(row_end) = find_any_of( val = text sub = cl_abap_char_utilities=>cr_lf ).
    IF row_end >= 0.
      first_row = substring( val = text len = row_end ).
    ENDIF.
    result = csv_separator_written.
    DATA(most) = count( val = first_row sub = result ).
    DATA(candidates) = VALUE string_table( ( `,` ) ( |\t| ) ).
    LOOP AT candidates INTO DATA(candidate).
      IF count( val = first_row sub = candidate ) > most.
        result = candidate.
        most = count( val = first_row sub = candidate ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD csv_cells.
    DATA value TYPE string.

    DATA(carriage_return) = substring( val = cl_abap_char_utilities=>cr_lf len = 1 ).
    DATA(stops) = separator && cl_abap_char_utilities=>cr_lf.
    DATA(length) = strlen( text ).
    DATA(position) = 0.
    DATA(row) = 1.
    DATA(column) = 1.
    WHILE position < length.
      CLEAR value.
      IF substring( val = text off = position len = 1 ) = `"`.
        " A value in quotes: two quotes in it stand for one.
        position = position + 1.
        DO.
          DATA(closing) = find( val = text sub = `"` off = position ).
          IF closing < 0.
            value = value && substring( val = text off = position ).
            position = length.
            EXIT.
          ENDIF.
          value = value && substring( val = text off = position len = closing - position ).
          position = closing + 1.
          IF position < length AND substring( val = text off = position len = 1 ) = `"`.
            value = value && `"`.
            position = position + 1.
          ELSE.
            EXIT.
          ENDIF.
        ENDDO.
      ENDIF.
      " The rest up to the separator or the end of the row: all of a value
      " without quotes.
      DATA(stop) = find_any_of( val = text sub = stops off = position ).
      IF stop < 0.
        stop = length.
      ENDIF.
      value = value && substring( val = text off = position len = stop - position ).
      IF value IS NOT INITIAL.
        INSERT VALUE #( row = row column = |{ column }| value = value ) INTO TABLE result.
      ENDIF.
      position = stop.
      IF position >= length.
        EXIT.
      ENDIF.

      DATA(stop_character) = substring( val = text off = position len = 1 ).
      position = position + 1.
      IF stop_character = separator.
        column = column + 1.
        CONTINUE.
      ENDIF.
      " CR LF, CR or LF ends the row.
      IF stop_character = carriage_return AND position < length AND
         substring( val = text off = position len = 1 ) = cl_abap_char_utilities=>newline.
        position = position + 1.
      ENDIF.
      row = row + 1.
      column = 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD from_file.
    DATA start TYPE x LENGTH 2.

    start = file.
    IF xstrlen( file ) >= 2 AND start = zip_signature.
      result = from_xlsx( file ).
    ELSE.
      result = from_csv( file ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
