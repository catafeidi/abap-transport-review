CLASS ltc_setup DEFINITION DEFERRED.
CLASS zcl_tr_setup DEFINITION LOCAL FRIENDS ltc_setup.

" Tests of the parts of the setup that need no system: the abaplint configuration it writes
" and the lines it returns. Nothing is read from or written to the database.
CLASS ltc_setup DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_tr_setup.

    METHODS setup.
    METHODS clean_json_is_valid FOR TESTING RAISING cx_static_check.
    METHODS abaplint_json_is_valid FOR TESTING RAISING cx_static_check.
    METHODS version_goes_into_json FOR TESTING RAISING cx_static_check.
    METHODS clean_json_has_the_rules FOR TESTING RAISING cx_static_check.
    METHODS todo_lines_are_counted FOR TESTING.
    METHODS other_lines_are_not_counted FOR TESTING.
    METHODS lines_keep_their_order FOR TESTING.
    METHODS heading_is_a_line FOR TESTING.
ENDCLASS.


CLASS ltc_setup IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( VALUE #( abaplint_version = `v740sp08` ) ).
  ENDMETHOD.


  METHOD clean_json_is_valid.
    DATA(json) = cut->clean_abap_json( ).

    DATA(parsed) = zcl_abapgit_ajson=>parse( json ).

    cl_abap_unit_assert=>assert_not_initial( parsed->get_string( '/syntax/version' ) ).
  ENDMETHOD.


  METHOD abaplint_json_is_valid.
    DATA(parsed) = zcl_abapgit_ajson=>parse( cut->abaplint_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = abap_true
                                        act = parsed->exists( '/rules/check_syntax' ) ).
  ENDMETHOD.


  METHOD version_goes_into_json.
    DATA(parsed) = zcl_abapgit_ajson=>parse( cut->abaplint_json( ) ).

    cl_abap_unit_assert=>assert_equals( exp = `v740sp08`
                                        act = parsed->get_string( '/syntax/version' ) ).
  ENDMETHOD.


  METHOD clean_json_has_the_rules.
    " The four rules that are wrong when the check sees one object alone must not be in it.
    DATA(json) = cut->clean_abap_json( ).

    cl_abap_unit_assert=>assert_false( xsdbool( json CS `"unused_variables"` ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( json CS `"prefer_inline"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( json CS `"align_parameters"` ) ).
  ENDMETHOD.


  METHOD todo_lines_are_counted.
    cut->line( kind = zcl_tr_setup=>state-todo
               text = 'one' ).
    cut->line( kind = zcl_tr_setup=>state-todo
               text = 'two' ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = cut->to_do ).
  ENDMETHOD.


  METHOD other_lines_are_not_counted.
    cut->line( kind = zcl_tr_setup=>state-ok
               text = 'fine' ).
    cut->line( kind = zcl_tr_setup=>state-info
               text = 'for information' ).

    cl_abap_unit_assert=>assert_equals( exp = 0
                                        act = cut->to_do ).
  ENDMETHOD.


  METHOD lines_keep_their_order.
    cut->line( kind = zcl_tr_setup=>state-ok
               text = 'first' ).
    cut->line( kind = zcl_tr_setup=>state-todo
               text = 'second' ).

    cl_abap_unit_assert=>assert_equals( exp = 2
                                        act = lines( cut->lines ) ).
    cl_abap_unit_assert=>assert_equals( exp = `first`
                                        act = cut->lines[ 1 ]-text ).
    cl_abap_unit_assert=>assert_equals( exp = zcl_tr_setup=>state-todo
                                        act = cut->lines[ 2 ]-kind ).
  ENDMETHOD.


  METHOD heading_is_a_line.
    cut->heading( 'Section' ).

    cl_abap_unit_assert=>assert_equals( exp = zcl_tr_setup=>state-heading
                                        act = cut->lines[ 1 ]-kind ).
  ENDMETHOD.

ENDCLASS.
