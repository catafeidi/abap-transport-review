"! The missing translations as an Excel file (.xlsx), and back.
"!
"! The file is built as Office Open XML with CL_ABAP_ZIP, and read with
"! iXML: no other library is needed on the system.
"!
"! One line per text. Visible: type, object, kind of text, target
"! language, source
"! text, Translation, Max. length, Length, Length check. Length and Length
"! check are formulas, and a translation that is too long is red, so the
"! translator sees it while typing. The columns that find the text again
"! (SE63 type and name, text key, customer number, language key) are
"! hidden, and the sheet is protected: only Translation can be changed.
"!
"! Reading takes the columns by their heading, so the order does not
"! matter. Both the strings Excel keeps in a table of their own and the
"! strings written in the cell are read.
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_read_result,
        lines TYPE zcl_tr_transl_check=>ty_findings,
        error TYPE string,
      END OF ty_read_result.

    CONSTANTS:
      BEGIN OF heading,
        object       TYPE string VALUE `Type`,
        obj_name     TYPE string VALUE `Object`,
        text_kind    TYPE string VALUE `Kind of text`,
        language     TYPE string VALUE `Language`,
        source_text  TYPE string VALUE `Source text`,
        target_text  TYPE string VALUE `Translation`,
        max_length   TYPE string VALUE `Max. length`,
        length       TYPE string VALUE `Length`,
        length_check TYPE string VALUE `Length check`,
        lxe_type     TYPE string VALUE `SE63 type`,
        lxe_name     TYPE string VALUE `SE63 name`,
        text_key     TYPE string VALUE `Text key`,
        custmnr      TYPE string VALUE `Customer number`,
        language_key TYPE string VALUE `Language key`,
      END OF heading.

    "! The lines as an .xlsx file; the Translation column holds the
    "! translation of each line, if it has one.
    METHODS to_xlsx
      IMPORTING
        lines         TYPE zcl_tr_transl_check=>ty_findings
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
    " Cell styles of styles.xml: 0 text, 1 heading, 2 the editable Translation.
    CONSTANTS:
      BEGIN OF style,
        text        TYPE string VALUE `0`,
        heading     TYPE string VALUE `1`,
        translation TYPE string VALUE `2`,
      END OF style.

    METHODS content_types
      RETURNING
        VALUE(result) TYPE string.
    METHODS package_relations
      RETURNING
        VALUE(result) TYPE string.
    METHODS workbook
      IMPORTING
        last_row      TYPE i
      RETURNING
        VALUE(result) TYPE string.
    METHODS workbook_relations
      RETURNING
        VALUE(result) TYPE string.
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
ENDCLASS.



