" Tests of the rule that decides which tables the tools write to Git and may write back. They read
" the object directory and the dictionary, nothing is changed.
CLASS ltc_content_table DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS unknown_table_is_refused FOR TESTING.
    METHODS empty_name_is_refused FOR TESTING.
    METHODS sap_table_is_refused FOR TESTING.
ENDCLASS.


CLASS ltc_content_table IMPLEMENTATION.

  METHOD unknown_table_is_refused.
    cl_abap_unit_assert=>assert_false( zcl_tr_content=>is_content_table( 'ZNOSUCHTABLE_X' ) ).
  ENDMETHOD.


  METHOD empty_name_is_refused.
    cl_abap_unit_assert=>assert_false( zcl_tr_content=>is_content_table( '' ) ).
  ENDMETHOD.


  METHOD sap_table_is_refused.
    " USR02 holds the password hashes of the system. It is in no package under Git.
    cl_abap_unit_assert=>assert_false( zcl_tr_content=>is_content_table( 'USR02' ) ).
  ENDMETHOD.

ENDCLASS.
