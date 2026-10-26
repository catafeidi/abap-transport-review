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


" Which SE63 texts the user sees when the product runs. TLGS is one
" SE63 type for many repository objects; the object type at the start of
" its name decides.
CLASS ltc_runtime_type DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PUBLIC SECTION.
    " A TLGS name as SE63 builds it: object type (4), name (40), part (2).
    CLASS-METHODS tlgs
      IMPORTING
        type          TYPE csequence
        name          TYPE csequence
        part          TYPE csequence
      RETURNING
        VALUE(result) TYPE lxeobjname.

  PRIVATE SECTION.
    METHODS classic_texts_unchanged FOR TESTING.
    METHODS cds_field_labels FOR TESTING.
    METHODS cds_view_description_is_not FOR TESTING.
    METHODS metadata_extension_ui_texts FOR TESTING.
    METHODS metadata_extension_description FOR TESTING.
    METHODS launchpad_tile_texts FOR TESTING.
    METHODS service_descriptions_are_not FOR TESTING.
    METHODS ui5_app_description_is_not FOR TESTING.
ENDCLASS.


CLASS ltc_runtime_type IMPLEMENTATION.

  METHOD tlgs.
    DATA object_name TYPE c LENGTH 40.

    object_name = name.
    result = |{ type }{ object_name WIDTH = 40 }{ part }|.
  ENDMETHOD.


  METHOD classic_texts_unchanged.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'MESS' lxe_name = '/MYNS/CORE' ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'RPT4' lxe_name = '/MYNS/CORE' ) ).
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'TABT' lxe_name = '/MYNS/CORE' ) ).
  ENDMETHOD.


  METHOD cds_field_labels.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'DDLT' lxe_name = 'I_COMPANYCODE' ) ).
  ENDMETHOD.


  METHOD cds_view_description_is_not.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'DDLS' lxe_name = 'I_COMPANYCODE' ) ).
  ENDMETHOD.


  METHOD metadata_extension_ui_texts.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'DDLX' name = 'CDR_C_DETAILS_U' part = '06' ) ) ).
  ENDMETHOD.


  METHOD metadata_extension_description.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'DDLX' name = 'CDR_C_DETAILS_U' part = '02' ) ) ).
  ENDMETHOD.


  METHOD launchpad_tile_texts.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'UIAD' name = '/ACCGO/GFFEEDDDCCBBBA94' part = '02' ) ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'UIAD' name = '/ACCGO/GFFEEDDDCCBBBA94' part = '04' ) ) ).
  ENDMETHOD.


  METHOD service_descriptions_are_not.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'IWSV' name = '/ACI/ASSET_CENTRAL_CHANGE_NOTIF    0001' part = '02' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type(
      lxe_type = 'TLGS'
      lxe_name = tlgs( type = 'SUSC' name = '/AGG' part = '02' ) ) ).
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'TLGS' lxe_name = 'UI' ) ).
  ENDMETHOD.


  METHOD ui5_app_description_is_not.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_check=>is_runtime_type( lxe_type = 'BSP' lxe_name = 'ZAPP' ) ).
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
    METHODS fiori_texts_in_plain_words FOR TESTING.
ENDCLASS.


CLASS ltc_text_kind IMPLEMENTATION.

  METHOD text_pool_is_split_by_key.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT4' text_key = 'SP_FILE' lxe_name = '' )
      exp = `Selection screen field label` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT1' text_key = 'I001' lxe_name = '' )
      exp = `Text in a program (text symbol)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'RPT8' text_key = '' lxe_name = '' )
      exp = `Text element of a program` ).
  ENDMETHOD.


  METHOD types_in_plain_words.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'MESS' text_key = 'TEXT' lxe_name = '' )
      exp = `Message (status bar or popup)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'CA1' text_key = '' lxe_name = '' )
      exp = `Menu, button or title (GUI status)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'SRT4' text_key = '' lxe_name = '' )
      exp = `Screen text (label, frame, button)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'VALU' text_key = '' lxe_name = '' )
      exp = `Value in a dropdown list` ).
  ENDMETHOD.


  METHOD unknown_type_names_it.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'XYZ1' text_key = '' lxe_name = '' )
      exp = `Other (SE63 type XYZ1)` ).
  ENDMETHOD.


  METHOD fiori_texts_in_plain_words.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'DDLT' text_key = '' lxe_name = 'I_COMPANYCODE' )
      exp = `Field label of a CDS view (Fiori app)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'TLGS' text_key = '' lxe_name = ltc_runtime_type=>tlgs( type = 'DDLX'
                                                                                                         name = 'C_DETAILS'
                                                                                                         part = '06' ) )
      exp = `UI text of a CDS view (Fiori annotation)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'TLGS' text_key = '' lxe_name = ltc_runtime_type=>tlgs( type = 'UIAD'
                                                                                                         name = 'ZAPP_TILE'
                                                                                                         part = '02' ) )
      exp = `Launchpad tile (title, subtitle)` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_tr_transl_check=>text_kind( lxe_type = 'TLGS' text_key = '' lxe_name = ltc_runtime_type=>tlgs( type = 'IWSV'
                                                                                                         name = 'ZSERVICE 0001'
                                                                                                         part = '02' ) )
      exp = `Description (IWSV)` ).
  ENDMETHOD.

ENDCLASS.

" The texts of UI5 apps count at release like the other missing texts.
CLASS ltc_ui5_texts DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS missing_text_of_an_app FOR TESTING.
    METHODS missing_file_of_an_app FOR TESTING.
ENDCLASS.


CLASS ltc_ui5_texts IMPLEMENTATION.

  METHOD missing_text_of_an_app.
    DATA(findings) = zcl_tr_transl_check=>from_ui5_findings( VALUE #(
      ( application = 'ZAPP' devclass = 'ZPACKAGE' file = `i18n/i18n_de.properties` language = 'D'
        source_language = 'E' text_key = `save` source_text = `Save`
        problem = zcl_tr_transl_ui5=>problem-text_missing ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    DATA(finding) = findings[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = finding-object exp = 'WAPA' ).
    cl_abap_unit_assert=>assert_equals( act = finding-obj_name exp = 'ZAPP' ).
    cl_abap_unit_assert=>assert_equals( act = finding-status exp = zcl_tr_transl_check=>status-missing ).
    cl_abap_unit_assert=>assert_equals( act = finding-language exp = 'D' ).
    cl_abap_unit_assert=>assert_equals( act = finding-text_key exp = 'save' ).
    cl_abap_unit_assert=>assert_equals( act = finding-source_text exp = 'Save' ).
    cl_abap_unit_assert=>assert_equals( act = finding-lxe_name exp = 'i18n/i18n_de.properties' ).
    cl_abap_unit_assert=>assert_equals( act = finding-text_kind exp = 'Text of a UI5 app (i18n file)' ).
  ENDMETHOD.


  METHOD missing_file_of_an_app.
    DATA(findings) = zcl_tr_transl_check=>from_ui5_findings( VALUE #(
      ( application = 'ZAPP' file = `i18n/i18n_de.properties` language = 'D' source_language = 'E'
        source_text = `5 text(s) to translate` problem = zcl_tr_transl_ui5=>problem-file_missing ) ) ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-status exp = zcl_tr_transl_check=>status-missing ).
    cl_abap_unit_assert=>assert_initial( findings[ 1 ]-text_key ).
  ENDMETHOD.

ENDCLASS.
