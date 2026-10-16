*"* use this source file for your ABAP unit test classes
" Tests of the length rule of a translation: the same rule decides the
" Length check column of the list and whether Save writes a text.
CLASS ltc_length DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS text_that_fits_is_ok FOR TESTING.
    METHODS exactly_max_length_is_ok FOR TESTING.
    METHODS longer_text_says_by_how_much FOR TESTING.
    METHODS no_limit_never_exceeds FOR TESTING.
    METHODS no_translation_has_no_status FOR TESTING.
    METHODS trailing_blanks_do_not_count FOR TESTING.
ENDCLASS.


CLASS ltc_length IMPLEMENTATION.

  METHOD text_that_fits_is_ok.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>length_status( text = `Storage` max_length = 10 )
      exp = `OK` ).
  ENDMETHOD.


  METHOD exactly_max_length_is_ok.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>exceeded_by( text = `0123456789` max_length = 10 )
      exp = 0 ).
  ENDMETHOD.


  METHOD longer_text_says_by_how_much.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>exceeded_by( text = `Storage location` max_length = 10 )
      exp = 6 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>length_status( text = `Storage location` max_length = 10 )
      exp = `Too long by 6` ).
  ENDMETHOD.


  METHOD no_limit_never_exceeds.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>exceeded_by( text = `A rather long text without a limit` max_length = 0 )
      exp = 0 ).
  ENDMETHOD.


  METHOD no_translation_has_no_status.
    cl_abap_unit_assert=>assert_initial( zcl_tr_transl_check=>length_status( text = `` max_length = 10 ) ).
  ENDMETHOD.


  METHOD trailing_blanks_do_not_count.
    " The texts of SE63 are fixed-length fields: their trailing blanks are
    " not part of the translation.
    DATA text TYPE lxeunitlin VALUE 'Storage'.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>exceeded_by( text = text max_length = 7 )
      exp = 0 ).
  ENDMETHOD.

ENDCLASS.


" Which transport entries lead to recording the text pool at release.
CLASS ltc_record DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS code_parts_carry_no_texts FOR TESTING.
    METHODS text_entries_are_no_code FOR TESTING.
    METHODS main_program_of_types FOR TESTING.
ENDCLASS.


CLASS ltc_record IMPLEMENTATION.

  METHOD code_parts_carry_no_texts.
    DATA(code_parts) = VALUE string_table( ( `REPS` ) ( `METH` ) ( `CPRI` ) ( `FUNC` ) ).
    LOOP AT code_parts INTO DATA(object).
      cl_abap_unit_assert=>assert_true(
        act = zcl_tr_transl_check=>is_code_part( pgmid = 'LIMU' object = CONV #( object ) )
        msg = object ).
    ENDLOOP.
  ENDMETHOD.


  METHOD text_entries_are_no_code.
    " These carry their texts in all languages themselves.
    DATA(text_parts) = VALUE string_table( ( `REPT` ) ( `MESS` ) ( `DYNP` ) ( `CUAD` ) ).
    LOOP AT text_parts INTO DATA(object).
      cl_abap_unit_assert=>assert_false(
        act = zcl_tr_transl_check=>is_code_part( pgmid = 'LIMU' object = CONV #( object ) )
        msg = object ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_code_part( pgmid = 'R3TR' object = 'PROG' ) ).
  ENDMETHOD.


  METHOD main_program_of_types.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>main_program( VALUE #( object = 'FUGR' obj_name = '/MYNS/AUTH' ) )
      exp = '/MYNS/SAPLAUTH' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>main_program( VALUE #( object = 'FUGR' obj_name = 'ZFOO' ) )
      exp = 'SAPLZFOO' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>main_program( VALUE #( object = 'PROG' obj_name = 'ZREPORT' ) )
      exp = 'ZREPORT' ).
    cl_abap_unit_assert=>assert_initial(
      zcl_tr_transl_check=>main_program( VALUE #( object = 'MSAG' obj_name = '/MYNS/MESSAGES' ) ) ).
  ENDMETHOD.

ENDCLASS.


" The kind of text shown to the translator instead of the SE63 type.
CLASS ltc_text_kind DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS text_pool_is_split_by_key FOR TESTING.
    METHODS types_in_plain_words FOR TESTING.
    METHODS unknown_type_names_it FOR TESTING.
ENDCLASS.


CLASS ltc_text_kind IMPLEMENTATION.

  METHOD text_pool_is_split_by_key.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT4' text_key = 'SP_FILE' )
      exp = `Selection screen field label` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT1' text_key = 'I001' )
      exp = `Text in a program (text symbol)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT8' text_key = '' )
      exp = `Text element of a program` ).
  ENDMETHOD.


  METHOD types_in_plain_words.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'MESS' text_key = 'TEXT' )
      exp = `Message (status bar or popup)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'CA1' text_key = '' )
      exp = `Menu, button or title (GUI status)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'SRT4' text_key = '' )
      exp = `Screen text (label, frame, button)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'VALU' text_key = '' )
      exp = `Value in a dropdown list` ).
  ENDMETHOD.


  METHOD unknown_type_names_it.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'XYZ1' text_key = '' )
      exp = `Other (SE63 type XYZ1)` ).
  ENDMETHOD.

ENDCLASS.