CLASS zcl_tr_transl_file IMPLEMENTATION.


  METHOD to_xlsx.
    DATA(zip) = NEW cl_abap_zip( ).
    zip->add( name = `[Content_Types].xml`        content = utf8( content_types( ) ) ).
    zip->add( name = `_rels/.rels`                content = utf8( package_relations( ) ) ).
    zip->add( name = `xl/workbook.xml`            content = utf8( workbook( lines( lines ) + 1 ) ) ).
    zip->add( name = `xl/_rels/workbook.xml.rels` content = utf8( workbook_relations( ) ) ).
    zip->add( name = `xl/styles.xml`              content = utf8( styles( ) ) ).
    zip->add( name = sheet_part                   content = utf8( sheet( lines ) ) ).
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
    " The filter of the heading row needs its range as a defined name.
    " Formulas are calculated when Excel opens the file.
    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<workbook xmlns="{ spreadsheet_namespace }" | &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      |<sheets><sheet name="{ sheet_name }" sheetId="1" r:id="rId1"/></sheets>| &&
      |<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">| &&
      |{ sheet_name }!$A$1:$I${ last_row }</definedName></definedNames>| &&
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
      `</Relationships>`.
  ENDMETHOD.


  METHOD styles.
    " Style 2, the Translation column: text format (a translation such as
    " "1.10" stays text), light yellow, not locked by the sheet protection.
    " The one differential format is the red of a text that is too long.
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
      `<dxfs count="1"><dxf><font><b/><color rgb="FF9C0006"/></font>` &&
      `<fill><patternFill><bgColor rgb="FFFFC7CE"/></patternFill></fill></dxf></dxfs>` &&
      `</styleSheet>`.
  ENDMETHOD.


  METHOD sheet.
    " Columns: A type, B object, C kind of text, D language, E source text,
    " F Translation, G Max. length, H Length, I Length check; hidden: J SE63
    " type, K SE63 name, L text key, M customer number, N language key.
    DATA(last_row) = lines( lines ) + 1.
    DATA(rows) = heading_row( ).
    LOOP AT lines INTO DATA(line).
      rows = rows && data_row( line = line row = sy-tabix + 1 ).
    ENDLOOP.

    result =
      `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` &&
      |<worksheet xmlns="{ spreadsheet_namespace }" | &&
      `xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">` &&
      |<dimension ref="A1:N{ last_row }"/>| &&
      `<sheetViews><sheetView workbookViewId="0">` &&
      `<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>` &&
      `</sheetView></sheetViews>` &&
      `<sheetFormatPr defaultRowHeight="15"/>` &&
      `<cols>` &&
      `<col min="1" max="1" width="7" customWidth="1"/>` &&
      `<col min="2" max="2" width="32" customWidth="1"/>` &&
      `<col min="3" max="3" width="30" customWidth="1"/>` &&
      `<col min="4" max="4" width="10" customWidth="1"/>` &&
      `<col min="5" max="6" width="55" customWidth="1"/>` &&
      `<col min="7" max="8" width="11" customWidth="1"/>` &&
      `<col min="9" max="9" width="16" customWidth="1"/>` &&
      `<col min="10" max="14" width="14" hidden="1" customWidth="1"/>` &&
      `</cols>` &&
      |<sheetData>{ rows }</sheetData>| &&
      `<sheetProtection sheet="1" objects="1" scenarios="1" formatColumns="0" formatRows="0" ` &&
      `autoFilter="0" sort="0"/>` &&
      |<autoFilter ref="A1:I{ last_row }"/>| &&
      |<conditionalFormatting sqref="F2:F{ last_row } I2:I{ last_row }">| &&
      `<cfRule type="expression" dxfId="0" priority="1">` &&
      `<formula>AND($G2&gt;0,LEN($F2)&gt;$G2)</formula></cfRule></conditionalFormatting>` &&
      `<dataValidations count="1">` &&
      |<dataValidation type="custom" errorStyle="warning" allowBlank="1" showErrorMessage="1" | &&
      |errorTitle="Too long" error="The translation is longer than Max. length. SAP does not save it." | &&
      |sqref="F2:F{ last_row }"><formula1>OR($G2=0,LEN($F2)&lt;=$G2)</formula1></dataValidation>| &&
      `</dataValidations>` &&
      `<pageMargins left="0.7" right="0.7" top="0.75" bottom="0.75" header="0.3" footer="0.3"/>` &&
      `</worksheet>`.
  ENDMETHOD.


  METHOD heading_row.
    result =
      `<row r="1">` &&
      text_cell( reference = `A1` value = heading-object       cell_style = style-heading ) &&
      text_cell( reference = `B1` value = heading-obj_name     cell_style = style-heading ) &&
      text_cell( reference = `C1` value = heading-text_kind    cell_style = style-heading ) &&
      text_cell( reference = `D1` value = heading-language     cell_style = style-heading ) &&
      text_cell( reference = `E1` value = heading-source_text  cell_style = style-heading ) &&
      text_cell( reference = `F1` value = heading-target_text  cell_style = style-heading ) &&
      text_cell( reference = `G1` value = heading-max_length   cell_style = style-heading ) &&
      text_cell( reference = `H1` value = heading-length       cell_style = style-heading ) &&
      text_cell( reference = `I1` value = heading-length_check cell_style = style-heading ) &&
      text_cell( reference = `J1` value = heading-lxe_type     cell_style = style-heading ) &&
      text_cell( reference = `K1` value = heading-lxe_name     cell_style = style-heading ) &&
      text_cell( reference = `L1` value = heading-text_key     cell_style = style-heading ) &&
      text_cell( reference = `M1` value = heading-custmnr      cell_style = style-heading ) &&
      text_cell( reference = `N1` value = heading-language_key cell_style = style-heading ) &&
      `</row>`.
  ENDMETHOD.


  METHOD data_row.
    DATA(r) = |{ row }|.
    " The Translation cell is written even when empty: its style is what
    " lets it be typed in.
    DATA(translation) = COND string(
      WHEN line-target_text IS INITIAL THEN |<c r="F{ r }" s="{ style-translation }"/>|
      ELSE text_cell( reference = |F{ r }| value = line-target_text cell_style = style-translation ) ).
    result =
      |<row r="{ r }">| &&
      text_cell( reference = |A{ r }| value = line-object ) &&
      text_cell( reference = |B{ r }| value = condense( line-obj_name ) ) &&
      text_cell( reference = |C{ r }| value = line-text_kind ) &&
      text_cell( reference = |D{ r }| value = zcl_tr_transl_check=>language_code( line-language ) ) &&
      text_cell( reference = |E{ r }| value = line-source_text ) &&
      translation &&
      |<c r="G{ r }"><v>{ line-max_length }</v></c>| &&
      |<c r="H{ r }"><f>LEN(F{ r })</f></c>| &&
      |<c r="I{ r }" t="str"><f>IF(F{ r }="","",IF(AND(G{ r }&gt;0,LEN(F{ r })&gt;G{ r }),| &&
      |"Too long by "&amp;(LEN(F{ r })-G{ r }),"OK"))</f></c>| &&
      text_cell( reference = |J{ r }| value = line-lxe_type ) &&
      text_cell( reference = |K{ r }| value = line-lxe_name ) &&
      text_cell( reference = |L{ r }| value = line-text_key ) &&
      text_cell( reference = |M{ r }| value = line-custmnr ) &&
      text_cell( reference = |N{ r }| value = line-language ) &&
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

ENDCLASS.
