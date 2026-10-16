*"* use this source file for your ABAP unit test classes
" Tests of the search for hardcoded texts in one source. The sources are
" written here; nothing is read from the system.
CLASS ltc_scan DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_tr_transl_hardcoded.

    METHODS setup.
    METHODS kinds_of
      IMPORTING
        source        TYPE string_table
      RETURNING
        VALUE(result) TYPE string_table.

    METHODS message_literal_is_found FOR TESTING.
    METHODS message_template_is_found FOR TESTING.
    METHODS message_of_a_class_is_not FOR TESTING.
    METHODS text_symbol_is_not_found FOR TESTING.
    METHODS message_00_is_found FOR TESTING.
    METHODS literal_after_with_is_found FOR TESTING.
    METHODS write_literal_is_found FOR TESTING.
    METHODS popup_parameter_is_found FOR TESTING.
    METHODS alv_column_text_is_found FOR TESTING.
    METHODS salv_text_method_is_found FOR TESTING.
    METHODS technical_literal_is_not FOR TESTING.
    METHODS text_constant_is_found FOR TESTING.
    METHODS line_number_is_kept FOR TESTING.
ENDCLASS.


CLASS ltc_scan IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( ).
  ENDMETHOD.


  METHOD kinds_of.
    DATA(findings) = cut->scan_source( source ).
    LOOP AT findings INTO DATA(finding).
      APPEND |{ finding-kind }: { finding-text }| TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD message_literal_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `MESSAGE 'No storage profile found' TYPE 'E'.` ) ) )
      exp = VALUE string_table( ( `message: No storage profile found` ) ) ).
  ENDMETHOD.


  METHOD message_template_is_found.
    DATA(act) = concat_lines_of( table = kinds_of( VALUE #( ( `MESSAGE |File { name } not found| TYPE 'S'.` ) ) )
                                 sep   = `#` ).
    cl_abap_unit_assert=>assert_equals(
      act = act
      exp = `message: File {...} not found`
      msg = |Found: "{ act }"| ).
  ENDMETHOD.


  METHOD message_of_a_class_is_not.
    cl_abap_unit_assert=>assert_initial(
      kinds_of( VALUE #( ( `MESSAGE e010(/myns/msg) WITH name.` ) ( `MESSAGE text TYPE 'I'.` ) ) ) ).
  ENDMETHOD.


  METHOD text_symbol_is_not_found.
    cl_abap_unit_assert=>assert_initial(
      kinds_of( VALUE #( ( `MESSAGE 'No storage profile found'(001) TYPE 'E'.` )
                         ( `WRITE: / 'Total'(002), total.` ) ) ) ).
  ENDMETHOD.


  METHOD message_00_is_found.
    DATA(findings) = cut->scan_source( VALUE #( ( `MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2.` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-kind exp = zcl_tr_transl_hardcoded=>kind-generic_message ).
  ENDMETHOD.


  METHOD literal_after_with_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `MESSAGE e010(/myns/msg) WITH 'Storage profile' name.` ) ) )
      exp = VALUE string_table( ( `message text: Storage profile` ) ) ).
  ENDMETHOD.


  METHOD write_literal_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `WRITE: / 'Total:', total.` ) ) )
      exp = VALUE string_table( ( `list output: Total:` ) ) ).
  ENDMETHOD.


  METHOD popup_parameter_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `CALL FUNCTION 'POPUP_TO_CONFIRM'` )
                               ( `  EXPORTING` )
                               ( `    titlebar      = 'Delete'` )
                               ( `    text_question = text` )
                               ( `  IMPORTING` )
                               ( `    answer        = answer.` ) ) )
      exp = VALUE string_table( ( `screen text: Delete` ) ) ).
  ENDMETHOD.


  METHOD alv_column_text_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `catalog = VALUE #( ( fieldname = 'STATUS' coltext = 'Status' ) ).` )
                               ( `layout-grid_title = 'Requests'.` ) ) )
      exp = VALUE string_table( ( `screen text: Status` ) ( `screen text: Requests` ) ) ).
  ENDMETHOD.


  METHOD salv_text_method_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `columns->get_column( 'STATUS_TEXT' )->set_long_text( 'Status' ).` ) ) )
      exp = VALUE string_table( ( `screen text: Status` ) ) ).
  ENDMETHOD.


  METHOD technical_literal_is_not.
    cl_abap_unit_assert=>assert_initial(
      kinds_of( VALUE #( ( `SELECT SINGLE low FROM tvarvc INTO @value WHERE name = 'ZTR_PACKAGES'.` )
                         ( `IF type = 'E'.` )
                         ( `ENDIF.` )
                         ( `CONSTANTS mode TYPE c LENGTH 5 VALUE 'BLOCK'.` )
                         ( `CONSTANTS xml TYPE string VALUE '<item><NAME>CHAR_REPL</NAME></item>'.` )
                         ( `WRITE value USING EDIT MASK '==ALPHA'.` )
                         ( `button-text = '/MYNS/BUTTON_ON'.` )
                         ( `CONSTANTS algorithm TYPE string VALUE 'http://www.w3.org/2001/04/xmlenc#aes256-cbc'.` ) ) ) ).
  ENDMETHOD.


  METHOD text_constant_is_found.
    cl_abap_unit_assert=>assert_equals(
      act = kinds_of( VALUE #( ( `CONSTANTS not_found TYPE string VALUE 'File not found'.` ) ) )
      exp = VALUE string_table( ( `text constant: File not found` ) ) ).
  ENDMETHOD.


  METHOD line_number_is_kept.
    DATA(findings) = cut->scan_source( VALUE #( ( `DATA x TYPE i.` ) ( `` ) ( `MESSAGE 'Done' TYPE 'S'.` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-line exp = 3 ).
  ENDMETHOD.

ENDCLASS.
