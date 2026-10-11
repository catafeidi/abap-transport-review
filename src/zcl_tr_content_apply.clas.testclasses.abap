*"* use this source file for your ABAP unit test classes
" Tests of the comparison of a content file with the rows of a system.
" Rows of TVARVC live in memory only: nothing is read from or written to
" the database. HIGH stands in for a credential field.
CLASS ltc_compare_rows DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    TYPES ty_rows TYPE STANDARD TABLE OF tvarvc WITH DEFAULT KEY.

    DATA fields       TYPE zcl_tr_content=>ty_key_fields.
    DATA client_field TYPE fieldname.
    DATA secrets      TYPE zcl_tr_content=>ty_field_names.
    DATA to_write     TYPE ty_rows.
    DATA missing_rows TYPE ty_rows.
    DATA inserted     TYPE i.
    DATA changed      TYPE i.
    DATA unchanged    TYPE i.

    METHODS setup.
    METHODS compare
      IMPORTING
        git_rows    TYPE ty_rows
        system_rows TYPE ty_rows.
    METHODS row
      IMPORTING
        name          TYPE tvarvc-name
        low           TYPE tvarvc-low OPTIONAL
        high          TYPE tvarvc-high OPTIONAL
        client        TYPE tvarvc-mandt OPTIONAL
      RETURNING
        VALUE(result) TYPE tvarvc.

    METHODS key_fields_are_read_from_ddic FOR TESTING.
    METHODS row_only_in_git_is_inserted FOR TESTING.
    METHODS row_that_is_equal_is_unchanged FOR TESTING.
    METHODS differing_row_is_overwritten FOR TESTING.
    METHODS secret_alone_is_no_change FOR TESTING.
    METHODS changed_row_keeps_secret FOR TESTING.
    METHODS new_row_takes_no_git_secret FOR TESTING.
    METHODS row_only_in_system_is_missing FOR TESTING.
    METHODS empty_file_misses_all_rows FOR TESTING.
ENDCLASS.


CLASS ltc_compare_rows IMPLEMENTATION.

  METHOD setup.
    zcl_tr_content=>key_fields(
      EXPORTING
        table        = 'TVARVC'
      IMPORTING
        fields       = fields
        client_field = client_field ).
    secrets = VALUE #( ( 'HIGH' ) ).
    CLEAR: to_write, missing_rows, inserted, changed, unchanged.
  ENDMETHOD.


  METHOD row.
    result-mandt = client.
    result-name  = name.
    result-type  = 'P'.
    result-low   = low.
    result-high  = high.
  ENDMETHOD.


  METHOD compare.
    zcl_tr_content_apply=>compare_rows(
      EXPORTING
        git_rows     = git_rows
        system_rows  = system_rows
        fields       = fields
        client_field = client_field
        secrets      = secrets
        client       = '123'
      IMPORTING
        to_write     = to_write
        missing_rows = missing_rows
        inserted     = inserted
        changed      = changed
        unchanged    = unchanged ).
  ENDMETHOD.


  METHOD key_fields_are_read_from_ddic.
    cl_abap_unit_assert=>assert_equals( act = client_field exp = 'MANDT' ).
    cl_abap_unit_assert=>assert_equals( act = lines( fields ) exp = 3 ).
  ENDMETHOD.


  METHOD row_only_in_git_is_inserted.
    compare( git_rows    = VALUE #( ( row( name = 'ZNEW' low = 'x' ) ) )
             system_rows = VALUE #( ( row( name = 'ZOTHER' low = 'y' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = inserted exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( to_write ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-name exp = 'ZNEW' ).
    " Git holds no client: the row goes into the client of the system.
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-mandt exp = '123' ).
  ENDMETHOD.


  METHOD row_that_is_equal_is_unchanged.
    compare( git_rows    = VALUE #( ( row( name = 'ZSAME' low = 'x' ) ) )
             system_rows = VALUE #( ( row( name = 'ZSAME' low = 'x' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = unchanged exp = 1 ).
    cl_abap_unit_assert=>assert_initial( to_write ).
    cl_abap_unit_assert=>assert_initial( missing_rows ).
  ENDMETHOD.


  METHOD differing_row_is_overwritten.
    compare( git_rows    = VALUE #( ( row( name = 'ZVAR' low = 'new' ) ) )
             system_rows = VALUE #( ( row( name = 'ZVAR' low = 'old' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = changed exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( to_write ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-low exp = 'new' ).
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-mandt exp = '123' ).
  ENDMETHOD.


  METHOD secret_alone_is_no_change.
    " Git holds the credential blank, the system its real value: that is
    " the normal state, not something to write.
    compare( git_rows    = VALUE #( ( row( name = 'ZPROFILE' low = 'x' ) ) )
             system_rows = VALUE #( ( row( name = 'ZPROFILE' low = 'x' high = 'SECRET' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = unchanged exp = 1 ).
    cl_abap_unit_assert=>assert_initial( to_write ).
  ENDMETHOD.


  METHOD changed_row_keeps_secret.
    compare( git_rows    = VALUE #( ( row( name = 'ZPROFILE' low = 'new' ) ) )
             system_rows = VALUE #( ( row( name = 'ZPROFILE' low = 'old' high = 'SECRET' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = changed exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-low exp = 'new' ).
    cl_abap_unit_assert=>assert_equals( act = to_write[ 1 ]-high exp = 'SECRET' ).
  ENDMETHOD.


  METHOD new_row_takes_no_git_secret.
    " Even a credential that someone put into a file does not reach the system.
    compare( git_rows    = VALUE #( ( row( name = 'ZNEW' low = 'x' high = 'LEAKED' ) ) )
             system_rows = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( act = inserted exp = 1 ).
    cl_abap_unit_assert=>assert_initial( to_write[ 1 ]-high ).
  ENDMETHOD.


  METHOD row_only_in_system_is_missing.
    compare( git_rows    = VALUE #( ( row( name = 'ZGIT' low = 'x' ) ) )
             system_rows = VALUE #( ( row( name = 'ZGIT' low = 'x' client = '123' ) )
                                    ( row( name = 'ZLOCAL' low = 'y' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = unchanged exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( missing_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = missing_rows[ 1 ]-name exp = 'ZLOCAL' ).
    cl_abap_unit_assert=>assert_initial( to_write ).
  ENDMETHOD.


  METHOD empty_file_misses_all_rows.
    compare( git_rows    = VALUE #( )
             system_rows = VALUE #( ( row( name = 'ZA' client = '123' ) )
                                    ( row( name = 'ZB' client = '123' ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( missing_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( to_write ).
  ENDMETHOD.

ENDCLASS.
