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
    METHODS hardcoded_texts_in_own_sheet FOR TESTING.
    METHODS no_hardcoded_no_second_sheet FOR TESTING.
    METHODS hardcoded_sheet_is_not_read FOR TESTING.
    METHODS languages_are_named FOR TESTING.
    METHODS proposed_source_is_marked FOR TESTING.
    METHODS proposed_source_change_is_read FOR TESTING.
    METHODS same_proposal_is_no_change FOR TESTING.
    METHODS proposal_once_per_text FOR TESTING.
    METHODS csv_lines_are_read_back FOR TESTING.
    METHODS csv_is_utf8_with_semicolons FOR TESTING.
    METHODS csv_special_characters_survive FOR TESTING.
    METHODS csv_saved_with_commas_is_read FOR TESTING.
    METHODS csv_not_in_utf8_is_refused FOR TESTING.
    METHODS csv_without_columns_is_refused FOR TESTING.
    METHODS csv_proposed_source_is_read FOR TESTING.
    METHODS hardcoded_csv_has_proposals FOR TESTING.
    METHODS any_file_is_read_by_its_kind FOR TESTING.
    METHODS typed_file
      IMPORTING
        rows          TYPE string
      RETURNING
        VALUE(result) TYPE xstring.
    METHODS part
      IMPORTING
        file          TYPE xstring
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS hardcoded
      RETURNING
        VALUE(result) TYPE zcl_tr_transl_hardcoded=>ty_findings.
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


  METHOD hardcoded.
    result = VALUE #( ( object = 'PROG' obj_name = '/MYNS/XML_CREATE' include = '/MYNS/XML_CREATE'
                        line = 42 kind = zcl_tr_transl_hardcoded=>kind-message
                        text = `Invalid request paramter received` ) ).
  ENDMETHOD.


  METHOD part.
    DATA content TYPE xstring.

    DATA(zip) = NEW cl_abap_zip( ).
    zip->load( file ).
    zip->get(
      EXPORTING
        name    = name
      IMPORTING
        content = content
      EXCEPTIONS
        OTHERS  = 1 ).
    IF sy-subrc = 0.
      result = cl_abap_codepage=>convert_from( source = content codepage = `UTF-8` ).
    ENDIF.
  ENDMETHOD.


  METHOD hardcoded_texts_in_own_sheet.
    DATA(file) = cut->to_xlsx( lines = VALUE #( ( line( ) ) ) hardcoded = hardcoded( ) ).

    cl_abap_unit_assert=>assert_char_cp( act = part( file = file name = `xl/workbook.xml` )
                                         exp = '*name="Hardcoded texts"*' ).
    DATA(sheet) = part( file = file name = `xl/worksheets/sheet2.xml` ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*Invalid request paramter received*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*Proposed English*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*Proposed German*' ).
    cl_abap_unit_assert=>assert_char_cp( act = part( file = file name = `[Content_Types].xml` )
                                         exp = '*/xl/worksheets/sheet2.xml*' ).
    cl_abap_unit_assert=>assert_char_cp( act = part( file = file name = `xl/_rels/workbook.xml.rels` )
                                         exp = '*worksheets/sheet2.xml*' ).
  ENDMETHOD.


  METHOD no_hardcoded_no_second_sheet.
    DATA(file) = cut->to_xlsx( VALUE #( ( line( ) ) ) ).

    cl_abap_unit_assert=>assert_initial( part( file = file name = `xl/worksheets/sheet2.xml` ) ).
    cl_abap_unit_assert=>assert_char_np( act = part( file = file name = `xl/workbook.xml` )
                                         exp = '*Hardcoded*' ).
  ENDMETHOD.


  METHOD hardcoded_sheet_is_not_read.
    DATA(read) = cut->from_xlsx( cut->to_xlsx( lines     = VALUE #( ( line( `Storage location` ) ) )
                                               hardcoded = hardcoded( ) ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( read-lines[ 1 ]-target_text ) exp = `Storage location` ).
  ENDMETHOD.


  METHOD languages_are_named.
    " The source text says which language it is in, next to it, and the
    " language to translate into is named as the target.
    DATA(sheet) = part( file = cut->to_xlsx( VALUE #( ( line( ) ) ) ) name = `xl/worksheets/sheet1.xml` ).

    cl_abap_unit_assert=>assert_char_cp(
      act = sheet
      exp = '*>Source language<*>Source text<*>Proposed source text<*>Target language<*>Translation<*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*<c r="D2"*<t xml:space="preserve">DE</t>*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*<c r="G2"*<t xml:space="preserve">EN</t>*' ).
  ENDMETHOD.


  METHOD proposed_source_is_marked.
    " A proposal that differs from the source text marks both cells; the
    " proposal cell can be typed in.
    DATA(sheet) = part( file = cut->to_xlsx( VALUE #( ( line( ) ) ) ) name = `xl/worksheets/sheet1.xml` ).

    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*sqref="E2:F2"*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*AND($F2&lt;&gt;"",$F2&lt;&gt;$E2)*' ).
    cl_abap_unit_assert=>assert_char_cp( act = sheet exp = '*<c r="F2" s="2"/>*' ).
  ENDMETHOD.


  METHOD typed_file.
    " A first sheet as the translation team returns it, with a proposed
    " source text typed in.
    DATA(zip) = NEW cl_abap_zip( ).
    zip->add( name    = `xl/worksheets/sheet1.xml`
              content = utf8( |<worksheet xmlns="{ spreadsheet_namespace }"><sheetData>| &&
                              `<row r="1">` &&
                              `<c r="A1" t="inlineStr"><is><t>Type</t></is></c>` &&
                              `<c r="B1" t="inlineStr"><is><t>Object</t></is></c>` &&
                              `<c r="C1" t="inlineStr"><is><t>Kind of text</t></is></c>` &&
                              `<c r="D1" t="inlineStr"><is><t>Source text</t></is></c>` &&
                              `<c r="E1" t="inlineStr"><is><t>Proposed source text</t></is></c>` &&
                              `<c r="F1" t="inlineStr"><is><t>Translation</t></is></c>` &&
                              `<c r="G1" t="inlineStr"><is><t>SE63 type</t></is></c>` &&
                              `<c r="H1" t="inlineStr"><is><t>SE63 name</t></is></c>` &&
                              `<c r="I1" t="inlineStr"><is><t>Text key</t></is></c>` &&
                              `<c r="J1" t="inlineStr"><is><t>Language key</t></is></c>` &&
                              `</row>` && rows && `</sheetData></worksheet>` ) ).
    result = zip->save( ).
  ENDMETHOD.


  METHOD proposed_source_change_is_read.
    DATA(read) = cut->from_xlsx( typed_file(
      `<row r="2"><c r="A2" t="inlineStr"><is><t>MESS</t></is></c>` &&
      `<c r="B2" t="inlineStr"><is><t>/MYNS/CORE</t></is></c>` &&
      `<c r="C2" t="inlineStr"><is><t>Message</t></is></c>` &&
      `<c r="D2" t="inlineStr"><is><t>Speicherot</t></is></c>` &&
      `<c r="E2" t="inlineStr"><is><t>Speicherort</t></is></c>` &&
      `<c r="F2" t="inlineStr"><is><t>Storage location</t></is></c>` &&
      `<c r="G2" t="inlineStr"><is><t>MESS</t></is></c>` &&
      `<c r="H2" t="inlineStr"><is><t>/MYNS/CORE</t></is></c>` &&
      `<c r="I2" t="inlineStr"><is><t>001</t></is></c>` &&
      `<c r="J2" t="inlineStr"><is><t>E</t></is></c></row>` ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-source_changes ) exp = 1 ).
    DATA(change) = read-source_changes[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = change-source_text exp = `Speicherot` ).
    cl_abap_unit_assert=>assert_equals( act = change-proposed exp = `Speicherort` ).
    cl_abap_unit_assert=>assert_equals( act = change-text_kind exp = `Message` ).
    cl_abap_unit_assert=>assert_equals( act = change-obj_name exp = '/MYNS/CORE' ).
    cl_abap_unit_assert=>assert_equals( act = change-text_key exp = '001' ).
  ENDMETHOD.


  METHOD same_proposal_is_no_change.
    DATA(read) = cut->from_xlsx( typed_file(
      `<row r="2"><c r="D2" t="inlineStr"><is><t>Speicherort</t></is></c>` &&
      `<c r="E2" t="inlineStr"><is><t>Speicherort</t></is></c>` &&
      `<c r="H2" t="inlineStr"><is><t>/MYNS/CORE</t></is></c>` &&
      `<c r="I2" t="inlineStr"><is><t>001</t></is></c></row>` ) ).

    cl_abap_unit_assert=>assert_initial( read-source_changes ).
  ENDMETHOD.


  METHOD proposal_once_per_text.
    " The same source text has one line per target language; a proposal
    " typed on both lines is one change.
    DATA(row) =
      `<c r="D{n}" t="inlineStr"><is><t>Speicherot</t></is></c>` &&
      `<c r="E{n}" t="inlineStr"><is><t>Speicherort</t></is></c>` &&
      `<c r="G{n}" t="inlineStr"><is><t>MESS</t></is></c>` &&
      `<c r="H{n}" t="inlineStr"><is><t>/MYNS/CORE</t></is></c>` &&
      `<c r="I{n}" t="inlineStr"><is><t>001</t></is></c>`.
    DATA(read) = cut->from_xlsx( typed_file(
      |<row r="2">{ replace( val = row sub = `{n}` with = `2` occ = 0 ) }| &&
      `<c r="J2" t="inlineStr"><is><t>E</t></is></c></row>` &&
      |<row r="3">{ replace( val = row sub = `{n}` with = `3` occ = 0 ) }| &&
      `<c r="J3" t="inlineStr"><is><t>F</t></is></c></row>` ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( read-source_changes ) exp = 1 ).
  ENDMETHOD.


  METHOD csv_lines_are_read_back.
    DATA(written) = VALUE zcl_tr_transl_check=>ty_findings( ( line( `Storage location` ) ) ).

    DATA(read) = cut->from_csv( cut->to_csv( written ) ).

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


  METHOD csv_is_utf8_with_semicolons.
    " Byte order mark first, so that every program sees UTF-8; every value
    " in quotes; the languages named as in the Excel file.
    DATA mark TYPE x LENGTH 3.

    DATA(file) = cut->to_csv( VALUE #( ( line( ) ) ) ).

    mark = file.
    cl_abap_unit_assert=>assert_equals( act = mark exp = cl_abap_char_utilities=>byte_order_mark_utf8 ).
    SHIFT file LEFT BY 3 PLACES IN BYTE MODE.
    DATA(text) = cl_abap_codepage=>convert_from( source = file codepage = `UTF-8` ).
    SPLIT text AT cl_abap_char_utilities=>cr_lf INTO TABLE DATA(rows).
    cl_abap_unit_assert=>assert_equals(
      act = rows[ 1 ]
      exp = `"Type";"Object";"Kind of text";"Source language";"Source text";"Proposed source text";` &&
            `"Target language";"Translation";"Max. length";"SE63 type";"SE63 name";"Text key";` &&
            `"Customer number";"Language key"` ).
    cl_abap_unit_assert=>assert_char_cp( act = rows[ 2 ] exp = '"PROG";"/MYNS/DEMO";*;"DE";"Speicherort";"";"EN";"";"20";*' ).
  ENDMETHOD.


  METHOD csv_special_characters_survive.
    " Separators, quotes, line breaks, a leading blank and umlauts are part
    " of a text. (A text field of SE63 keeps no trailing blank.)
    DATA(text) = | Größe; "Daten", 5 €{ cl_abap_char_utilities=>cr_lf }zweite Zeile|.

    DATA(read) = cut->from_csv( cut->to_csv( VALUE #( ( line( text ) ) ) ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( read-lines[ 1 ]-target_text ) exp = text ).
  ENDMETHOD.


  METHOD csv_saved_with_commas_is_read.
    " A program that saves the file again may use commas, no quotes and no
    " byte order mark.
    DATA(read) = cut->from_csv( utf8( |Translation,SE63 type,SE63 name,Text key,Language key\n| &&
                                      |"Storage location, central",RPT4,/MYNS/DEMO,I001,E\n| ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-lines ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( read-lines[ 1 ]-target_text )
                                        exp = `Storage location, central` ).
    cl_abap_unit_assert=>assert_equals( act = read-lines[ 1 ]-text_key exp = 'I001' ).
  ENDMETHOD.


  METHOD csv_not_in_utf8_is_refused.
    " "Größe" saved in the Windows code page: ö is the single byte F6.
    CONSTANTS o_in_windows_code_page TYPE x LENGTH 1 VALUE 'F6'.
    DATA(file) = utf8( |"Translation";"SE63 type";"SE63 name";"Text key";"Language key"\r\n"Gr| ).
    DATA(rest) = utf8( `ße";"RPT4";"X";"I001";"D"` ).
    CONCATENATE file o_in_windows_code_page rest INTO file IN BYTE MODE.

    DATA(read) = cut->from_csv( file ).

    cl_abap_unit_assert=>assert_char_cp( act = read-error exp = '*UTF-8*' ).
    cl_abap_unit_assert=>assert_initial( read-lines ).
  ENDMETHOD.


  METHOD csv_without_columns_is_refused.
    DATA(read) = cut->from_csv( utf8( |Amount;Currency\r\n10;EUR| ) ).

    cl_abap_unit_assert=>assert_char_cp( act = read-error exp = '*Translation*' ).
    cl_abap_unit_assert=>assert_initial( read-lines ).
  ENDMETHOD.


  METHOD csv_proposed_source_is_read.
    DATA(read) = cut->from_csv( utf8(
      |"Kind of text";"Source text";"Proposed source text";"Translation";"SE63 type";"SE63 name";| &&
      |"Text key";"Language key"\r\n| &&
      |"Message";"Speicherot";"Speicherort";"Storage location";"MESS";"/MYNS/CORE";"001";"E"\r\n| ) ).

    cl_abap_unit_assert=>assert_initial( read-error ).
    cl_abap_unit_assert=>assert_equals( act = lines( read-source_changes ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = read-source_changes[ 1 ]-proposed exp = `Speicherort` ).
    cl_abap_unit_assert=>assert_equals( act = read-source_changes[ 1 ]-text_kind exp = `Message` ).
  ENDMETHOD.


  METHOD hardcoded_csv_has_proposals.
    DATA(text) = cl_abap_codepage=>convert_from( source = cut->hardcoded_to_csv( hardcoded( ) ) codepage = `UTF-8` ).

    cl_abap_unit_assert=>assert_char_cp(
      act = text
      exp = '*"Type";"Object";"Include";"Line";"Kind";"Text in the code";"Proposed English";"Proposed German"*' ).
    cl_abap_unit_assert=>assert_char_cp( act = text exp = '*"42";*"Invalid request paramter received";"";""*' ).
  ENDMETHOD.


  METHOD any_file_is_read_by_its_kind.
    DATA(written) = VALUE zcl_tr_transl_check=>ty_findings( ( line( `Storage location` ) ) ).

    DATA(from_excel) = cut->from_file( cut->to_xlsx( written ) ).
    DATA(from_csv) = cut->from_file( cut->to_csv( written ) ).

    cl_abap_unit_assert=>assert_initial( from_excel-error ).
    cl_abap_unit_assert=>assert_initial( from_csv-error ).
    cl_abap_unit_assert=>assert_equals( act = from_csv-lines exp = from_excel-lines ).
  ENDMETHOD.

ENDCLASS.
