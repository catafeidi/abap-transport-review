*"* use this source file for your ABAP unit test classes

" Reading a .properties file: keys, values, comments, continued lines.
CLASS ltc_properties DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS key_and_value FOR TESTING.
    METHODS comments_and_blank_lines_skip FOR TESTING.
    METHODS colon_and_blanks_separate FOR TESTING.
    METHODS continued_line_is_joined FOR TESTING.
    METHODS no_translation_marker_skips FOR TESTING.
    METHODS last_duplicate_key_wins FOR TESTING.
ENDCLASS.


CLASS ltc_properties IMPLEMENTATION.

  METHOD key_and_value.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `appTitle=Storage locations` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = properties[ key = `appTitle` ]-value exp = `Storage locations` ).
  ENDMETHOD.


  METHOD comments_and_blank_lines_skip.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `# XTIT: title` )
                                                          ( `! old style comment` )
                                                          ( `` )
                                                          ( `   ` )
                                                          ( `title=Title` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( properties ) exp = 1 ).
  ENDMETHOD.


  METHOD colon_and_blanks_separate.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `  save : Save` )
                                                          ( `cancel = Cancel = now` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = properties[ key = `save` ]-value exp = `Save` ).
    cl_abap_unit_assert=>assert_equals( act = properties[ key = `cancel` ]-value exp = `Cancel = now` ).
  ENDMETHOD.


  METHOD continued_line_is_joined.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `text=first part \` )
                                                          ( `    second part` )
                                                          ( `next=x` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = properties[ key = `text` ]-value exp = `first part second part` ).
    cl_abap_unit_assert=>assert_equals( act = lines( properties ) exp = 2 ).
  ENDMETHOD.


  METHOD no_translation_marker_skips.
    " SAP marks texts that are never translated with the text type NOTR.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `#NOTR: technical id` )
                                                          ( `appId=com.example.app` )
                                                          ( `# NOTR` )
                                                          ( `` )
                                                          ( `version=1.0` )
                                                          ( `#XTIT: title` )
                                                          ( `title=Title` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( properties ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = properties[ 1 ]-key exp = `title` ).
  ENDMETHOD.


  METHOD last_duplicate_key_wins.
    DATA(properties) = zcl_tr_transl_ui5=>parse( VALUE #( ( `title=` ) ( `title=Titel` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = properties[ key = `title` ]-value exp = `Titel` ).
  ENDMETHOD.

ENDCLASS.


" The language of a file from its name, and the file names of a language.
CLASS ltc_file_names DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS base_file_has_no_language FOR TESTING.
    METHODS language_and_region FOR TESTING.
    METHODS bundle_with_other_name FOR TESTING.
    METHODS german_matches_de_and_region FOR TESTING.
    METHODS chinese_has_two_scripts FOR TESTING.
    METHODS pseudo_language_never_matches FOR TESTING.
    METHODS short_word_is_no_language FOR TESTING.
    METHODS old_codes_of_languages FOR TESTING.
ENDCLASS.


CLASS ltc_file_names IMPLEMENTATION.

  METHOD base_file_has_no_language.
    DATA(name) = zcl_tr_transl_ui5=>split_file_name( `i18n/i18n.properties` ).
    cl_abap_unit_assert=>assert_equals( act = name-bundle exp = `i18n/i18n` ).
    cl_abap_unit_assert=>assert_initial( name-suffix ).
  ENDMETHOD.


  METHOD language_and_region.
    DATA(name) = zcl_tr_transl_ui5=>split_file_name( `webapp/i18n/i18n_zh_TW.properties` ).
    cl_abap_unit_assert=>assert_equals( act = name-bundle exp = `webapp/i18n/i18n` ).
    cl_abap_unit_assert=>assert_equals( act = name-suffix exp = `zh_TW` ).
  ENDMETHOD.


  METHOD bundle_with_other_name.
    DATA(name) = zcl_tr_transl_ui5=>split_file_name( `i18n/messagebundle_en.properties` ).
    cl_abap_unit_assert=>assert_equals( act = name-bundle exp = `i18n/messagebundle` ).
    cl_abap_unit_assert=>assert_equals( act = name-suffix exp = `en` ).
  ENDMETHOD.


  METHOD german_matches_de_and_region.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `de` language = 'D' ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `de_DE` language = 'D' ) ).
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_ui5=>is_file_of_language( suffix = `en` language = 'D' ) ).
  ENDMETHOD.


  METHOD chinese_has_two_scripts.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `zh_CN` language = '1' ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `zh_TW` language = 'M' ) ).
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_ui5=>is_file_of_language( suffix = `zh_TW` language = '1' ) ).
  ENDMETHOD.


  METHOD pseudo_language_never_matches.
    cl_abap_unit_assert=>assert_false( zcl_tr_transl_ui5=>is_file_of_language( suffix = `en_US_sappsd` language = 'E' ) ).
  ENDMETHOD.


  METHOD short_word_is_no_language.
    " ui and ovp are no language codes: they belong to the bundle name.
    DATA(name) = zcl_tr_transl_ui5=>split_file_name( `i18n/app_ui.properties` ).
    cl_abap_unit_assert=>assert_equals( act = name-bundle exp = `i18n/app_ui` ).
    cl_abap_unit_assert=>assert_initial( name-suffix ).
    name = zcl_tr_transl_ui5=>split_file_name( `i18n/app_ui_de.properties` ).
    cl_abap_unit_assert=>assert_equals( act = name-bundle exp = `i18n/app_ui` ).
    cl_abap_unit_assert=>assert_equals( act = name-suffix exp = `de` ).
  ENDMETHOD.


  METHOD old_codes_of_languages.
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `iw` language = 'B' ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `in` language = 'i' ) ).
    cl_abap_unit_assert=>assert_true( zcl_tr_transl_ui5=>is_file_of_language( suffix = `id` language = 'i' ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_tr_transl_ui5=>split_file_name( `i18n/i18n_iw.properties` )-suffix
                                        exp = `iw` ).
  ENDMETHOD.

ENDCLASS.


" The texts of one UI5 app against the required languages.
CLASS ltc_check_files DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_tr_transl_ui5.

    METHODS setup.
    METHODS check
      IMPORTING
        files         TYPE zcl_tr_transl_ui5=>ty_files
      RETURNING
        VALUE(result) TYPE zcl_tr_transl_ui5=>ty_findings.
    METHODS complete_app_has_no_findings FOR TESTING.
    METHODS missing_language_file FOR TESTING.
    METHODS missing_and_empty_keys FOR TESTING.
    METHODS original_language_needs_none FOR TESTING.
    METHODS without_base_file FOR TESTING.
    METHODS empty_source_is_not_required FOR TESTING.
    METHODS bundle_without_texts_skipped FOR TESTING.
    METHODS translated_in_se63 FOR TESTING.
    METHODS file_and_se63_together FOR TESTING.
ENDCLASS.


CLASS ltc_check_files IMPLEMENTATION.

  METHOD setup.
    cut = NEW zcl_tr_transl_ui5( VALUE #( ( 'E' ) ( 'D' ) ) ).
  ENDMETHOD.


  METHOD check.
    result = cut->check_files( application = 'ZAPP' devclass = 'ZPACKAGE' original_language = 'E' files = files ).
  ENDMETHOD.


  METHOD complete_app_has_no_findings.
    cl_abap_unit_assert=>assert_initial( check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ( `save=Save` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ( `save=Sichern` ) ) ) ) ) ).
  ENDMETHOD.


  METHOD missing_language_file.
    DATA(findings) = check( VALUE #(
      ( name = `i18n/i18n.properties` lines = VALUE #( ( `title=Title` ) ( `save=Save` ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-problem exp = zcl_tr_transl_ui5=>problem-file_missing ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-file exp = `i18n/i18n_de.properties` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-language exp = 'D' ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-application exp = 'ZAPP' ).
  ENDMETHOD.


  METHOD missing_and_empty_keys.
    DATA(findings) = check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ( `save=Save` ) ( `cancel=Cancel` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ( `save=` ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ text_key = `save` ]-source_text exp = `Save` ).
    cl_abap_unit_assert=>assert_equals( act = findings[ text_key = `cancel` ]-problem exp = zcl_tr_transl_ui5=>problem-text_missing ).
    cl_abap_unit_assert=>assert_equals( act = findings[ text_key = `cancel` ]-file exp = `i18n/i18n_de.properties` ).
  ENDMETHOD.


  METHOD original_language_needs_none.
    " English is the original language: i18n.properties is the English text.
    DATA(findings) = check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ) ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( findings[ language = 'E' ] ) ) ).
  ENDMETHOD.


  METHOD without_base_file.
    " Only messagebundle_en: the file of the original language is the reference.
    DATA(findings) = check( VALUE #(
      ( name = `i18n/messagebundle_en.properties` lines = VALUE #( ( `title=Title` ) ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-file exp = `i18n/messagebundle_de.properties` ).
  ENDMETHOD.


  METHOD empty_source_is_not_required.
    cl_abap_unit_assert=>assert_initial( check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ( `placeholder=` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ) ) ) ) ).
  ENDMETHOD.


  METHOD translated_in_se63.
    " No i18n_de.properties, but the texts are translated in SE63: the
    " UI5 repository serves them as i18n_de.properties at runtime.
    cl_abap_unit_assert=>assert_initial( check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ) in_se63 = abap_true ) ) ) ).
  ENDMETHOD.


  METHOD file_and_se63_together.
    " A key counts as translated when the file or SE63 has a text for it.
    DATA(findings) = check( VALUE #(
      ( name = `i18n/i18n.properties`    lines = VALUE #( ( `title=Title` ) ( `save=Save` ) ( `cancel=Cancel` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `title=Titel` ) ( `save=` ) ) )
      ( name = `i18n/i18n_de.properties` lines = VALUE #( ( `save=Sichern` ) ) in_se63 = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = findings[ 1 ]-text_key exp = `cancel` ).
  ENDMETHOD.


  METHOD bundle_without_texts_skipped.
    " Only comments: there is nothing to translate, so no file is missing.
    cl_abap_unit_assert=>assert_initial( check( VALUE #(
      ( name = `i18n/messagebundle_en.properties` lines = VALUE #( ( `# ${copyright}` ) ( `` ) ) ) ) ) ).
  ENDMETHOD.

ENDCLASS.
