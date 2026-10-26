*"* use this source file for your ABAP unit test classes
" Tests of the namespace of object and package names.
CLASS ltc_namespace DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS package_of_core FOR TESTING.
    METHODS object_of_reports FOR TESTING.
    METHODS object_of_http_service FOR TESTING.
    METHODS customer_name_has_none FOR TESTING.
    METHODS lone_slash_has_none FOR TESTING.
    METHODS list_as_text FOR TESTING.
ENDCLASS.


CLASS ltc_namespace IMPLEMENTATION.

  METHOD package_of_core.
    cl_abap_unit_assert=>assert_equals( act = zcl_tr_namespace=>of_name( '/MYNS/CORE' ) exp = `/MYNS/` ).
  ENDMETHOD.


  METHOD object_of_reports.
    cl_abap_unit_assert=>assert_equals( act = zcl_tr_namespace=>of_name( '/MYNSREP/CL_REPORTS_AUTH' )
                                        exp = `/MYNSREP/` ).
  ENDMETHOD.


  METHOD object_of_http_service.
    cl_abap_unit_assert=>assert_equals( act = zcl_tr_namespace=>of_name( '/other/api' ) exp = `/OTHER/` ).
  ENDMETHOD.


  METHOD customer_name_has_none.
    cl_abap_unit_assert=>assert_initial( zcl_tr_namespace=>of_name( 'ZCL_TR_AUTH' ) ).
    cl_abap_unit_assert=>assert_initial( zcl_tr_namespace=>of_name( '$ZTR_REVIEW' ) ).
  ENDMETHOD.


  METHOD lone_slash_has_none.
    cl_abap_unit_assert=>assert_initial( zcl_tr_namespace=>of_name( '/MYNS' ) ).
    cl_abap_unit_assert=>assert_initial( zcl_tr_namespace=>of_name( '/' ) ).
  ENDMETHOD.


  METHOD list_as_text.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_namespace=>as_text( VALUE #( ( `/MYNSREP/` ) ( `/MYNS/` ) ) )
      exp = `/MYNS/, /MYNSREP/` ).
  ENDMETHOD.

ENDCLASS.
