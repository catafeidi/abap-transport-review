"! Console class for ADT (Run As, ABAP Application (Console), F9): checks this system as
"! report ZTR_SETUP does, without writing anything. Every line starts with its light.
"! Writing the settings needs input; do that with report ZTR_SETUP.
CLASS zcl_tr_console_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    METHODS settings
      RETURNING
        VALUE(result) TYPE zcl_tr_setup=>ty_settings.
    METHODS text_of
      IMPORTING
        line          TYPE zcl_tr_setup=>ty_line
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_tr_console_check IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(lines) = NEW zcl_tr_setup( settings( ) )->run( ).
    LOOP AT lines INTO DATA(line).
      out->write( text_of( line ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD settings.
    result = VALUE #(
      client_id        = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-client_id )
      packages         = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-packages )
      require_complete = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-require_complete )
      variant_pattern  = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_pattern )
      variant_package  = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_package )
      abaplint_version = `v740sp08` ).
    zcl_tr_setup=>abaplint_setting( IMPORTING url   = result-abaplint_url
                                              depth = result-abaplint_depth ).
  ENDMETHOD.


  METHOD text_of.
    CASE line-kind.
      WHEN zcl_tr_setup=>state-ok.
        result = |[ OK ]   { line-text }|.
      WHEN zcl_tr_setup=>state-todo.
        result = |[ TODO ] { line-text }|.
      WHEN zcl_tr_setup=>state-info.
        result = |[ INFO ] { line-text }|.
      WHEN zcl_tr_setup=>state-heading.
        result = |{ cl_abap_char_utilities=>newline }== { line-text }|.
      WHEN zcl_tr_setup=>state-note.
        result = |         { line-text }|.
      WHEN OTHERS.
        result = ``.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
