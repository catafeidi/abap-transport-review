"! Texts of UI5 apps: a UI5 app is a BSP application (WAPA) whose texts
"! are i18n files, not SE63 texts. Per bundle (i18n/i18n.properties, or
"! another name such as messagebundle) there is a file without language,
"! the text of the original language, and one file per translation:
"! i18n_de.properties, i18n_zh_TW.properties. A required language needs
"! its file, and the file needs every key of the original with a text.
"!
"! The reference is the file without language; when an app has none, the
"! file of its original language (i18n_en.properties). Pseudo languages
"! such as en_US_sappsd never count as a translation. Texts of type NOTR
"! (comment #NOTR before the key) are never translated.
"!
"! Two ways to translate an app deployed to the SAPUI5 ABAP repository,
"! and both count: the file in the app, or SE63 (the repository keeps the
"! texts of i18n.properties in /UI5/TREP_TEXT_T and serves
"! i18n_de.properties from the German translation at runtime).
"! The files and the SE63 texts are read with the API of the repository
"! (/UI5/IF_UI5_REP_DT, /UI5/IF_UI5_REP_TEXTS_RT), which knows its path
"! mapping and line format. The tools only list what is missing.
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_ui5 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF problem,
        file_missing TYPE c LENGTH 1 VALUE 'F',
        text_missing TYPE c LENGTH 1 VALUE 'T',
      END OF problem.
    TYPES:
      BEGIN OF ty_finding,
        application       TYPE o2applname,
        devclass          TYPE devclass,
        "! The language file that is missing, or that misses the text
        file              TYPE string,
        language          TYPE spras,
        source_language   TYPE spras,
        "! Empty when the whole file is missing
        text_key          TYPE string,
        source_text       TYPE string,
        problem           TYPE c LENGTH 1,
      END OF ty_finding.
    TYPES ty_findings TYPE STANDARD TABLE OF ty_finding WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_file,
        name    TYPE string,
        lines   TYPE string_table,
        "! The texts of the language as SE63 keeps them, not a file
        in_se63 TYPE abap_bool,
      END OF ty_file.
    TYPES ty_files TYPE STANDARD TABLE OF ty_file WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_property,
        key   TYPE string,
        value TYPE string,
      END OF ty_property.
    TYPES ty_properties TYPE SORTED TABLE OF ty_property WITH UNIQUE KEY key.
    TYPES:
      BEGIN OF ty_file_name,
        "! Folder and bundle: i18n/i18n
        bundle TYPE string,
        "! Language part: de, zh_TW; empty for the file of the original
        suffix TYPE string,
      END OF ty_file_name.

    "! @parameter languages | the required languages
    METHODS constructor
      IMPORTING
        languages TYPE zcl_tr_transl_check=>ty_languages.
    "! The missing translations of the UI5 apps among the objects (WAPA).
    "! Other objects are skipped.
    METHODS check_objects
      IMPORTING
        objects       TYPE zcl_tr_transl_check=>ty_objects
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! The missing translations of one app, from its i18n files.
    METHODS check_files
      IMPORTING
        application       TYPE o2applname
        devclass          TYPE devclass
        original_language TYPE spras
        files             TYPE ty_files
      RETURNING
        VALUE(result)     TYPE ty_findings.
    "! The keys and texts of a .properties file. Comments (# and !) and
    "! empty lines are skipped; a line ending with \ goes on in the next.
    CLASS-METHODS parse
      IMPORTING
        lines         TYPE string_table
      RETURNING
        VALUE(result) TYPE ty_properties.
    "! i18n/i18n_de_DE.properties -> bundle i18n/i18n, suffix de_DE.
    CLASS-METHODS split_file_name
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE ty_file_name.
    "! True when the language part of a file name is the SAP language:
    "! de and de_DE for D; zh_CN for 1 (Chinese), zh_TW for M.
    CLASS-METHODS is_file_of_language
      IMPORTING
        suffix        TYPE string
        language      TYPE spras
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS file_extension TYPE string VALUE `.properties`.
    CONSTANTS lowercase TYPE string VALUE `abcdefghijklmnopqrstuvwxyz`.
    CONSTANTS uppercase TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZ`.
    CONSTANTS chinese_simplified TYPE spras VALUE '1'.
    CONSTANTS chinese_traditional TYPE spras VALUE 'M'.
    CONSTANTS hebrew TYPE spras VALUE 'B'.
    CONSTANTS indonesian TYPE spras VALUE 'i'.
    CONSTANTS no_translation TYPE string VALUE `NOTR`.

    CLASS-DATA language_codes TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    DATA languages TYPE zcl_tr_transl_check=>ty_languages.

    "! The language parts a file of the language may have, first the one
    "! a new file gets: de; zh_CN, zh for Chinese.
    CLASS-METHODS suffixes_of
      IMPORTING
        language      TYPE spras
      RETURNING
        VALUE(result) TYPE string_table.
    "! Without blanks and tabs at the start and the end; inside unchanged.
    CLASS-METHODS trim
      IMPORTING
        text          TYPE csequence
      RETURNING
        VALUE(result) TYPE string.
    "! True for an ISO language code of T002 (de, zh), and the old codes
    "! UI5 still knows (iw, in).
    CLASS-METHODS is_language_code
      IMPORTING
        code          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.
    "! True when the comment before a key marks its text as never
    "! translated: #NOTR, # NOTR: ...
    CLASS-METHODS is_no_translation
      IMPORTING
        comment       TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS read_files
      IMPORTING
        application   TYPE o2applname
      RETURNING
        VALUE(result) TYPE ty_files.
    METHODS file_paths
      IMPORTING
        repository    TYPE REF TO /ui5/if_ui5_rep_dt
        folder        TYPE string
      RETURNING
        VALUE(result) TYPE string_table
      RAISING
        /ui5/cx_ui5_rep_dt.
    CLASS-METHODS as_lines
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE string_table.
ENDCLASS.



CLASS zcl_tr_transl_ui5 IMPLEMENTATION.

  METHOD constructor.
    me->languages = languages.
  ENDMETHOD.


  METHOD check_objects.
    DATA directory_entry TYPE tadir.

    LOOP AT objects INTO DATA(object) WHERE object = 'WAPA'.
      CLEAR directory_entry.
      SELECT SINGLE devclass masterlang FROM tadir
        INTO CORRESPONDING FIELDS OF directory_entry
        WHERE pgmid = 'R3TR' AND object = 'WAPA' AND obj_name = object-obj_name.
      DATA(application) = CONV o2applname( object-obj_name ).
      DATA(files) = read_files( application ).
      IF files IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND LINES OF check_files( application       = application
                                   devclass          = directory_entry-devclass
                                   original_language = COND #( WHEN directory_entry-masterlang IS INITIAL THEN 'E'
                                                               ELSE directory_entry-masterlang )
                                   files             = files ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_files.
    DATA content TYPE xstring.
    DATA codes   TYPE /ui5/trep_lang_codes_t.
    DATA text    TYPE string.

    TRY.
        DATA(repository) = /ui5/cl_ui5_rep_dt=>/ui5/if_ui5_rep_dt~get_api( iv_name = CONV string( application ) ).
        DATA(paths) = file_paths( repository = repository folder = `` ).
      CATCH cx_root.
        " Not an app of the SAPUI5 repository (a classic BSP application).
        RETURN.
    ENDTRY.

    LOOP AT paths INTO DATA(path).
      TRY.
          CLEAR content.
          repository->get_file( EXPORTING iv_path         = path
                                          iv_newline_chars = cl_abap_char_utilities=>cr_lf
                                IMPORTING ev_file_content = content ).
          APPEND VALUE #( name = path lines = as_lines( cl_abap_codepage=>convert_from( content ) ) ) TO result.
        CATCH cx_root.
          " A file that cannot be read is left out, as if it were missing.
          CONTINUE.
      ENDTRY.
    ENDLOOP.

    " The translations SE63 keeps for the files without language.
    TRY.
        DATA(texts) = /ui5/cl_ui5_rep_texts_rt=>/ui5/if_ui5_rep_texts_rt~get_api( iv_name = CONV string( application ) ).
      CATCH cx_root.
        RETURN.
    ENDTRY.
    LOOP AT paths INTO path.
      DATA(name) = split_file_name( path ).
      IF name-bundle IS INITIAL OR name-suffix IS NOT INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR codes.
      texts->get_all_lang_codes_for_prop( EXPORTING iv_prop_file_path = path
                                          IMPORTING et_language_codes = codes ).
      LOOP AT codes INTO DATA(code).
        DATA(language_file) = |{ name-bundle }_{ condense( CONV string( code ) ) }{ file_extension }|.
        TRY.
            CLEAR text.
            texts->get_prop_texts_4_lang( EXPORTING iv_path         = language_file
                                          IMPORTING ev_prop_content = text ).
          CATCH cx_root.
            CONTINUE.
        ENDTRY.
        IF text IS NOT INITIAL.
          APPEND VALUE #( name = language_file lines = as_lines( text ) in_se63 = abap_true ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD file_paths.
    " The .properties files of the app, in every folder. A name with a dot
    " in its last part is a file; the others are asked whether they are
    " folders, so that a large app does not cost a call per file.
    LOOP AT repository->get_folder_children( folder ) INTO DATA(child).
      DATA(last_part) = COND string( WHEN child CA '/' THEN substring_after( val = child sub = `/` occ = -1 )
                                     ELSE child ).
      IF last_part CA '.'.
        IF to_lower( child ) CP |*{ file_extension }|.
          APPEND child TO result.
        ENDIF.
      ELSEIF repository->check_is_folder( child ) = abap_true.
        APPEND LINES OF file_paths( repository = repository folder = child ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD as_lines.
    DATA(normalized) = replace( val = text sub = cl_abap_char_utilities=>cr_lf with = cl_abap_char_utilities=>newline occ = 0 ).
    SPLIT normalized AT cl_abap_char_utilities=>newline INTO TABLE result.
  ENDMETHOD.


  METHOD check_files.
    TYPES:
      BEGIN OF ty_named,
        bundle  TYPE string,
        suffix  TYPE string,
        lines   TYPE string_table,
        in_se63 TYPE abap_bool,
      END OF ty_named.
    DATA named       TYPE STANDARD TABLE OF ty_named WITH DEFAULT KEY.
    DATA bundles     TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    DATA translated  TYPE ty_properties.
    DATA file_suffix TYPE string.

    LOOP AT files INTO DATA(file).
      DATA(name) = split_file_name( file-name ).
      IF name-bundle IS INITIAL.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( bundle = name-bundle suffix = name-suffix lines = file-lines in_se63 = file-in_se63 ) TO named.
      INSERT name-bundle INTO TABLE bundles.
    ENDLOOP.

    LOOP AT bundles INTO DATA(bundle).
      " The text of the original language: the file without language, or
      " else the file of the original language. Never a text of SE63.
      DATA(reference) = VALUE ty_named( named[ bundle = bundle suffix = `` in_se63 = abap_false ] OPTIONAL ).
      IF reference IS INITIAL.
        LOOP AT named INTO DATA(candidate) WHERE bundle = bundle AND in_se63 = abap_false.
          IF is_file_of_language( suffix = candidate-suffix language = original_language ) = abap_true.
            reference = candidate.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.
      IF reference IS INITIAL.
        " No text of the original language: nothing to compare with.
        CONTINUE.
      ENDIF.
      DATA(source) = parse( reference-lines ).
      DELETE source WHERE value IS INITIAL.
      IF source IS INITIAL.
        " Only comments or empty texts: nothing to translate.
        CONTINUE.
      ENDIF.

      LOOP AT languages INTO DATA(language).
        " The file without language is the text of the original language.
        IF language = original_language.
          CONTINUE.
        ENDIF.
        " Every text of the language, from its file and from SE63: a key
        " is translated when one of them has a text for it.
        CLEAR: translated, file_suffix.
        DATA(found) = abap_false.
        LOOP AT named INTO candidate WHERE bundle = bundle AND suffix IS NOT INITIAL.
          IF is_file_of_language( suffix = candidate-suffix language = language ) = abap_false.
            CONTINUE.
          ENDIF.
          found = abap_true.
          IF candidate-in_se63 = abap_false.
            file_suffix = candidate-suffix.
          ENDIF.
          LOOP AT parse( candidate-lines ) INTO DATA(translation) WHERE value IS NOT INITIAL.
            INSERT translation INTO TABLE translated.
          ENDLOOP.
        ENDLOOP.
        DATA(suffixes) = suffixes_of( language ).
        IF file_suffix IS INITIAL AND suffixes IS NOT INITIAL.
          file_suffix = suffixes[ 1 ].
        ENDIF.
        DATA(finding) = VALUE ty_finding( application = application devclass = devclass
                                          file = |{ bundle }_{ file_suffix }{ file_extension }|
                                          language = language source_language = original_language ).

        IF found = abap_false.
          finding-problem     = problem-file_missing.
          finding-source_text = |{ lines( source ) } text(s) to translate|.
          APPEND finding TO result.
          CONTINUE.
        ENDIF.

        LOOP AT source INTO DATA(property).
          IF NOT line_exists( translated[ key = property-key ] ).
            finding-problem     = problem-text_missing.
            finding-text_key    = property-key.
            finding-source_text = property-value.
            APPEND finding TO result.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD parse.
    DATA logical TYPE string.
    DATA property_key   TYPE string.
    DATA property_value TYPE string.
    DATA comment TYPE string.

    DATA(index) = 0.
    WHILE index < lines( lines ).
      index = index + 1.
      DATA(line) = trim( lines[ index ] ).
      IF line IS INITIAL.
        CONTINUE.
      ENDIF.
      " # and ! start a comment (# is the escape character of CP, so no CP).
      " The last comment before a key says its text type.
      IF substring( val = line len = 1 ) CA '#!'.
        comment = line.
        CONTINUE.
      ENDIF.
      logical = line.
      " A line that ends with a backslash goes on in the next line.
      WHILE logical CP '*\' AND index < lines( lines ).
        index = index + 1.
        logical = substring( val = logical len = strlen( logical ) - 1 ) && trim( lines[ index ] ).
      ENDWHILE.

      " The key ends at the first = or :; blanks around it do not count.
      DATA(separator) = find_any_of( val = logical sub = `=:` ).
      IF separator >= 0.
        property_key   = trim( substring( val = logical len = separator ) ).
        property_value = trim( substring( val = logical off = separator + 1 ) ).
      ELSE.
        property_key   = logical.
        property_value = ``.
      ENDIF.
      IF property_key IS NOT INITIAL AND is_no_translation( comment ) = abap_false.
        " As in Java, a key that comes again replaces the earlier text.
        DELETE result WHERE key = property_key.
        INSERT VALUE #( key = property_key value = property_value ) INTO TABLE result.
      ENDIF.
      CLEAR comment.
    ENDWHILE.
  ENDMETHOD.


  METHOD trim.
    DATA(blanks) = | { cl_abap_char_utilities=>horizontal_tab }|.
    result = text.
    DATA(start) = find_any_not_of( val = result sub = blanks ).
    IF start < 0.
      CLEAR result.
      RETURN.
    ENDIF.
    DATA(last) = find_any_not_of( val = result sub = blanks occ = -1 ).
    result = substring( val = result off = start len = last - start + 1 ).
  ENDMETHOD.


  METHOD is_no_translation.
    " #NOTR: ..., # NOTR, #NOTR,10: the text type is the first word.
    DATA(type) = to_upper( trim( substring( val = comment off = nmin( val1 = 1 val2 = strlen( comment ) ) ) ) ).
    result = xsdbool( type CP |{ no_translation }*| AND
                      ( strlen( type ) = strlen( no_translation ) OR
                        substring( val = type off = strlen( no_translation ) len = 1 ) CA ':, ' ) ).
  ENDMETHOD.


  METHOD is_language_code.
    DATA codes TYPE STANDARD TABLE OF laiso WITH DEFAULT KEY.

    IF language_codes IS INITIAL.
      SELECT laiso FROM t002 INTO TABLE codes.
      LOOP AT codes INTO DATA(laiso) WHERE table_line IS NOT INITIAL.
        INSERT to_lower( condense( CONV string( laiso ) ) ) INTO TABLE language_codes.
      ENDLOOP.
      " Old codes that UI5 still uses: Hebrew, Indonesian.
      INSERT `iw` INTO TABLE language_codes.
      INSERT `in` INTO TABLE language_codes.
    ENDIF.
    result = xsdbool( line_exists( language_codes[ table_line = code ] ) ).
  ENDMETHOD.


  METHOD split_file_name.
    DATA parts TYPE string_table.

    DATA(length) = strlen( name ) - strlen( file_extension ).
    IF length <= 0 OR to_lower( substring( val = name off = length ) ) <> file_extension.
      RETURN.
    ENDIF.
    DATA(without_extension) = substring( val = name len = length ).
    " The folder stays with the bundle; only the file name has a language.
    DATA(slash) = find( val = without_extension sub = `/` occ = -1 ).
    DATA(folder) = COND string( WHEN slash >= 0 THEN substring( val = without_extension len = slash + 1 ) ).
    DATA(file) = COND string( WHEN slash >= 0 THEN substring( val = without_extension off = slash + 1 )
                              ELSE without_extension ).

    " The language starts at the first part of two or three small letters
    " after the bundle name: i18n_de, messagebundle_zh_TW.
    SPLIT file AT `_` INTO TABLE parts.
    DATA(language_part) = 0.
    LOOP AT parts INTO DATA(part) FROM 2.
      IF strlen( part ) BETWEEN 2 AND 3 AND part CO lowercase AND is_language_code( part ) = abap_true.
        language_part = sy-tabix.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF language_part = 0.
      result-bundle = |{ folder }{ file }|.
      RETURN.
    ENDIF.
    DATA(bundle_parts) = VALUE string_table( FOR i = 1 UNTIL i >= language_part ( parts[ i ] ) ).
    DATA(suffix_parts) = VALUE string_table( FOR i = language_part UNTIL i > lines( parts ) ( parts[ i ] ) ).
    result-bundle = |{ folder }{ concat_lines_of( table = bundle_parts sep = `_` ) }|.
    result-suffix = concat_lines_of( table = suffix_parts sep = `_` ).
  ENDMETHOD.


  METHOD is_file_of_language.
    LOOP AT suffixes_of( language ) INTO DATA(expected).
      IF suffix = expected.
        result = abap_true.
        RETURN.
      ENDIF.
      " A region after the language: de_DE, en_US. Not a variant such as
      " en_US_sappsd (pseudo language for tests), and not for Chinese,
      " where the region is the script: zh_TW is not Chinese (simplified).
      DATA(region) = substring_after( val = suffix sub = |{ expected }_| ).
      IF suffix CP |{ expected }_*| AND strlen( region ) = 2 AND region CO uppercase AND
         NOT expected CA `_` AND language <> chinese_simplified.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD suffixes_of.
    DATA code TYPE laiso.

    " The two Chinese languages of SAP are scripts of one ISO language,
    " and UI5 knows Hebrew under its old code iw as well.
    CASE language.
      WHEN chinese_simplified.
        result = VALUE #( ( `zh_CN` ) ( `zh` ) ).
        RETURN.
      WHEN chinese_traditional.
        result = VALUE #( ( `zh_TW` ) ).
        RETURN.
      WHEN hebrew.
        result = VALUE #( ( `he` ) ( `iw` ) ).
        RETURN.
      WHEN indonesian.
        result = VALUE #( ( `id` ) ( `in` ) ).
        RETURN.
    ENDCASE.
    SELECT SINGLE laiso FROM t002 INTO code WHERE spras = language.
    IF sy-subrc = 0 AND code IS NOT INITIAL.
      result = VALUE #( ( to_lower( condense( CONV string( code ) ) ) ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
