"! Translation check: finds texts of repository objects that have no
"! translation in the languages the project works in.
"!
"! The texts are read with the engine of SE63 (LXE): every object is
"! expanded into its translation objects (LXE_OBJ_EXPAND_TRANSPORT_OBJ),
"! and each of them is read as pairs of source and target text
"! (LXE_OBJ_TEXT_PAIR_READ). So every kind of text is covered the same
"! way: data elements, domains, tables, messages, text pools, GUI
"! status, OTR, Web Dynpro configurations, transactions, documentation.
"!
"! Settings, written by report ZTR_SETUP (STVARV):
"!   ZTR_TRANSL_LANGUAGES  select option, the required languages (EQ)
"!   ZTR_TRANSL_MODE       parameter, OFF (default), INFORM or BLOCK
"!   ZTR_TRANSL_EXCLUDE    select option, object names never checked
"! Only objects of the packages under Git are checked (STVARV
"! ZTR_PACKAGES, method PACKAGES of ZCL_TR_AUTH).
"!
"! A text that is missing in a required language is a finding of status
"! MISSING. A translation that is the same as the source text is only
"! reported (SAME_AS_SOURCE): product terms such as "Customizing" stay
"! English in German on purpose.
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_check DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_languages TYPE STANDARD TABLE OF spras WITH DEFAULT KEY.
    TYPES ty_name_range TYPE RANGE OF trobj_name.
    TYPES:
      BEGIN OF ty_object,
        object   TYPE trobjtype,
        obj_name TYPE trobj_name,
      END OF ty_object.
    TYPES ty_objects TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY object obj_name.
    TYPES:
      BEGIN OF ty_finding,
        object          TYPE trobjtype,
        obj_name        TYPE trobj_name,
        devclass        TYPE devclass,
        lxe_type        TYPE lxeobjtype,
        lxe_name        TYPE lxeobjname,
        text_kind       TYPE c LENGTH 40,
        text_key        TYPE lxetextkey,
        language        TYPE spras,
        source_language TYPE spras,
        source_text     TYPE lxeunitlin,
        target_text     TYPE lxeunitlin,
        status          TYPE c LENGTH 1,
        " What writing the translation back needs.
        custmnr         TYPE lxecustmnr,
        source_iso      TYPE lxeisolang,
        max_length      TYPE lxeunitmlt,
      END OF ty_finding.
    TYPES ty_findings TYPE STANDARD TABLE OF ty_finding WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_write_result,
        written  TYPE i,
        failed   TYPE i,
        messages TYPE string_table,
      END OF ty_write_result.

    CONSTANTS:
      BEGIN OF status,
        missing        TYPE c LENGTH 1 VALUE 'M',
        same_as_source TYPE c LENGTH 1 VALUE 'S',
        not_readable   TYPE c LENGTH 1 VALUE 'R',
      END OF status.
    CONSTANTS:
      BEGIN OF mode,
        off    TYPE string VALUE `OFF`,
        inform TYPE string VALUE `INFORM`,
        block  TYPE string VALUE `BLOCK`,
      END OF mode.
    CONSTANTS:
      BEGIN OF parameter_name,
        languages TYPE rvari_vnam VALUE 'ZTR_TRANSL_LANGUAGES',
        mode      TYPE rvari_vnam VALUE 'ZTR_TRANSL_MODE',
        exclude   TYPE rvari_vnam VALUE 'ZTR_TRANSL_EXCLUDE',
        record    TYPE rvari_vnam VALUE 'ZTR_TRANSL_RECORD',
      END OF parameter_name.
    " In the short text of a request: release it without the check.
    CONSTANTS skip_marker TYPE string VALUE `#NOTRANSL`.
    " In the short text of a request: a delivery to customers. A missing
    " translation always refuses its release, without "Translate now".
    CONSTANTS delivery_marker TYPE string VALUE `#DELIVERY`.
    CONSTANTS report_name TYPE progname VALUE 'ZTR_TRANSL_REPORT'.

    "! The required languages of this system, from STVARV.
    CLASS-METHODS configured_languages
      RETURNING
        VALUE(result) TYPE ty_languages.
    "! OFF, INFORM or BLOCK, from STVARV. OFF when nothing is stored.
    CLASS-METHODS configured_mode
      RETURNING
        VALUE(result) TYPE string.
    "! Object names that are never checked, from STVARV.
    "! Where a text appears, in plain words for the translator: "Message",
    "! "Selection screen field label", ... The text pool (RPT*) is split by
    "! the first character of the text key: I text symbol, S selection
    "! text, R title, H list heading.
    CLASS-METHODS text_kind
      IMPORTING
        lxe_type      TYPE lxeobjtype
        text_key      TYPE csequence
      RETURNING
        VALUE(result) TYPE string.
    "! True for a transport entry that carries code and no texts: LIMU
    "! REPS, METH, CPRI, CPUB, CPRO, CINC, CLSD, CDEF, FUNC, INTD.
    CLASS-METHODS is_code_part
      IMPORTING
        pgmid         TYPE pgmid
        object        TYPE trobjtype
      RETURNING
        VALUE(result) TYPE abap_bool.
    "! The main program of a program, class or function group, whose text
    "! pool holds its text elements: ZREPORT, ZCL_X=====CP, SAPLZFOO,
    "! /MYNS/SAPLAUTH. Empty for other object types.
    CLASS-METHODS main_program
      IMPORTING
        object        TYPE ty_object
      RETURNING
        VALUE(result) TYPE progname.
    "! True when the release check records the translations of the
    "! released objects in the task (STVARV ZTR_TRANSL_RECORD = X).
    CLASS-METHODS configured_record
      RETURNING
        VALUE(result) TYPE abap_bool.
    CLASS-METHODS configured_exclusions
      RETURNING
        VALUE(result) TYPE ty_name_range.
    "! Number of findings of the given status.
    CLASS-METHODS count
      IMPORTING
        findings      TYPE ty_findings
        status        TYPE c
      RETURNING
        VALUE(result) TYPE i.
    "! Text of a status, for lists and messages.
    CLASS-METHODS status_text
      IMPORTING
        status        TYPE c
      RETURNING
        VALUE(result) TYPE string.
    "! Two-letter code of a language as the user knows it: EN, DE.
    CLASS-METHODS language_code
      IMPORTING
        language      TYPE spras
      RETURNING
        VALUE(result) TYPE string.
    "! Characters by which a translation is longer than the maximum
    "! length of its text; 0 when it fits or the text has no limit.
    "! @parameter max_length | per text, as SE63 returns it (0 = no limit)
    CLASS-METHODS exceeded_by
      IMPORTING
        text          TYPE csequence
        max_length    TYPE lxeunitmlt
      RETURNING
        VALUE(result) TYPE i.
    "! "OK" or "Too long by N" for a translation, empty for no translation.
    CLASS-METHODS length_status
      IMPORTING
        text          TYPE csequence
        max_length    TYPE lxeunitmlt
      RETURNING
        VALUE(result) TYPE string.
    "! True for the SE63 object types whose texts the user sees when the
    "! product runs: messages, text elements, GUI status, screen texts,
    "! field labels, fixed values, transactions, OTR, F1 help. False for
    "! texts that only developers see: descriptions of classes, methods,
    "! interfaces, function modules, tables, domains, packages.
    CLASS-METHODS is_runtime_type
      IMPORTING
        lxe_type      TYPE lxeobjtype
      RETURNING
        VALUE(result) TYPE abap_bool.

    "! @parameter languages | the required languages; empty = the configured ones
    "! @parameter exclusions | object names to skip; empty = the configured ones
    "! @parameter package_pattern | packages in scope; empty = the packages under Git
    "! @parameter all_texts | also the texts only developers see (descriptions)
    METHODS constructor
      IMPORTING
        languages       TYPE ty_languages OPTIONAL
        exclusions      TYPE ty_name_range OPTIONAL
        package_pattern TYPE devclass OPTIONAL
        all_texts       TYPE abap_bool DEFAULT abap_false.
    "! The objects of a task or request (E071), as the release check gets them.
    METHODS check_transport_objects
      IMPORTING
        objects       TYPE tr_objects
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! Every object of a released or open task or request, with its tasks.
    METHODS check_transport
      IMPORTING
        transport     TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! Every object of the packages that match the pattern.
    METHODS check_packages
      IMPORTING
        package_pattern TYPE devclass
      RETURNING
        VALUE(result)   TYPE ty_findings.
    "! Every object whose name starts with the namespace, e.g. /MYNS/,
    "! in whatever package it is, except local packages ($...).
    METHODS check_namespace
      IMPORTING
        namespace     TYPE namespace
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! Records in a task the translations of the text elements (text
    "! pool) of the programs and classes whose code parts it holds, as the
    "! LANG entries SE63 makes. A task that holds only code (LIMU METH,
    "! REPS, CPRI, FUNC, ...) does not carry the text pool; every other
    "! entry carries its texts in all languages itself (R3TR objects,
    "! LIMU REPT, MESS, DYNP, CUAD), so nothing else is recorded. Not
    "! recorded either: an object whose text pool or whole object is in
    "! another open request (a message names it), so that no text of a
    "! change still in work is shipped early. Only translation objects
    "! with at least one translated text in a required language.
    "! WRITTEN counts the recorded translation objects and languages.
    "! @parameter objects | the objects of the task, as E071 holds them
    "! @parameter transport | the task to record in
    METHODS record_translations
      IMPORTING
        objects       TYPE tr_objects
        transport     TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_write_result.
    "! Writes translations as SE63 does and records them in a request.
    "! Only lines with a target text are written; the other texts of the
    "! same translation object keep their translation.
    "! @parameter translations | findings with the new text in TARGET_TEXT
    "! @parameter target | task or request the translations are recorded
    "!                     in; empty: written, but recorded nowhere
    METHODS write_translations
      IMPORTING
        translations  TYPE ty_findings
        target        TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_write_result.
    "! Repository objects (R3TR level).
    "! @parameter any_package | true: not only the packages in scope, any
    "!                          package except local ones ($...)
    METHODS check_objects
      IMPORTING
        objects       TYPE ty_objects
        any_package   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! The repository objects of a task or request and its tasks.
    METHODS transport_objects
      IMPORTING
        transport     TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_objects.
    "! The repository objects of the packages that match the pattern.
    METHODS package_objects
      IMPORTING
        package_pattern TYPE devclass
      RETURNING
        VALUE(result)   TYPE ty_objects.
    "! The repository objects whose name starts with the namespace.
    METHODS namespace_objects
      IMPORTING
        namespace     TYPE namespace
      RETURNING
        VALUE(result) TYPE ty_objects.
    "! The objects that are checked: not excluded, not local, and in the
    "! packages in scope (with ANY_PACKAGE: in any package that is not
    "! local). The same objects for the texts of SE63, the hardcoded texts
    "! and the text tables.
    METHODS objects_in_scope
      IMPORTING
        objects       TYPE ty_objects
        any_package   TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE ty_objects.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_language,
        r3  TYPE spras,
        iso TYPE lxeisolang,
      END OF ty_language.
    TYPES ty_language_map TYPE SORTED TABLE OF ty_language WITH UNIQUE KEY r3.
    TYPES ty_pairs TYPE STANDARD TABLE OF lxe_pcx_s1 WITH DEFAULT KEY.
    TYPES ty_collection TYPE STANDARD TABLE OF lxe_colob WITH DEFAULT KEY.

    DATA languages       TYPE ty_language_map.
    DATA exclusions      TYPE ty_name_range.
    DATA package_pattern TYPE devclass.
    DATA all_texts       TYPE abap_bool.

    CLASS-METHODS select_option
      IMPORTING
        name          TYPE rvari_vnam
      RETURNING
        VALUE(result) TYPE ty_name_range.
    CLASS-METHODS like_pattern
      IMPORTING
        pattern       TYPE devclass
      RETURNING
        VALUE(result) TYPE devclass.

    METHODS main_objects
      IMPORTING
        objects       TYPE tr_objects
      RETURNING
        VALUE(result) TYPE ty_objects.
    METHODS package_of
      IMPORTING
        object        TYPE ty_object
      RETURNING
        VALUE(result) TYPE devclass.
    METHODS check_object
      IMPORTING
        object   TYPE ty_object
        devclass TYPE devclass
      CHANGING
        findings TYPE ty_findings.
    METHODS main_object
      IMPORTING
        entry         TYPE e071
      RETURNING
        VALUE(result) TYPE ty_object.
    "! The open request (other than the one of TRANSPORT and its tasks)
    "! that holds the object or its text pool; empty when there is none.
    METHODS other_open_request
      IMPORTING
        object        TYPE ty_object
        transport     TYPE trkorr
      RETURNING
        VALUE(result) TYPE trkorr.
    "! Appends transport entries to a task or request; returns the reason
    "! when that fails, empty when it worked.
    METHODS append_to_request
      IMPORTING
        target        TYPE trkorr
        e071          TYPE tr_objects
        e071k         TYPE tr_keys
      RETURNING
        VALUE(result) TYPE string.
    METHODS r3_language
      IMPORTING
        iso           TYPE lxeisolang
      RETURNING
        VALUE(result) TYPE spras.
ENDCLASS.



CLASS zcl_tr_transl_check IMPLEMENTATION.


  METHOD configured_languages.
    LOOP AT select_option( parameter_name-languages ) INTO DATA(entry)
         WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      DATA(language) = CONV spras( entry-low ).
      IF NOT line_exists( result[ table_line = language ] ).
        APPEND language TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD configured_mode.
    SELECT SINGLE low FROM tvarvc
      INTO @DATA(value)
      WHERE name = @parameter_name-mode
        AND type = 'P'
        AND numb = '0000'.
    result = to_upper( condense( CONV string( value ) ) ).
    IF result <> mode-inform AND result <> mode-block.
      result = mode-off.
    ENDIF.
  ENDMETHOD.


  METHOD text_kind.
    DATA(type) = CONV string( lxe_type ).
    IF strlen( type ) = 4 AND type CP 'RPT+'.
      DATA(id) = COND string( WHEN strlen( text_key ) > 0 THEN substring( val = text_key len = 1 ) ELSE `` ).
      result = SWITCH #( id
        WHEN 'I' THEN `Text in a program (text symbol)`
        WHEN 'S' THEN `Selection screen field label`
        WHEN 'R' THEN `Program title`
        WHEN 'H' THEN `List heading`
        ELSE `Text element of a program` ).
      RETURN.
    ENDIF.
    IF strlen( type ) = 4 AND type CP 'SRT+'.
      result = `Screen text (label, frame, button)`.
      RETURN.
    ENDIF.
    IF strlen( type ) = 3 AND type CP 'CA+' AND substring( val = type off = 2 len = 1 ) CO '0123456789'.
      result = `Menu, button or title (GUI status)`.
      RETURN.
    ENDIF.
    result = SWITCH #( type
      WHEN 'MESS' THEN `Message (status bar or popup)`
      WHEN 'DTEL' THEN `Field label (screen, table column)`
      WHEN 'DE'   THEN `F1 help of a field`
      WHEN 'DT'   THEN `Dialog text (popup)`
      WHEN 'VALU' THEN `Value in a dropdown list`
      WHEN 'TRAN' THEN `Transaction name (menu, launchpad tile)`
      WHEN 'SOTR' OR 'LOTR' THEN `Web or UI text (OTR)`
      WHEN 'TOBJ' THEN `Title of a maintenance view (SM30)`
      WHEN 'WDYN' OR 'WD' OR 'WC' OR 'VW' THEN `Web Dynpro screen text`
      ELSE |Other (SE63 type { type })| ).
  ENDMETHOD.


  METHOD is_code_part.
    result = xsdbool( pgmid = 'LIMU' AND
                      ( object = 'REPS' OR object = 'METH' OR object = 'CPRI' OR object = 'CPUB' OR
                        object = 'CPRO' OR object = 'CINC' OR object = 'CLSD' OR object = 'CDEF' OR
                        object = 'FUNC' OR object = 'INTD' ) ).
  ENDMETHOD.


  METHOD main_program.
    CASE object-object.
      WHEN 'PROG'.
        result = object-obj_name.
      WHEN 'CLAS'.
        result = cl_oo_classname_service=>get_classpool_name( CONV seoclsname( object-obj_name ) ).
      WHEN 'FUGR'.
        " /MYNS/AUTH -> /MYNS/SAPLAUTH, ZFOO -> SAPLZFOO.
        IF object-obj_name(1) <> '/'.
          result = |SAPL{ object-obj_name }|.
          RETURN.
        ENDIF.
        DATA(rest) = substring( val = object-obj_name off = 1 ).
        IF rest CS '/'.
          DATA(namespace) = |/{ substring_before( val = rest sub = `/` ) }/|.
          result = |{ namespace }SAPL{ substring( val = object-obj_name off = strlen( namespace ) ) }|.
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD configured_record.
    SELECT SINGLE low FROM tvarvc
      INTO @DATA(value)
      WHERE name = @parameter_name-record
        AND type = 'P'
        AND numb = '0000'.
    result = xsdbool( sy-subrc = 0 AND value = abap_true ).
  ENDMETHOD.


  METHOD configured_exclusions.
    result = select_option( parameter_name-exclude ).
  ENDMETHOD.


  METHOD select_option.
    SELECT numb, sign, opti, low, high FROM tvarvc
      INTO TABLE @DATA(rows)
      WHERE name = @name
        AND type = 'S'
      ORDER BY numb.
    LOOP AT rows INTO DATA(row) WHERE sign IS NOT INITIAL AND opti IS NOT INITIAL.
      APPEND VALUE #( sign = row-sign option = row-opti low = row-low high = row-high ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD count.
    LOOP AT findings TRANSPORTING NO FIELDS WHERE status = status.
      result = result + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD status_text.
    CASE status.
      WHEN zcl_tr_transl_check=>status-missing.
        result = `missing`.
      WHEN zcl_tr_transl_check=>status-same_as_source.
        result = `same as source`.
      WHEN zcl_tr_transl_check=>status-not_readable.
        result = `not readable`.
    ENDCASE.
  ENDMETHOD.


  METHOD language_code.
    DATA code TYPE laiso.
    CALL FUNCTION 'CONVERSION_EXIT_ISOLA_OUTPUT'
      EXPORTING
        input  = language
      IMPORTING
        output = code.
    result = COND #( WHEN code IS INITIAL THEN language ELSE code ).
  ENDMETHOD.


  METHOD exceeded_by.
    " Counted in characters, as Excel's LEN in the downloaded file does.
    IF max_length <= 0.
      RETURN.
    ENDIF.
    result = nmax( val1 = strlen( text ) - max_length val2 = 0 ).
  ENDMETHOD.


  METHOD length_status.
    IF text IS INITIAL.
      RETURN.
    ENDIF.
    DATA(excess) = exceeded_by( text = text max_length = max_length ).
    result = COND #( WHEN excess = 0 THEN `OK` ELSE |Too long by { excess }| ).
  ENDMETHOD.


  METHOD is_runtime_type.
    " SE63 object types (table LXE_ATTOB, texts in LXE_ATTOBT).
    "   MESS          messages
    "   RPT1 .. RPT8  text elements: text symbols, selection texts, titles
    "   CA1 .. CA7    GUI status and titles (CA alone: class attributes)
    "   SRT1 .. SRT8  screen texts (SRH: screen descriptions, not shown)
    "   DTEL          field labels of data elements (screens, ALV)
    "   DE            F1 help of data elements
    "   DT            dialog texts (popups)
    "   VALU          fixed values of domains (dropdowns)
    "   TRAN          transaction texts (menu, Fiori launchpad)
    "   SOTR, LOTR    OTR short and long texts
    "   TOBJ          maintenance dialogs (SM30 title)
    "   WDYN WD WC VW Web Dynpro and its configurations
    CASE lxe_type.
      WHEN 'MESS' OR 'DTEL' OR 'DE' OR 'DT' OR 'VALU' OR 'TRAN' OR 'SOTR' OR 'LOTR' OR 'TOBJ' OR
           'WDYN' OR 'WD' OR 'WC' OR 'VW'.
        result = abap_true.
      WHEN OTHERS.
        result = xsdbool( strlen( lxe_type ) = 4 AND ( lxe_type CP 'RPT+' OR lxe_type CP 'SRT+' ) OR
                          strlen( lxe_type ) = 3 AND lxe_type CP 'CA+' AND lxe_type+2(1) CO '0123456789' ).
    ENDCASE.
  ENDMETHOD.


  METHOD like_pattern.
    " CP pattern of STVARV (/MYNS/*) as LIKE pattern for Open SQL.
    result = pattern.
    REPLACE ALL OCCURRENCES OF '*' IN result WITH '%'.
    REPLACE ALL OCCURRENCES OF '+' IN result WITH '_'.
  ENDMETHOD.


  METHOD constructor.
    DATA(required) = languages.
    IF required IS INITIAL.
      required = configured_languages( ).
    ENDIF.
    LOOP AT required INTO DATA(language).
      DATA(iso) = VALUE lxeisolang( ).
      CALL FUNCTION 'LXE_T002_CHECK_LANGUAGE'
        EXPORTING
          r3_lang            = language
        IMPORTING
          o_language         = iso
        EXCEPTIONS
          language_not_in_cp = 1
          unknown            = 2
          OTHERS             = 3.
      IF sy-subrc = 0 AND iso IS NOT INITIAL.
        INSERT VALUE #( r3 = language iso = iso ) INTO TABLE me->languages.
      ENDIF.
    ENDLOOP.

    me->exclusions = COND #( WHEN exclusions IS INITIAL THEN configured_exclusions( ) ELSE exclusions ).
    me->package_pattern = COND #( WHEN package_pattern IS INITIAL THEN zcl_tr_auth=>packages( ) ELSE package_pattern ).
    me->all_texts = all_texts.
  ENDMETHOD.


  METHOD check_transport_objects.
    result = check_objects( main_objects( objects ) ).
  ENDMETHOD.


  METHOD check_transport.
    result = check_objects( transport_objects( transport ) ).
  ENDMETHOD.


  METHOD transport_objects.
    " The request and all its tasks, or the task alone.
    SELECT trkorr FROM e070
      INTO TABLE @DATA(transports)
      WHERE trkorr = @transport
         OR strkorr = @transport.
    IF transports IS INITIAL.
      RETURN.
    ENDIF.
    SELECT pgmid, object, obj_name FROM e071
      INTO TABLE @DATA(entries)
      FOR ALL ENTRIES IN @transports
      WHERE trkorr = @transports-trkorr.
    DATA(objects) = VALUE tr_objects( ).
    LOOP AT entries INTO DATA(entry).
      APPEND VALUE #( pgmid = entry-pgmid object = entry-object obj_name = entry-obj_name ) TO objects.
    ENDLOOP.
    result = main_objects( objects ).
  ENDMETHOD.


  METHOD check_packages.
    result = check_objects( package_objects( package_pattern ) ).
  ENDMETHOD.


  METHOD package_objects.
    DATA(pattern) = like_pattern( package_pattern ).
    SELECT object, obj_name FROM tadir
      INTO TABLE @DATA(entries)
      WHERE pgmid    = 'R3TR'
        AND devclass LIKE @pattern
        AND delflag  = @space.
    LOOP AT entries INTO DATA(entry).
      INSERT VALUE #( object = entry-object obj_name = entry-obj_name ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_namespace.
    result = check_objects( objects = namespace_objects( namespace ) any_package = abap_true ).
  ENDMETHOD.


  METHOD namespace_objects.
    DATA(pattern) = |{ namespace }%|.
    SELECT object, obj_name FROM tadir
      INTO TABLE @DATA(entries)
      WHERE pgmid    = 'R3TR'
        AND obj_name LIKE @pattern
        AND delflag  = @space.
    LOOP AT entries INTO DATA(entry).
      INSERT VALUE #( object = entry-object obj_name = entry-obj_name ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_objects.
    IF languages IS INITIAL.
      RETURN.
    ENDIF.
    DATA(in_scope) = objects_in_scope( objects = objects any_package = any_package ).
    LOOP AT in_scope INTO DATA(object).
      check_object(
        EXPORTING
          object   = object
          devclass = package_of( object )
        CHANGING
          findings = result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD objects_in_scope.
    LOOP AT objects INTO DATA(object).
      IF exclusions IS NOT INITIAL AND object-obj_name IN exclusions.
        CONTINUE.
      ENDIF.
      DATA(devclass) = package_of( object ).
      " Only objects of the packages under Git (or, for a namespace, of
      " any package that is not local): local objects, SAP objects and
      " objects of other products are not checked.
      IF devclass IS INITIAL OR devclass(1) = '$'.
        CONTINUE.
      ENDIF.
      IF any_package = abap_false AND devclass NP package_pattern.
        CONTINUE.
      ENDIF.
      INSERT object INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD main_objects.
    " LIMU entries (methods, includes, screens, ...) stand for their main
    " object; LANG entries (translations) for the object they translate.
    LOOP AT objects INTO DATA(entry).
      DATA(main) = main_object( CORRESPONDING #( entry ) ).
      IF main IS NOT INITIAL.
        INSERT main INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD main_object.
    DATA directory_entry TYPE tadir.

    CASE entry-pgmid.
      WHEN 'R3TR' OR 'LANG'.
        result = VALUE #( object = entry-object obj_name = entry-obj_name ).
      WHEN 'LIMU'.
        CALL FUNCTION 'TR_CHECK_TYPE'
          EXPORTING
            wi_e071  = entry
          IMPORTING
            we_tadir = directory_entry.
        IF directory_entry-object IS NOT INITIAL.
          result = VALUE #( object = directory_entry-object obj_name = directory_entry-obj_name ).
        ENDIF.
    ENDCASE.
  ENDMETHOD.


  METHOD package_of.
    SELECT SINGLE devclass FROM tadir
      INTO @result
      WHERE pgmid    = 'R3TR'
        AND object   = @object-object
        AND obj_name = @object-obj_name.
  ENDMETHOD.


  METHOD check_object.
    DATA collection TYPE ty_collection.
    DATA pairs      TYPE ty_pairs.
    DATA process    TYPE lxestatprc.

    CALL FUNCTION 'LXE_OBJ_EXPAND_TRANSPORT_OBJ'
      EXPORTING
        pgmid           = 'R3TR'
        object          = object-object
        obj_name        = object-obj_name
      TABLES
        ex_colob        = collection
      EXCEPTIONS
        unknown_object  = 1
        unknown_ta_type = 2
        OTHERS          = 3.
    IF sy-subrc <> 0.
      " An object type without texts for translation.
      RETURN.
    ENDIF.

    LOOP AT collection INTO DATA(part).
      " Descriptions that only developers see are not required, unless
      " asked for: development may be in English only.
      IF all_texts = abap_false AND is_runtime_type( part-objtype ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(source_language) = r3_language( part-orig_lang ).
      LOOP AT languages INTO DATA(language) WHERE iso <> part-orig_lang.
        CLEAR pairs.
        CALL FUNCTION 'LXE_OBJ_TEXT_PAIR_READ'
          EXPORTING
            t_lang    = language-iso
            s_lang    = part-orig_lang
            custmnr   = part-custmnr
            objtype   = part-objtype
            objname   = part-objname
            read_only = abap_true
          IMPORTING
            pstatus   = process
          TABLES
            lt_pcx_s1 = pairs.
        IF process = 'F'.
          APPEND VALUE #( object = object-object obj_name = object-obj_name devclass = devclass
                          lxe_type = part-objtype lxe_name = part-objname
                          text_kind = text_kind( lxe_type = part-objtype text_key = `` )
                          language = language-r3 source_language = source_language
                          status = status-not_readable ) TO findings.
          CONTINUE.
        ENDIF.
        LOOP AT pairs INTO DATA(pair) WHERE s_text IS NOT INITIAL.
          DATA(finding) = VALUE ty_finding(
            object = object-object obj_name = object-obj_name devclass = devclass
            lxe_type = part-objtype lxe_name = part-objname text_key = pair-textkey
            text_kind = text_kind( lxe_type = part-objtype text_key = pair-textkey )
            language = language-r3 source_language = source_language
            source_text = pair-s_text target_text = pair-t_text
            custmnr = part-custmnr source_iso = part-orig_lang max_length = pair-unitmlt ).
          IF pair-t_text IS INITIAL.
            finding-status = status-missing.
          ELSEIF pair-t_text = pair-s_text.
            finding-status = status-same_as_source.
          ELSE.
            CONTINUE.
          ENDIF.
          APPEND finding TO findings.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD write_translations.
    " One write per translation object and language, as SE63 does: the
    " current pairs are read, the new texts put in, and all written back.
    TYPES:
      BEGIN OF ty_group,
        custmnr    TYPE lxecustmnr,
        lxe_type   TYPE lxeobjtype,
        lxe_name   TYPE lxeobjname,
        language   TYPE spras,
        source_iso TYPE lxeisolang,
      END OF ty_group.
    DATA groups  TYPE SORTED TABLE OF ty_group WITH UNIQUE KEY custmnr lxe_type lxe_name language.
    DATA pairs   TYPE ty_pairs.
    DATA process TYPE lxestatprc.
    DATA e071    TYPE STANDARD TABLE OF e071 WITH DEFAULT KEY.
    DATA e071k   TYPE STANDARD TABLE OF e071k WITH DEFAULT KEY.

    LOOP AT translations INTO DATA(line) WHERE target_text IS NOT INITIAL.
      INSERT VALUE #( custmnr = line-custmnr lxe_type = line-lxe_type lxe_name = line-lxe_name
                      language = line-language source_iso = line-source_iso ) INTO TABLE groups.
    ENDLOOP.

    LOOP AT groups INTO DATA(group).
      DATA(target_iso) = VALUE lxeisolang( ).
      CALL FUNCTION 'LXE_T002_CHECK_LANGUAGE'
        EXPORTING
          r3_lang            = group-language
        IMPORTING
          o_language         = target_iso
        EXCEPTIONS
          language_not_in_cp = 1
          unknown            = 2
          OTHERS             = 3.
      IF sy-subrc <> 0 OR target_iso IS INITIAL.
        result-failed = result-failed + 1.
        APPEND |{ group-lxe_name }: language { group-language } is not known to SE63| TO result-messages.
        CONTINUE.
      ENDIF.

      " Read for writing, as SE63 does before it saves: the readers of
      " several types (messages, for example) remember the database rows
      " of the texts only then, and the writer needs them. Read only, the
      " writer refuses every text of such a type.
      CLEAR pairs.
      CALL FUNCTION 'LXE_OBJ_TEXT_PAIR_READ'
        EXPORTING
          t_lang    = target_iso
          s_lang    = group-source_iso
          custmnr   = group-custmnr
          objtype   = group-lxe_type
          objname   = group-lxe_name
          read_only = abap_false
        IMPORTING
          pstatus   = process
        TABLES
          lt_pcx_s1 = pairs.
      IF process = 'F'.
        result-failed = result-failed + 1.
        APPEND |{ group-lxe_type } { group-lxe_name } ({ group-language }): SE63 cannot read it| TO result-messages.
        CONTINUE.
      ENDIF.

      DATA(changed) = 0.
      LOOP AT translations INTO line
           WHERE custmnr = group-custmnr AND lxe_type = group-lxe_type AND lxe_name = group-lxe_name
             AND language = group-language AND target_text IS NOT INITIAL.
        READ TABLE pairs ASSIGNING FIELD-SYMBOL(<pair>) WITH KEY textkey = line-text_key.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF exceeded_by( text = line-target_text max_length = line-max_length ) > 0.
          result-failed = result-failed + 1.
          APPEND |{ condense( line-obj_name ) } ({ group-language }): "{ line-target_text }" is longer | &&
                 |than { line-max_length } characters, not written| TO result-messages.
          CONTINUE.
        ENDIF.
        <pair>-t_text = line-target_text.
        changed = changed + 1.
      ENDLOOP.
      IF changed = 0.
        CONTINUE.
      ENDIF.

      CALL FUNCTION 'LXE_OBJ_TEXT_PAIR_WRITE'
        EXPORTING
          t_lang    = target_iso
          s_lang    = group-source_iso
          custmnr   = group-custmnr
          objtype   = group-lxe_type
          objname   = group-lxe_name
        IMPORTING
          pstatus   = process
        TABLES
          lt_pcx_s1 = pairs.
      IF process <> 'S'.
        result-failed = result-failed + changed.
        APPEND |{ group-lxe_type } { group-lxe_name } ({ group-language }): SE63 did not write it| TO result-messages.
        CONTINUE.
      ENDIF.
      result-written = result-written + changed.

      " The transport entries of the translation (LANG), as SE63 makes
      " them, appended to the request.
      IF target IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR: e071, e071k.
      CALL FUNCTION 'LXE_OBJ_CREATE_TRANSPORT_SE63'
        EXPORTING
          language = group-language
          custmnr  = group-custmnr
          objtype  = group-lxe_type
          objname  = group-lxe_name
        IMPORTING
          pstatus  = process
        TABLES
          ex_e071  = e071
          ex_e071k = e071k.
      IF process <> 'S' OR e071 IS INITIAL.
        APPEND |{ group-lxe_type } { group-lxe_name } ({ group-language }): written, but no transport entry| TO result-messages.
        CONTINUE.
      ENDIF.
      DATA(reason) = append_to_request( target = target e071 = e071 e071k = e071k ).
      IF reason IS NOT INITIAL.
        APPEND |{ group-lxe_type } { group-lxe_name } ({ group-language }): written, not recorded in { target }: { reason }|
               TO result-messages.
      ENDIF.
    ENDLOOP.
    COMMIT WORK.
  ENDMETHOD.


  METHOD record_translations.
    DATA collection TYPE STANDARD TABLE OF lxe_colob WITH DEFAULT KEY.
    DATA pairs      TYPE ty_pairs.
    DATA process    TYPE lxestatprc.
    DATA part_e071  TYPE tr_objects.
    DATA part_e071k TYPE tr_keys.
    DATA e071       TYPE tr_objects.
    DATA e071k      TYPE tr_keys.
    DATA carried    TYPE ty_objects.
    DATA code_only  TYPE ty_objects.

    IF languages IS INITIAL OR transport IS INITIAL.
      RETURN.
    ENDIF.

    " Which objects the task holds only as code; which it carries with
    " their texts (the whole object, or its text pool).
    LOOP AT objects INTO DATA(entry).
      DATA(main) = main_object( CORRESPONDING #( entry ) ).
      IF main IS INITIAL.
        CONTINUE.
      ENDIF.
      IF is_code_part( pgmid = entry-pgmid object = entry-object ) = abap_true.
        INSERT main INTO TABLE code_only.
      ELSEIF entry-pgmid = 'R3TR' OR ( entry-pgmid = 'LIMU' AND entry-object = 'REPT' ).
        INSERT main INTO TABLE carried.
      ENDIF.
    ENDLOOP.
    LOOP AT carried INTO main.
      DELETE TABLE code_only FROM main.
    ENDLOOP.

    DATA(in_scope) = objects_in_scope( code_only ).
    LOOP AT in_scope INTO DATA(object).
      DATA(other) = other_open_request( object = object transport = transport ).
      IF other IS NOT INITIAL.
        APPEND |{ object-object } { condense( object-obj_name ) } is also in open request { other }: | &&
               |its text elements are not recorded| TO result-messages.
        CONTINUE.
      ENDIF.
      CLEAR collection.
      CALL FUNCTION 'LXE_OBJ_EXPAND_TRANSPORT_OBJ'
        EXPORTING
          pgmid           = 'R3TR'
          object          = object-object
          obj_name        = object-obj_name
        TABLES
          ex_colob        = collection
        EXCEPTIONS
          unknown_object  = 1
          unknown_ta_type = 2
          OTHERS          = 3.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      " Only the text pool (text symbols, selection texts, titles): the
      " other texts of the object travel with their own entries.
      LOOP AT collection INTO DATA(part) WHERE objtype CP 'RPT+'.
        LOOP AT languages INTO DATA(language) WHERE iso <> part-orig_lang.
          CLEAR pairs.
          CALL FUNCTION 'LXE_OBJ_TEXT_PAIR_READ'
            EXPORTING
              t_lang    = language-iso
              s_lang    = part-orig_lang
              custmnr   = part-custmnr
              objtype   = part-objtype
              objname   = part-objname
              read_only = abap_true
            IMPORTING
              pstatus   = process
            TABLES
              lt_pcx_s1 = pairs.
          IF process = 'F' OR pairs IS INITIAL.
            CONTINUE.
          ENDIF.
          " Nothing translated in this language: nothing to carry.
          LOOP AT pairs TRANSPORTING NO FIELDS WHERE t_text IS NOT INITIAL.
            EXIT.
          ENDLOOP.
          IF sy-subrc <> 0.
            CONTINUE.
          ENDIF.
          CLEAR: part_e071, part_e071k.
          CALL FUNCTION 'LXE_OBJ_CREATE_TRANSPORT_SE63'
            EXPORTING
              language = language-r3
              custmnr  = part-custmnr
              objtype  = part-objtype
              objname  = part-objname
            IMPORTING
              pstatus  = process
            TABLES
              ex_e071  = part_e071
              ex_e071k = part_e071k.
          IF process <> 'S' OR part_e071 IS INITIAL.
            APPEND |{ part-objtype } { part-objname } ({ language-r3 }): no transport entry| TO result-messages.
            result-failed = result-failed + 1.
            CONTINUE.
          ENDIF.
          APPEND LINES OF part_e071 TO e071.
          APPEND LINES OF part_e071k TO e071k.
          result-written = result-written + 1.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
    IF e071 IS INITIAL.
      RETURN.
    ENDIF.

    SORT e071 BY pgmid object obj_name lang.
    DELETE ADJACENT DUPLICATES FROM e071 COMPARING pgmid object obj_name lang.
    SORT e071k.
    DELETE ADJACENT DUPLICATES FROM e071k.
    DATA(reason) = append_to_request( target = transport e071 = e071 e071k = e071k ).
    IF reason IS NOT INITIAL.
      APPEND |Not recorded in { transport }: { reason }| TO result-messages.
      result-failed = result-failed + result-written.
      result-written = 0.
    ENDIF.
  ENDMETHOD.


  METHOD other_open_request.
    " The own request and all its tasks are one delivery: an entry there
    " is not "another" request.
    SELECT SINGLE strkorr FROM e070 INTO @DATA(parent) WHERE trkorr = @transport.
    DATA(own) = COND trkorr( WHEN parent IS NOT INITIAL THEN parent ELSE transport ).
    SELECT trkorr FROM e070
      INTO TABLE @DATA(family)
      WHERE trkorr = @own
         OR strkorr = @own.

    DATA(program) = CONV trobj_name( main_program( object ) ).
    SELECT e071~trkorr, e070~strkorr FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      INTO TABLE @DATA(holders)
      WHERE ( e070~trstatus = 'D' OR e070~trstatus = 'L' )
        AND ( ( e071~pgmid = 'R3TR' AND e071~object = @object-object AND e071~obj_name = @object-obj_name )
           OR ( e071~pgmid = 'LIMU' AND e071~object = 'REPT' AND e071~obj_name = @program ) ).
    LOOP AT holders INTO DATA(holder).
      IF line_exists( family[ trkorr = holder-trkorr ] ).
        CONTINUE.
      ENDIF.
      result = COND #( WHEN holder-strkorr IS NOT INITIAL THEN holder-strkorr ELSE holder-trkorr ).
      RETURN.
    ENDLOOP.
  ENDMETHOD.


  METHOD append_to_request.
    DATA entries TYPE tr_objects.
    DATA keys    TYPE tr_keys.

    entries = e071.
    keys = e071k.
    CALL FUNCTION 'TR_APPEND_TO_COMM_OBJS_KEYS'
      EXPORTING
        wi_trkorr = target
        iv_dialog = abap_false
      TABLES
        wt_e071   = entries
        wt_e071k  = keys
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO result.
      IF result IS INITIAL.
        result = `the transport organizer refused the entries`.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD r3_language.
    CALL FUNCTION 'LXE_T002_CHECK_LANGUAGE'
      EXPORTING
        language           = iso
      IMPORTING
        o_r3_lang          = result
      EXCEPTIONS
        language_not_in_cp = 1
        unknown            = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
