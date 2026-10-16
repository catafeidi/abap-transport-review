*----------------------------------------------------------------------*
* Class ZCL_TR_CONTENT_APPLY: the other direction of ZCL_TR_CONTENT.
*
* ZCL_TR_CONTENT writes what abapGit does not write (table rows,
* report variants, SAP Note entries) as JSON under content/. abapGit
* ignores that folder, so an abapGit pull does not bring it into a
* system. This class does: it compares every file of content/ with the
* system, reports the difference and, on request, applies it and records
* it in a workbench request, so that the change travels on from there
* like any other change (development -> quality -> production).
*
*   content/tables/<table>.json   rows of a table
*       Compared by key. A row of Git that the system does not have is
*       inserted; a row that differs is overwritten; a row only the system
*       has is reported and removed only on request. The client is never
*       part of a file, it is the logon client. Credential fields (see
*       ZCL_TR_CONTENT=>SECRET_FIELDS) are blank in Git: the system
*       keeps its own values, and a new row gets them blank.
*   content/variants/<report>.<variant>.json
*       Created or changed through the variant function modules when the
*       report exists on the system, as stored records when it does not.
*   content/notes/<entry>.json
*       Only reported: a note is implemented in SNOTE.
*
* Without writing nothing is changed. With writing, the keys of every
* table and every variant are recorded in the given request first; only
* if that works the rows are written, and one table or variant at a time
* is committed or rolled back.
*
* Create in SE24 as a local object, source-based editor, paste this file.
* Needs abapGit and ZCL_TR_CONTENT. ABAP 7.40.
*----------------------------------------------------------------------*
CLASS zcl_tr_content_apply DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    CONSTANTS:
      BEGIN OF kind,
        table   TYPE c LENGTH 1 VALUE 'T',
        variant TYPE c LENGTH 1 VALUE 'V',
        note    TYPE c LENGTH 1 VALUE 'N',
      END OF kind.
    TYPES:
      BEGIN OF ty_item,
        kind      TYPE c LENGTH 1,
        name      TYPE string,
        inserted  TYPE i,        " in Git, not in the system
        changed   TYPE i,        " in both, different
        unchanged TYPE i,
        missing   TYPE i,        " in the system, not in Git
        written   TYPE abap_bool,
        failed    TYPE abap_bool,
        message   TYPE string,
      END OF ty_item.
    TYPES ty_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

    " Rows of a table file against the rows of the system. TO_WRITE holds
    " the rows to insert or overwrite, ready to be written: client set,
    " credential fields of an existing row taken from the system.
    CLASS-METHODS compare_rows
      IMPORTING
        git_rows     TYPE STANDARD TABLE
        system_rows  TYPE STANDARD TABLE
        fields       TYPE zcl_tr_content=>ty_key_fields
        client_field TYPE fieldname
        secrets      TYPE zcl_tr_content=>ty_field_names
        client       TYPE mandt DEFAULT sy-mandt
      EXPORTING
        to_write     TYPE STANDARD TABLE
        missing_rows TYPE STANDARD TABLE
        inserted     TYPE i
        changed      TYPE i
        unchanged    TYPE i.
    " A new workbench request with a task of the current user.
    CLASS-METHODS create_request
      IMPORTING
        text          TYPE as4text
      RETURNING
        VALUE(result) TYPE trkorr
      RAISING
        zcx_abapgit_exception.

    METHODS constructor
      IMPORTING
        remote_files TYPE zif_abapgit_git_definitions=>ty_files_tt.
    " One item per file of content/. TASK is a request or task that is
    " not released; it is needed only to write.
    METHODS run
      IMPORTING
        task           TYPE trkorr OPTIONAL
        write_changes  TYPE abap_bool DEFAULT abap_false
        delete_missing TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result)  TYPE ty_items
      RAISING
        zcx_abapgit_exception.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_position,
        key      TYPE string,
        position TYPE i,
      END OF ty_position.
    TYPES ty_positions TYPE HASHED TABLE OF ty_position WITH UNIQUE KEY key.
    TYPES ty_values TYPE STANDARD TABLE OF rsparams WITH DEFAULT KEY.
    TYPES ty_texts  TYPE STANDARD TABLE OF varit WITH DEFAULT KEY.
    TYPES ty_raw    TYPE STANDARD TABLE OF vari WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_variant_file,
        header     TYPE varid,
        texts      TYPE ty_texts,
        values     TYPE ty_values,
        raw_values TYPE ty_raw,
      END OF ty_variant_file.
    TYPES:
      BEGIN OF ty_note_file,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
        note     TYPE cwbnthead-numm,
        version  TYPE cwbnthead-versno,
      END OF ty_note_file.

    CONSTANTS tables_path   TYPE string VALUE '/content/tables/'.
    CONSTANTS variants_path TYPE string VALUE '/content/variants/'.
    CONSTANTS notes_path    TYPE string VALUE '/content/notes/'.

    DATA remote_files TYPE zif_abapgit_git_definitions=>ty_files_tt.

    CLASS-METHODS clear_row
      IMPORTING
        client_field TYPE fieldname
        secrets      TYPE zcl_tr_content=>ty_field_names
      CHANGING
        row          TYPE any.
    CLASS-METHODS sy_message
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS task_of
      IMPORTING
        request       TYPE trkorr
      RETURNING
        VALUE(result) TYPE trkorr
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS file_text
      IMPORTING
        file          TYPE zif_abapgit_git_definitions=>ty_file
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS record_rows
      IMPORTING
        task         TYPE trkorr
        table        TYPE tabname
        fields       TYPE zcl_tr_content=>ty_key_fields
        client_field TYPE fieldname
        rows         TYPE STANDARD TABLE
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS record_variant
      IMPORTING
        task    TYPE trkorr
        report  TYPE rsvar-report
        variant TYPE rsvar-variant
      RAISING
        zcx_abapgit_exception.

    " S_TABU_NAM, activity 02, for one table. A client-independent table also needs S_TABU_CLI.
    METHODS may_change
      IMPORTING
        table         TYPE tabname
        is_cross_client TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS apply_table
      IMPORTING
        file           TYPE zif_abapgit_git_definitions=>ty_file
        task           TYPE trkorr
        write_changes  TYPE abap_bool
        delete_missing TYPE abap_bool
      RETURNING
        VALUE(result)  TYPE ty_item
      RAISING
        zcx_abapgit_exception.
    METHODS apply_variant
      IMPORTING
        file          TYPE zif_abapgit_git_definitions=>ty_file
        task          TYPE trkorr
        write_changes TYPE abap_bool
      RETURNING
        VALUE(result) TYPE ty_item
      RAISING
        zcx_abapgit_exception.
    METHODS apply_note
      IMPORTING
        file          TYPE zif_abapgit_git_definitions=>ty_file
      RETURNING
        VALUE(result) TYPE ty_item
      RAISING
        zcx_abapgit_exception.
