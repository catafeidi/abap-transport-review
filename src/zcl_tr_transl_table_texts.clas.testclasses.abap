*"* use this source file for your ABAP unit test classes
" Tests of the comparison of the entries of a text table per language.
" The rows are written here; no table is read.
CLASS ltc_rows DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_row,
        id    TYPE c LENGTH 10,
        spras TYPE spras,
        text  TYPE c LENGTH 40,
      END OF ty_row.
    TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.

    DATA cut TYPE REF TO zcl_tr_transl_table_texts.

    METHODS setup.
    METHODS check
      IMPORTING
        rows          TYPE ty_rows
      RETURNING
        VALUE(result) TYPE zcl_tr_transl_table_texts=>ty_findings.

    METHODS entry_in_both_is_complete FOR TESTING.
    METHODS entry_only_in_german_is_found FOR TESTING.
    METHODS entry_in_other_language_only FOR TESTING.
ENDCLASS.


CLASS ltc_rows IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( VALUE #( ( 'D' ) ( 'E' ) ) ).
  ENDMETHOD.


  METHOD check.
    result = cut->check_rows( rows = rows key_fields = VALUE #( ( `ID` ) ) language_field = 'SPRAS' text_field = 'TEXT' ).
  ENDMETHOD.


  METHOD entry_in_both_is_complete.
    cl_abap_unit_assert=>assert_initial(
      check( VALUE #( ( id = 'A' spras = 'D' text = 'Speicherort' ) ( id = 'A' spras = 'E' text = 'Storage' ) ) ) ).
  ENDMETHOD.


  METHOD entry_only_in_german_is_found.
    DATA(findings) = check( VALUE #( ( id = 'A' spras = 'D' text = 'Speicherort' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-entry_key exp = `A` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-language exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-source_language exp = 'D' ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-source_text exp = `Speicherort` ).
  ENDMETHOD.


  METHOD entry_in_other_language_only.
    " A customer entry in Romanian alone is not a text of the product.
    cl_abap_unit_assert=>assert_initial( check( VALUE #( ( id = 'B' spras = 'O' text = 'Locatie' ) ) ) ).
  ENDMETHOD.

ENDCLASS.
