*"* use this source file for your ABAP unit test classes
" Tests of the Excel file of the translations: what TO_XLSX writes,
" FROM_XLSX reads back; a file as Excel saves it (strings in a table of
" their own) is read the same way. Nothing is read from the database.
CLASS ltc_file DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS spreadsheet_namespace TYPE string VALUE `http://schemas.openxmlformats.org/spreadsheetml/2006/main`.

    DATA cut TYPE REF TO zcl_tr_transl_file.

    METHODS setup.
    METHODS line
      IMPORTING
        target_text   TYPE csequence DEFAULT ``
      RETURNING
        VALUE(result) TYPE zcl_tr_transl_check=>ty_finding.
    METHODS utf8
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE xstring.

    METHODS written_lines_are_read_back FOR TESTING.
    METHODS special_characters_survive FOR TESTING.
    METHODS empty_translation_stays_empty FOR TESTING.
    METHODS excel_saved_strings_are_read FOR TESTING.
    METHODS line_without_se63_name_is_left FOR TESTING.
    METHODS file_that_is_no_zip_is_refused FOR TESTING.
    METHODS foreign_sheet_is_refused FOR TESTING.
ENDCLASS.


CLASS ltc_file IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( ).
  ENDMETHOD.


  METHOD line.
    result = VALUE #( object = 'PROG' obj_name = '/MYNS/DEMO' language = 'E' source_language = 'D'
                      lxe_type = 'RPT4' lxe_name = '/MYNS/DEMO' text_key = 'I001'
                      source_text = 'Speicherort' target_text = target_text
                      custmnr = '999999' max_length = 20 status = zcl_tr_transl_check=>status-missing ).
  ENDMETHOD.


  METHOD utf8.
    result = cl_abap_codepage=>convert_to( source = text codepage = `UTF-8` ).
  ENDMETHOD.


  METHOD written_lines_are_read_back.
    DATA(written) = VALUE zcl_tr_transl_check=>ty_findings( ( line( `Storage location` ) ) ).

    DATA(read) = cut->from_xlsx( cut->to_xlsx( written ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    DATA(back) = read-lines[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = back-target_text exp = `Storage location` ).
    cl_abap_unit_assert=>assert_equals( act = back-source_text exp = `Speicherort` ).
    cl_abap_unit_assert=>assert_equals( act = back-lxe_type exp = 'RPT4' ).
    cl_abap_unit_assert=>assert_equals( act = back-lxe_name exp = '/MYNS/DEMO' ).
    cl_abap_unit_assert=>assert_equals( act = back-text_key exp = 'I001' ).
    cl_abap_unit_assert=>assert_equals( act = back-custmnr exp = '999999' ).
    cl_abap_unit_assert=>assert_equals( act = back-language exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = back-max_length exp = 20 ).
    cl_abap_unit_assert=>assert_equals( act = back-object exp = 'PROG' ).
    cl_abap_unit_assert=>assert_equals( act = back-obj_name exp = '/MYNS/DEMO' ).
  ENDMETHOD.


  METHOD special_characters_survive.
    DATA(text) = `Größe < 10 & "Daten" > 5 €`.

    DATA(read) = cut->from_xlsx( cut->to_xlsx( VALUE #( ( line( text ) ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = CONV string( read-lines[ 1 ]-target_text ) exp = text ).
  ENDMETHOD.


  METHOD empty_translation_stays_empty.
    DATA(read) = cut->from_xlsx( cut->to_xlsx( VALUE #( ( line( ) ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( read-lines[ 1 ]-target_text ).
  ENDMETHOD.


  METHOD excel_saved_strings_are_read.
    " Excel saves strings as indexes into xl/sharedStrings.xml; a rich text
    " is split into runs.
    DATA(sheet) =
      |<worksheet xmlns="{ spreadsheet_namespace }"><sheetData>| &&
      `<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" t="s"><v>2</v></c>` &&
      `<c r="D1" t="s"><v>3</v></c><c r="E1" t="s"><v>4</v></c></row>` &&
      `<row r="2"><c r="A2" t="s"><v>5</v></c><c r="B2" t="s"><v>6</v></c><c r="C2" t="s"><v>7</v></c>` &&
      `<c r="D2" t="s"><v>8</v></c><c r="E2" t="s"><v>9</v></c></row>` &&
      `</sheetData></worksheet>`.
    DATA(strings) =
      |<sst xmlns="{ spreadsheet_namespace }">| &&
      `<si><t>Translation</t></si><si><t>SE63 type</t></si><si><t>SE63 name</t></si>` &&
      `<si><t>Text key</t></si><si><t>Language key</t></si>` &&
      `<si><r><t xml:space="preserve">Storage </t></r><r><rPr><b/></rPr><t>location</t></r></si>` &&
      `<si><t>RPT4</t></si><si><t>/MYNS/DEMO</t></si><si><t>I001</t></si><si><t>E</t></si>` &&
      `</sst>`.
    DATA(zip) = NEW cl_abap_zip( ).
    zip->add( name = `xl/worksheets/sheet1.xml` content = utf8( sheet ) ).
    zip->add( name = `xl/sharedStrings.xml` content = utf8( strings ) ).

    DATA(read) = cut->from_xlsx( zip->save( ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( read-lines[ 1 ]-target_text ) exp = `Storage location` ).
    cl_abap_unit_assert=>assert_equals( act = read-lines[ 1 ]-text_key exp = 'I001' ).
  ENDMETHOD.


  METHOD line_without_se63_name_is_left.
    DATA(without_name) = line( `Storage location` ).
    CLEAR without_name-lxe_name.

    DATA(read) = cut->from_xlsx( cut->to_xlsx( VALUE #( ( line( `A` ) ) ( without_name ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
  ENDMETHOD.


  METHOD file_that_is_no_zip_is_refused.
    DATA(read) = cut->from_xlsx( utf8( `Type;Object;Translation` ) ).

    cl_abap_unit_assert=>assert_not_initial( read-error ).
    cl_abap_unit_assert=>assert_initial( read-lines ).
  ENDMETHOD.


  METHOD foreign_sheet_is_refused.
    DATA(zip) = NEW cl_abap_zip( ).
    zip->add( name    = `xl/worksheets/sheet1.xml`
              content = utf8( |<worksheet xmlns="{ spreadsheet_namespace }"><sheetData>| &&
                              `<row r="1"><c r="A1" t="inlineStr"><is><t>Amount</t></is></c></row>` &&
                              `</sheetData></worksheet>` ) ).

    DATA(read) = cut->from_xlsx( zip->save( ) ).

    cl_abap_unit_assert=>assert_char_cp( act = read-error exp = '*Translation*' ).
  ENDMETHOD.

ENDCLASS.