ENDCLASS.



CLASS ZCL_TR_CONTENT_APPLY IMPLEMENTATION.


  METHOD apply_note.
    DATA note TYPE ty_note_file.

    result-kind = kind-note.
    result-name = file-filename.
    TRY.
        zcl_abapgit_ajson=>parse( file_text( file ) )->to_abap( IMPORTING ev_container = note ).
      CATCH zcx_abapgit_ajson_error INTO DATA(parse_error).
        result-failed  = abap_true.
        result-message = |not readable: { parse_error->get_text( ) }|.
        RETURN.
    ENDTRY.

    result-name = |{ note-object } { note-obj_name }|.
    IF note-note IS INITIAL.
      result-message = |entry of type { note-object }: nothing that can be compared, check it by hand|.
      result-missing = 1.
      RETURN.
    ENDIF.

    SELECT MAX( versno ) FROM cwbnthead
      INTO @DATA(version)
      WHERE numm = @note-note.
    IF version IS INITIAL.
      result-missing = 1.
      result-message = |SAP Note { note-note } is not on this system: download and implement it in SNOTE|.
    ELSEIF version < note-version.
      result-missing = 1.
      result-message = |SAP Note { note-note }: version { version } here, version { note-version } in Git: update it in SNOTE|.
    ELSE.
      result-unchanged = 1.
      result-message = |SAP Note { note-note } is here in version { version }|.
    ENDIF.
  ENDMETHOD.


  METHOD may_change.
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD table.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    IF is_cross_client = abap_true.
      AUTHORITY-CHECK OBJECT 'S_TABU_CLI'
        ID 'CLIIDMAINT' FIELD 'X'.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
    ENDIF.
    result = abap_true.
  ENDMETHOD.


  METHOD apply_table.
    DATA fields       TYPE zcl_tr_content=>ty_key_fields.
    DATA client_field TYPE fieldname.
    DATA git_ref      TYPE REF TO data.
    DATA system_ref   TYPE REF TO data.
    DATA write_ref    TYPE REF TO data.
    DATA missing_ref  TYPE REF TO data.
    FIELD-SYMBOLS <git>     TYPE STANDARD TABLE.
    FIELD-SYMBOLS <system>  TYPE STANDARD TABLE.
    FIELD-SYMBOLS <write>   TYPE STANDARD TABLE.
    FIELD-SYMBOLS <missing> TYPE STANDARD TABLE.

    DATA(table) = CONV tabname( to_upper( substring_before( val = file-filename sub = '.json' ) ) ).
    REPLACE ALL OCCURRENCES OF '#' IN table WITH '/'.
    result-kind = kind-table.
    result-name = table.

    SELECT SINGLE tabclass FROM dd02l
      INTO @DATA(table_class)
      WHERE tabname  = @table
        AND as4local = 'A'.
    IF sy-subrc <> 0 OR table_class <> 'TRANSP'.
      result-message = |skipped: { table } is not a transparent table on this system|.
      RETURN.
    ENDIF.
    " Only the tables whose rows the tools write to Git, in the packages under Git. A file name in a
    " repository must not be enough to change any table of the system.
    IF zcl_tr_content=>is_content_table( table ) = abap_false.
      result-message = |skipped: { table } is not a content table of the packages under Git (delivery class E, S or G, or STVARV ZTR_CONTENT_TABLES)|.
      RETURN.
    ENDIF.
    IF write_changes = abap_true AND may_change( table ) = abap_false.
      result-message = |skipped: no authorization to change { table } (S_TABU_NAM, activity 02)|.
      RETURN.
    ENDIF.
    IF zcl_tr_content=>key_fields( EXPORTING table = table
                                       IMPORTING fields = fields client_field = client_field ) = abap_false.
      result-message = |skipped: no key fields of { table }|.
      RETURN.
    ENDIF.
    IF write_changes = abap_true AND client_field IS INITIAL AND
       may_change( table = table is_cross_client = abap_true ) = abap_false.
      result-message = |skipped: { table } is client-independent and needs S_TABU_CLI as well|.
      RETURN.
    ENDIF.
    DATA(secrets) = zcl_tr_content=>secret_fields( table ).

    CREATE DATA git_ref     TYPE STANDARD TABLE OF (table).
    CREATE DATA system_ref  TYPE STANDARD TABLE OF (table).
    CREATE DATA write_ref   TYPE STANDARD TABLE OF (table).
    CREATE DATA missing_ref TYPE STANDARD TABLE OF (table).
    ASSIGN git_ref->*     TO <git>.
    ASSIGN system_ref->*  TO <system>.
    ASSIGN write_ref->*   TO <write>.
    ASSIGN missing_ref->* TO <missing>.

    TRY.
        zcl_abapgit_ajson=>parse( file_text( file ) )->to_abap( IMPORTING ev_container = <git> ).
      CATCH zcx_abapgit_ajson_error INTO DATA(parse_error).
        result-failed  = abap_true.
        result-message = |not readable: { parse_error->get_text( ) }|.
        RETURN.
    ENDTRY.

    TRY.
        SELECT * FROM (table) INTO TABLE <system>.
      CATCH cx_sy_dynamic_osql_error INTO DATA(sql_error).
        result-failed  = abap_true.
        result-message = |reading { table } failed: { sql_error->get_text( ) }|.
        RETURN.
    ENDTRY.

    compare_rows(
      EXPORTING
        git_rows     = <git>
        system_rows  = <system>
        fields       = fields
        client_field = client_field
        secrets      = secrets
      IMPORTING
        to_write     = <write>
        missing_rows = <missing>
        inserted     = result-inserted
        changed      = result-changed
        unchanged    = result-unchanged ).
    result-missing = lines( <missing> ).
    IF secrets IS NOT INITIAL AND result-inserted > 0.
      result-message = |new rows get blank credential fields: { lines( secrets ) } field(s) to fill by hand|.
    ENDIF.

    IF write_changes = abap_false.
      RETURN.
    ENDIF.

    DATA(delete_rows) = xsdbool( delete_missing = abap_true AND result-missing > 0 ).
    IF lines( <write> ) = 0 AND delete_rows = abap_false.
      RETURN.
    ENDIF.

    " Recorded first: if the request does not take the keys, nothing is written.
    IF lines( <write> ) > 0.
      record_rows( task = task table = table fields = fields client_field = client_field rows = <write> ).
      MODIFY (table) FROM TABLE <write>.
      IF sy-subrc <> 0.
        ROLLBACK WORK.
        result-failed  = abap_true.
        result-message = |writing { table } failed|.
        RETURN.
      ENDIF.
    ENDIF.
    IF delete_rows = abap_true.
      record_rows( task = task table = table fields = fields client_field = client_field rows = <missing> ).
      DELETE (table) FROM TABLE <missing>.
    ENDIF.
    COMMIT WORK AND WAIT.
    result-written = abap_true.
  ENDMETHOD.


  METHOD apply_variant.
    DATA content        TYPE ty_variant_file.
    DATA current_values TYPE ty_values.
    DATA current_texts  TYPE ty_texts.
    DATA current_raw    TYPE ty_raw.
    FIELD-SYMBOLS <text> TYPE varit.
    FIELD-SYMBOLS <raw>  TYPE vari.

    result-kind = kind-variant.
    result-name = file-filename.
    TRY.
        zcl_abapgit_ajson=>parse( file_text( file ) )->to_abap( IMPORTING ev_container = content ).
      CATCH zcx_abapgit_ajson_error INTO DATA(parse_error).
        result-failed  = abap_true.
        result-message = |not readable: { parse_error->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA(report)  = content-header-report.
    DATA(variant) = content-header-variant.
    result-name = |{ report } { variant }|.
    IF report IS INITIAL OR variant IS INITIAL.
      result-failed  = abap_true.
      result-message = |no report or variant name in the file|.
      RETURN.
    ENDIF.
    IF variant CA '%&'.
      result-message = |skipped: client-independent variant, transport it by hand|.
      RETURN.
    ENDIF.
    " Only variants that the tools write to Git themselves: of a report in a package under Git, or
    " the product variants of the Git settings. A file name in a repository must not be enough to
    " change the variants of any report.
    IF zcl_tr_content=>is_content_variant( report = report variant = variant ) = abap_false.
      result-message = |skipped: { report } is not a report of the packages under Git, and { variant } is not a variant of the Git settings (STVARV ZTR_VARIANT_PATTERN, ZTR_VARIANT_PACKAGE)|.
      RETURN.
    ENDIF.

    SELECT SINGLE name FROM trdir INTO @DATA(program) WHERE name = @report.
    DATA(report_exists) = xsdbool( sy-subrc = 0 ).
    SELECT SINGLE variant FROM varid INTO @DATA(existing_variant)
      WHERE report = @report AND variant = @variant.
    DATA(variant_exists) = xsdbool( sy-subrc = 0 ).

    SELECT * FROM varit INTO TABLE @current_texts
      WHERE report = @report AND variant = @variant
      ORDER BY PRIMARY KEY.
    LOOP AT current_texts ASSIGNING <text>.
      CLEAR <text>-mandt.
    ENDLOOP.

    " For a report that exists, the variant goes in through the function modules of SAP, which
    " check what they are given. The raw tables are only for a report that is not on this system.
    IF report_exists = abap_true AND content-values IS INITIAL.
      result-message = |skipped: the file has no readable values for the report { report }, which exists here|.
      RETURN.
    ENDIF.
    DATA(by_function) = xsdbool( report_exists = abap_true AND content-values IS NOT INITIAL ).
    IF by_function = abap_true.
      IF variant_exists = abap_true.
        CALL FUNCTION 'RS_VARIANT_CONTENTS'
          EXPORTING
            report               = report
            variant              = variant
          TABLES
            valutab              = current_values
          EXCEPTIONS
            variant_non_existent = 1
            variant_obsolete     = 2
            OTHERS               = 3.
        IF sy-subrc <> 0.
          CLEAR current_values.
        ENDIF.
      ENDIF.
      IF variant_exists = abap_true AND current_values = content-values AND current_texts = content-texts.
        result-unchanged = 1.
        RETURN.
      ENDIF.
    ELSE.
      IF content-raw_values IS INITIAL.
        result-message = |skipped: report { report } is not on this system and the file has no stored values|.
        RETURN.
      ENDIF.
      SELECT * FROM vari INTO TABLE @current_raw
        WHERE report = @report AND variant = @variant
        ORDER BY PRIMARY KEY.
      LOOP AT current_raw ASSIGNING <raw>.
        CLEAR: <raw>-mandt, <raw>-vdate, <raw>-vtime.
      ENDLOOP.
      IF variant_exists = abap_true AND current_raw = content-raw_values AND current_texts = content-texts.
        result-unchanged = 1.
        RETURN.
      ENDIF.
    ENDIF.

    IF variant_exists = abap_true.
      result-changed = 1.
    ELSE.
      result-inserted = 1.
    ENDIF.
    IF write_changes = abap_false.
      RETURN.
    ENDIF.

    IF may_change( `VARID` ) = abap_false OR may_change( `VARI` ) = abap_false OR may_change( `VARIT` ) = abap_false.
      result-message = |skipped: no authorization to change variants (S_TABU_NAM, activity 02 for VARID, VARI, VARIT)|.
      RETURN.
    ENDIF.

    record_variant( task = task report = report variant = variant ).

    DATA(header) = content-header.
    header-mandt = sy-mandt.
    " The rows of the file belong to the variant that was checked above, whatever the rows say.
    LOOP AT content-texts ASSIGNING <text>.
      <text>-mandt   = sy-mandt.
      <text>-report  = report.
      <text>-variant = variant.
    ENDLOOP.

    IF by_function = abap_true.
      IF variant_exists = abap_true.
        CALL FUNCTION 'RS_CHANGE_CREATED_VARIANT'
          EXPORTING
            curr_report   = report
            curr_variant  = variant
            vari_desc     = header
          TABLES
            vari_contents = content-values
            vari_text     = content-texts
          EXCEPTIONS
            OTHERS        = 1.
      ELSE.
        CALL FUNCTION 'RS_CREATE_VARIANT'
          EXPORTING
            curr_report   = report
            curr_variant  = variant
            vari_desc     = header
          TABLES
            vari_contents = content-values
            vari_text     = content-texts
          EXCEPTIONS
            OTHERS        = 1.
      ENDIF.
      IF sy-subrc <> 0.
        ROLLBACK WORK.
        result-failed  = abap_true.
        result-message = |variant function failed: { sy_message( ) }|.
        RETURN.
      ENDIF.
    ELSE.
      LOOP AT content-raw_values ASSIGNING <raw>.
        <raw>-mandt   = sy-mandt.
        <raw>-report  = report.
        <raw>-variant = variant.
        <raw>-vdate   = sy-datum.
        <raw>-vtime = sy-uzeit.
      ENDLOOP.
      DELETE FROM vari  WHERE report = report AND variant = variant.
      DELETE FROM varit WHERE report = report AND variant = variant.
      MODIFY varid FROM header.
      MODIFY vari  FROM TABLE content-raw_values.
      MODIFY varit FROM TABLE content-texts.
    ENDIF.
    COMMIT WORK AND WAIT.
    result-written = abap_true.
  ENDMETHOD.


  METHOD clear_row.
    FIELD-SYMBOLS <value> TYPE any.

    IF client_field IS NOT INITIAL.
      ASSIGN COMPONENT client_field OF STRUCTURE row TO <value>.
      IF sy-subrc = 0.
        CLEAR <value>.
      ENDIF.
    ENDIF.
    LOOP AT secrets INTO DATA(secret).
      ASSIGN COMPONENT secret OF STRUCTURE row TO <value>.
      IF sy-subrc = 0.
        CLEAR <value>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD compare_rows.
    DATA positions   TYPE ty_positions.
    DATA system_copy TYPE REF TO data.
    DATA git_copy    TYPE REF TO data.
    DATA target_ref  TYPE REF TO data.
    FIELD-SYMBOLS <git>          TYPE any.
    FIELD-SYMBOLS <system>       TYPE any.
    FIELD-SYMBOLS <system_plain> TYPE any.
    FIELD-SYMBOLS <git_plain>    TYPE any.
    FIELD-SYMBOLS <target>       TYPE any.
    FIELD-SYMBOLS <from>         TYPE any.
    FIELD-SYMBOLS <to>           TYPE any.

    CLEAR: to_write, missing_rows, inserted, changed, unchanged.

    DATA(line_type) = CAST cl_abap_tabledescr( cl_abap_typedescr=>describe_by_data( git_rows ) )->get_table_line_type( ).
    CREATE DATA system_copy TYPE HANDLE line_type.
    CREATE DATA git_copy    TYPE HANDLE line_type.
    CREATE DATA target_ref  TYPE HANDLE line_type.
    ASSIGN system_copy->* TO <system_plain>.
    ASSIGN git_copy->*    TO <git_plain>.
    ASSIGN target_ref->*  TO <target>.

    LOOP AT system_rows ASSIGNING <system>.
      INSERT VALUE #( key      = zcl_tr_content=>key_of( row = <system> fields = fields )
                      position = sy-tabix ) INTO TABLE positions.
    ENDLOOP.

    LOOP AT git_rows ASSIGNING <git>.
      DATA(key) = zcl_tr_content=>key_of( row = <git> fields = fields ).
      READ TABLE positions ASSIGNING FIELD-SYMBOL(<position>) WITH TABLE KEY key = key.
      DATA(found) = xsdbool( sy-subrc = 0 ).

      " The row to write: Git's row in this client, credentials blank.
      <target> = <git>.
      IF client_field IS NOT INITIAL.
        ASSIGN COMPONENT client_field OF STRUCTURE <target> TO <to>.
        IF sy-subrc = 0.
          <to> = client.
        ENDIF.
      ENDIF.
      LOOP AT secrets INTO DATA(blank_secret).
        ASSIGN COMPONENT blank_secret OF STRUCTURE <target> TO <to>.
        IF sy-subrc = 0.
          CLEAR <to>.
        ENDIF.
      ENDLOOP.

      IF found = abap_false.
        APPEND <target> TO to_write.
        inserted = inserted + 1.
        CONTINUE.
      ENDIF.

      DATA(position) = <position>-position.
      DELETE TABLE positions WITH TABLE KEY key = key.
      READ TABLE system_rows INDEX position ASSIGNING <system>.

      " Same rows once client and credentials are out of the way.
      <system_plain> = <system>.
      <git_plain>    = <git>.
      clear_row( EXPORTING client_field = client_field secrets = secrets CHANGING row = <system_plain> ).
      clear_row( EXPORTING client_field = client_field secrets = secrets CHANGING row = <git_plain> ).
      IF <system_plain> = <git_plain>.
        unchanged = unchanged + 1.
        CONTINUE.
      ENDIF.

      " A changed row keeps the credentials of the system.
      LOOP AT secrets INTO DATA(secret).
        ASSIGN COMPONENT secret OF STRUCTURE <system> TO <from>.
        ASSIGN COMPONENT secret OF STRUCTURE <target> TO <to>.
        IF <from> IS ASSIGNED AND <to> IS ASSIGNED.
          <to> = <from>.
        ENDIF.
      ENDLOOP.
      APPEND <target> TO to_write.
      changed = changed + 1.
    ENDLOOP.

    LOOP AT positions ASSIGNING <position>.
      READ TABLE system_rows INDEX <position>-position ASSIGNING <system>.
      APPEND <system> TO missing_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD constructor.
    me->remote_files = remote_files.
  ENDMETHOD.


  METHOD create_request.
    DATA header TYPE trwbo_request_header.

    CALL FUNCTION 'TR_INSERT_REQUEST_WITH_TASKS'
      EXPORTING
        iv_type            = 'K'
        iv_text            = text
        iv_owner           = sy-uname
        it_users           = VALUE scts_users( ( user = sy-uname ) )
        iv_with_badi_check = abap_true
      IMPORTING
        es_request_header  = header
      EXCEPTIONS
        insert_failed      = 1
        enqueue_failed     = 2
        OTHERS             = 3.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |The request was not created: { sy_message( ) }| ).
    ENDIF.
    COMMIT WORK AND WAIT.
    result = header-trkorr.
  ENDMETHOD.


  METHOD file_text.
    result = zcl_abapgit_convert=>xstring_to_string_utf8( file-data ).
  ENDMETHOD.


  METHOD record_rows.
    DATA objects TYPE STANDARD TABLE OF e071 WITH DEFAULT KEY.
    DATA keys    TYPE STANDARD TABLE OF e071k WITH DEFAULT KEY.
    DATA tabkey  TYPE e071k-tabkey.
    FIELD-SYMBOLS <row> TYPE any.

    APPEND VALUE #( pgmid = 'R3TR' object = 'TABU' obj_name = table objfunc = 'K' ) TO objects.
    LOOP AT rows ASSIGNING <row>.
      " As E071K holds it: the client first, then the key fields.
      tabkey = zcl_tr_content=>key_of( row = <row> fields = fields ).
      IF client_field IS NOT INITIAL.
        tabkey = |{ sy-mandt }{ tabkey }|.
      ENDIF.
      APPEND VALUE #( pgmid      = 'R3TR'
                      object     = 'TABU'
                      objname    = table
                      tabkey     = tabkey
                      mastertype = 'TABU'
                      mastername = table ) TO keys.
    ENDLOOP.

    CALL FUNCTION 'TR_APPEND_TO_COMM_OBJS_KEYS'
      EXPORTING
        wi_trkorr = task
        iv_dialog = abap_false
      TABLES
        wt_e071   = objects
        wt_e071k  = keys
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      zcx_abapgit_exception=>raise( |{ table } was not recorded in { task }: { sy_message( ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD record_variant.
    DATA objects TYPE STANDARD TABLE OF e071 WITH DEFAULT KEY.
    DATA keys    TYPE STANDARD TABLE OF e071k WITH DEFAULT KEY.

    " The object name of a variant: report in 40 characters, then the name.
    APPEND VALUE #( pgmid    = 'R3TR'
                    object   = 'VARX'
                    obj_name = |{ report WIDTH = 40 }{ variant }| ) TO objects.
    CALL FUNCTION 'TR_APPEND_TO_COMM_OBJS_KEYS'
      EXPORTING
        wi_trkorr = task
        iv_dialog = abap_false
      TABLES
        wt_e071   = objects
        wt_e071k  = keys
      EXCEPTIONS
        OTHERS    = 1.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      zcx_abapgit_exception=>raise( |Variant { report } { variant } was not recorded in { task }: { sy_message( ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD run.
    DATA request_task TYPE trkorr.

    IF write_changes = abap_true.
      IF task IS INITIAL.
        zcx_abapgit_exception=>raise( |Writing needs a request or task that is not released| ).
      ENDIF.
      request_task = task_of( task ).
    ENDIF.

    DATA(files) = remote_files.
    SORT files BY path filename.
    LOOP AT files INTO DATA(file) WHERE filename CP '*.json'.
      TRY.
          CASE file-path.
            WHEN tables_path.
              APPEND apply_table( file           = file
                                  task           = request_task
                                  write_changes  = write_changes
                                  delete_missing = delete_missing ) TO result.
            WHEN variants_path.
              APPEND apply_variant( file          = file
                                    task          = request_task
                                    write_changes = write_changes ) TO result.
            WHEN notes_path.
              APPEND apply_note( file ) TO result.
          ENDCASE.
        CATCH zcx_abapgit_exception INTO DATA(error).
          ROLLBACK WORK.
          APPEND VALUE #( name = file-filename failed = abap_true message = error->get_text( ) ) TO result.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD sy_message.
    IF sy-msgid IS INITIAL.
      result = |no message|.
      RETURN.
    ENDIF.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      INTO result.
  ENDMETHOD.


  METHOD task_of.
    SELECT SINGLE trkorr, strkorr, trstatus FROM e070
      INTO @DATA(header)
      WHERE trkorr = @request.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Request or task { request } does not exist| ).
    ENDIF.
    IF header-trstatus <> 'D'.
      zcx_abapgit_exception=>raise( |{ request } is released: changes can only go into an open request| ).
    ENDIF.
    IF header-strkorr IS NOT INITIAL.
      result = header-trkorr.
      RETURN.
    ENDIF.

    SELECT trkorr FROM e070
      INTO @result UP TO 1 ROWS
      WHERE strkorr  = @request
        AND as4user  = @sy-uname
        AND trstatus = 'D'
      ORDER BY trkorr.
    ENDSELECT.
    IF result IS INITIAL.
      zcx_abapgit_exception=>raise( |Request { request } has no open task of { sy-uname }| ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
