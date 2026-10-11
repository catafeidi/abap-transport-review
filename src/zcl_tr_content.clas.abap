*----------------------------------------------------------------------*
* Class ZCL_TR_CONTENT: what abapGit does not write to Git.
*
* abapGit writes repository objects (classes, tables, programs, ...) as
* files under src/. A transport carries more: table rows, report
* variants, authorization profiles, OTR texts, SAP Note entries. This
* class writes those as JSON under content/, so that everything a
* transport carries is in Git and goes through the same review.
*
*   content/tables/<table>.json      rows of a table, sorted by key; one
*                                    file per table and repository, rows
*                                    of every key that was transported
*                                    (TABU, TDAT, VDAT, CDAT, logical
*                                    objects such as SUSP and SUSK, OTR)
*   content/variants/<report>.<variant>.json
*                                    variant header, texts and values
*   content/notes/<entry>.json       SAP Note entries: number, version
*
* abapGit ignores the folder: the repositories start in /src/.
*
* Used by report ZTR_PUSH_TRANSPORT for every push and every check,
* and by its baseline run for what is already in the packages. One
* instance per repository: it gets the files of the selected branch and
* the packages of the repository, and keeps only what belongs there.
*
* Transports of copies are never handled (the caller filters them).
* Entries no handler covers are reported by UNCOVERED.
*
* Create in SE24 as a local object, source-based editor, paste this file.
* Needs abapGit (ZCL_ABAPGIT_AJSON, ZCL_ABAPGIT_OBJECTS). ABAP 7.40.
*----------------------------------------------------------------------*
CLASS zcl_tr_content DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_table_range TYPE RANGE OF tabname.
    TYPES:
      BEGIN OF ty_file,
        path     TYPE string,
        filename TYPE string,
        data     TYPE xstring,
      END OF ty_file.
    TYPES ty_files TYPE STANDARD TABLE OF ty_file WITH DEFAULT KEY.
    TYPES ty_packages TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
    " One entry of a transport that abapGit does not write.
    TYPES:
      BEGIN OF ty_entry,
        trkorr   TYPE trkorr,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
        kind     TYPE c LENGTH 1,     " see kind
        package  TYPE devclass,       " owner, decides the repository
      END OF ty_entry.
    TYPES ty_entries TYPE STANDARD TABLE OF ty_entry WITH DEFAULT KEY.
    TYPES ty_key_fields TYPE STANDARD TABLE OF dfies WITH DEFAULT KEY.
    TYPES ty_field_names TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY.

    CONSTANTS folder TYPE string VALUE '/content/'.
    CONSTANTS:
      BEGIN OF kind,
        abapgit   TYPE c LENGTH 1 VALUE 'G',   " a file under src/, abapGit's job
        rows      TYPE c LENGTH 1 VALUE 'T',   " table rows with keys in E071K
        logical   TYPE c LENGTH 1 VALUE 'L',   " logical transport object (OBJH/OBJSL)
        otr       TYPE c LENGTH 1 VALUE 'O',   " OTR texts of a package
        variant   TYPE c LENGTH 1 VALUE 'V',   " report variant
        note      TYPE c LENGTH 1 VALUE 'N',   " SAP Note implementation
        uncovered TYPE c LENGTH 1 VALUE 'U',   " nothing writes it to Git
      END OF kind.

    " Every entry of a task or request with its kind and owner package.
    " Only entries that are not abapGit's job are returned.
    CLASS-METHODS classify
      IMPORTING
        transport     TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_entries.
    " The entries of a request and of all its tasks.
    CLASS-METHODS classify_request
      IMPORTING
        request       TYPE trkorr
      RETURNING
        VALUE(result) TYPE ty_entries.
    " Text for logs and the pull request: one line per entry.
    CLASS-METHODS describe
      IMPORTING
        entry         TYPE ty_entry
      RETURNING
        VALUE(result) TYPE string.
    " The key fields of a table without the client, and its client field
    " (empty for a table that is not client dependent). False if the table
    " does not exist as a dictionary structure on this system.
    " True for a table whose rows the tools write to Git, and may therefore write back: a transparent
    " table of a package under Git (STVARV ZTR_PACKAGES) that is delivered content (delivery class E, S
    " or G) or is listed in STVARV select option ZTR_CONTENT_TABLES.
    CLASS-METHODS is_content_table
      IMPORTING
        table         TYPE tabname
      RETURNING
        VALUE(result) TYPE abap_bool.
    " True for a variant that the tools write to Git, and may write back: a variant of a report in a
    " package under Git, or a variant whose name matches STVARV ZTR_VARIANT_PATTERN when the package
    " in STVARV ZTR_VARIANT_PACKAGE is under Git.
    CLASS-METHODS is_content_variant
      IMPORTING
        report        TYPE rsvar-report
        variant       TYPE rsvar-variant
      RETURNING
        VALUE(result) TYPE abap_bool.
    CLASS-METHODS key_fields
      IMPORTING
        table         TYPE tabname
      EXPORTING
        fields        TYPE ty_key_fields
        client_field  TYPE fieldname
      RETURNING
        VALUE(result) TYPE abap_bool.
    " The key of a row as the transport writes it in E071K, without client.
    CLASS-METHODS key_of
      IMPORTING
        row           TYPE any
        fields        TYPE ty_key_fields
      RETURNING
        VALUE(result) TYPE string.
    " Non-key fields that may hold credentials. They are blanked in every
    " file, so whoever applies a file must keep the values of the system.
    CLASS-METHODS secret_fields
      IMPORTING
        table         TYPE tabname
      RETURNING
        VALUE(result) TYPE ty_field_names.

    METHODS constructor
      IMPORTING
        remote_files TYPE zif_abapgit_git_definitions=>ty_files_tt
        packages     TYPE ty_packages.
    " The content of one task or request, for this repository.
    METHODS add_transport
      IMPORTING
        transport TYPE trkorr.
    " Baseline: everything of the packages of this repository that abapGit
    " does not write: objects without abapGit type, rows of the delivered
    " tables, variants and ALV layouts of the programs.
    METHODS add_packages.
    " Files to create or change: their new content.
    METHODS changed
      RETURNING
        VALUE(result) TYPE ty_files.
    " Files that must be removed.
    METHODS removed
      RETURNING
        VALUE(result) TYPE ty_files.
    " Entries of this repository that nothing could write.
    METHODS uncovered
      RETURNING
        VALUE(result) TYPE ty_entries.
    METHODS has_entries
      RETURNING
        VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_key,
        table  TYPE tabname,
        tabkey TYPE e071k-tabkey,
      END OF ty_key.
    TYPES ty_keys TYPE STANDARD TABLE OF ty_key WITH DEFAULT KEY.
    TYPES ty_strings TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    CONSTANTS client_type TYPE datatype_d VALUE 'CLNT'.
    " Variants of reports that a package maintains: STVARV parameters
    " ZTR_VARIANT_PATTERN (name pattern of the variants) and
    " ZTR_VARIANT_PACKAGE (the package they belong to). Without both,
    " variants are not written to Git.
    CONSTANTS default_variant_pattern TYPE string VALUE ``.
    CONSTANTS default_variant_package TYPE devclass VALUE ''.
    CONSTANTS key_length  TYPE i VALUE 120.

    DATA remote_files TYPE zif_abapgit_git_definitions=>ty_files_tt.
    DATA packages     TYPE ty_packages.
    DATA keys         TYPE ty_keys.
    DATA variants     TYPE ty_entries.
    DATA notes        TYPE ty_entries.
    DATA missing      TYPE ty_entries.

    CLASS-METHODS kind_of
      IMPORTING
        entry         TYPE e071
      RETURNING
        VALUE(result) TYPE ty_entry-kind.
    CLASS-METHODS owner_package
      IMPORTING
        entry         TYPE e071
        entry_kind    TYPE ty_entry-kind
      RETURNING
        VALUE(result) TYPE devclass.
    CLASS-METHODS variant_setting
      EXPORTING
        pattern TYPE string
        package TYPE devclass.
    CLASS-METHODS package_of
      IMPORTING
        object        TYPE csequence OPTIONAL
        obj_name      TYPE csequence
      RETURNING
        VALUE(result) TYPE devclass.
    CLASS-METHODS file_name
      IMPORTING
        name          TYPE csequence
      RETURNING
        VALUE(result) TYPE string.

    CLASS-METHODS extra_table_range
      RETURNING
        VALUE(result) TYPE zcl_tr_content=>ty_table_range.

    METHODS is_ours
      IMPORTING
        package       TYPE devclass
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS add_entry
      IMPORTING
        entry TYPE ty_entry.
    METHODS add_logical_keys
      IMPORTING
        entry TYPE ty_entry.
    METHODS add_otr_keys
      IMPORTING
        package TYPE csequence.
    METHODS add_whole_table
      IMPORTING
        table TYPE tabname.
    METHODS matches
      IMPORTING
        key           TYPE string
        tabkey        TYPE csequence
      RETURNING
        VALUE(result) TYPE abap_bool.
    " Fields that may hold credentials: blanked in every file. The rule is a
    " deny-list on the names of field, data element and domain, so it is best effort:
    " a credential in a field with an ordinary name is not found.
    METHODS mask_secrets
      IMPORTING
        table TYPE tabname
      CHANGING
        rows  TYPE STANDARD TABLE.
    METHODS table_file
      IMPORTING
        table TYPE tabname
      CHANGING
        files TYPE ty_files
        gone  TYPE ty_files.
    METHODS read_rows
      IMPORTING
        table        TYPE tabname
        tabkey       TYPE csequence
        fields       TYPE ty_key_fields
        client_field TYPE fieldname
      CHANGING
        rows         TYPE STANDARD TABLE.
    METHODS variant_file
      IMPORTING
        entry TYPE ty_entry
      CHANGING
        files TYPE ty_files
        gone  TYPE ty_files.
    METHODS note_file
      IMPORTING
        entry TYPE ty_entry
      CHANGING
        files TYPE ty_files.
    METHODS remote_text
      IMPORTING
        filename      TYPE string
        path          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS to_file
      IMPORTING
        path     TYPE string
        filename TYPE string
        json     TYPE string
      CHANGING
        files    TYPE ty_files.
ENDCLASS.



CLASS ZCL_TR_CONTENT IMPLEMENTATION.


  METHOD add_entry.
    CASE entry-kind.
      WHEN kind-rows.
        " The keys the transport recorded, views and clusters already
        " broken down into their tables.
        SELECT objname, tabkey FROM e071k
          INTO TABLE @DATA(transport_keys)
          WHERE trkorr     = @entry-trkorr
            AND mastertype = @entry-object
            AND mastername = @entry-obj_name.
        LOOP AT transport_keys INTO DATA(transport_key).
          APPEND VALUE #( table = transport_key-objname tabkey = transport_key-tabkey ) TO keys.
        ENDLOOP.
      WHEN kind-logical.
        add_logical_keys( entry ).
      WHEN kind-otr.
        add_otr_keys( entry-obj_name ).
      WHEN kind-variant.
        APPEND entry TO variants.
      WHEN kind-note.
        APPEND entry TO notes.
      WHEN OTHERS.
        APPEND entry TO missing.
    ENDCASE.
  ENDMETHOD.


  METHOD add_logical_keys.
    " SAP's own definition: OBJSL lists the tables of the object and a key
    " mask per table. '/' starts the next key field, '&' is the object
    " name, 'L' a language and '*' the rest: all generic.
    DATA fields       TYPE ty_key_fields.
    DATA client_field TYPE fieldname.
    DATA tabkey       TYPE c LENGTH 120.
    DATA position     TYPE i.

    SELECT tobj_name, tobjkey FROM objsl
      INTO TABLE @DATA(definitions)
      WHERE objectname = @entry-object
        AND objecttype = 'L'
        AND tobject    = 'TABU'.

    LOOP AT definitions INTO DATA(definition).
      DATA(table) = CONV tabname( definition-tobj_name ).
      IF key_fields( EXPORTING table = table IMPORTING fields = fields client_field = client_field ) = abap_false.
        APPEND entry TO missing.
        CONTINUE.
      ENDIF.

      CLEAR: tabkey, position.
      IF client_field IS NOT INITIAL.
        tabkey = sy-mandt.
        position = 3.
      ENDIF.
      DATA(mask) = CONV string( definition-tobjkey ).
      IF mask(1) = '/'.
        mask = mask+1.
      ENDIF.
      SPLIT mask AT '/' INTO TABLE DATA(segments).
      LOOP AT segments INTO DATA(segment).
        READ TABLE fields INTO DATA(field) INDEX sy-tabix.
        IF sy-subrc <> 0 OR segment = '*' OR segment = 'L'.
          tabkey+position(1) = '*'.
          position = position + 1.
          EXIT.
        ENDIF.
        REPLACE '&' IN segment WITH condense( CONV string( entry-obj_name ) ).
        IF field-leng <= 0 OR position + field-leng > key_length.
          EXIT.
        ENDIF.
        tabkey+position(field-leng) = segment.
        position = position + field-leng.
      ENDLOOP.
      APPEND VALUE #( table = table tabkey = tabkey ) TO keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_otr_keys.
    " Old OTR: header and texts of every concept of the package.
    SELECT concept FROM sotr_head
      INTO TABLE @DATA(concepts)
      WHERE paket = @package.
    LOOP AT concepts INTO DATA(concept).
      APPEND VALUE #( table = 'SOTR_HEAD' tabkey = concept-concept ) TO keys.
      APPEND VALUE #( table = 'SOTR_TEXT' tabkey = |{ concept-concept }*| ) TO keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_packages.
    DATA entry TYPE ty_entry.

    DATA(extra_tables) = extra_table_range( ).

    " Objects without an abapGit type, for example authorization profiles
    " (SUSP) and OTR texts (SOTR).
    SELECT pgmid, object, obj_name, devclass FROM tadir
      INTO TABLE @DATA(objects)
      FOR ALL ENTRIES IN @packages
      WHERE pgmid    = 'R3TR'
        AND devclass = @packages-table_line
        AND delflag  = @abap_false.

    " Product variants of SAP reports, in the repository of their package.
    variant_setting( IMPORTING pattern = DATA(variant_pattern) package = DATA(variant_package) ).
    IF is_ours( variant_package ) = abap_true.
      DATA(like_pattern) = variant_pattern.
      REPLACE ALL OCCURRENCES OF '*' IN like_pattern WITH '%'.
      SELECT report, variant FROM varid
        INTO TABLE @DATA(product_variants)
        WHERE variant LIKE @like_pattern.
      LOOP AT product_variants INTO DATA(product_variant).
        APPEND VALUE #( pgmid = 'LIMU' object = 'VARX' package = variant_package kind = kind-variant
                        obj_name = |{ product_variant-report WIDTH = 40 }{ product_variant-variant }| ) TO variants.
      ENDLOOP.
    ENDIF.

    LOOP AT objects INTO DATA(object).
      CASE object-object.
        WHEN 'TABL'.
          " Rows of the tables whose content the product ships: SAP marks
          " them as delivered content (delivery class E, S, G). More tables
          " only on purpose, in
          " STVARV select option ZTR_CONTENT_TABLES. Customizing that
          " each system keeps for itself (delivery class C) and
          " application data stay out,
          " even if a system copy once transported them.
          SELECT SINGLE contflag, tabclass FROM dd02l
            INTO @DATA(table_definition)
            WHERE tabname  = @object-obj_name
              AND as4local = 'A'.
          IF sy-subrc = 0 AND table_definition-tabclass = 'TRANSP' AND
             ( table_definition-contflag CA 'ESG' OR object-obj_name IN extra_tables ).
            add_whole_table( CONV #( object-obj_name ) ).
          ENDIF.
        WHEN 'PROG'.
          " Variants of the program, and its ALV layouts.
          SELECT variant FROM varid
            INTO TABLE @DATA(program_variants)
            WHERE report = @object-obj_name.
          LOOP AT program_variants INTO DATA(program_variant).
            APPEND VALUE #( pgmid = 'LIMU' object = 'VARX' package = object-devclass kind = kind-variant
                            obj_name = |{ object-obj_name WIDTH = 40 }{ program_variant-variant }| ) TO variants.
          ENDLOOP.
          APPEND VALUE #( table = 'LTDX'
                          tabkey = |{ sy-mandt }LT{ object-obj_name WIDTH = 40 }*| ) TO keys.
      ENDCASE.

      CLEAR entry.
      entry-kind = kind_of( VALUE e071( pgmid = object-pgmid object = object-object obj_name = object-obj_name ) ).
      IF entry-kind = kind-abapgit OR entry-kind = kind-rows.
        CONTINUE.
      ENDIF.
      entry-pgmid    = object-pgmid.
      entry-object   = object-object.
      entry-obj_name = object-obj_name.
      entry-package  = object-devclass.
      add_entry( entry ).
    ENDLOOP.
  ENDMETHOD.


  METHOD add_transport.
    " Entries without an owner of their own (SAP Note entries, rows of an
    " SAP table whose key names nothing of ours) go where the other
    " objects of the same transport go.
    DATA fallback TYPE devclass.

    SELECT object, obj_name FROM e071
      INTO TABLE @DATA(transport_objects)
      WHERE trkorr = @transport
        AND pgmid  = 'R3TR'.
    LOOP AT transport_objects INTO DATA(transport_object).
      DATA(package) = package_of( object = transport_object-object obj_name = transport_object-obj_name ).
      IF is_ours( package ) = abap_true.
        fallback = package.
        EXIT.
      ENDIF.
    ENDLOOP.

    LOOP AT classify( transport ) INTO DATA(entry).
      IF entry-package IS INITIAL OR entry-package NP zcl_tr_auth=>packages( ).
        entry-package = fallback.
      ENDIF.
      IF entry-package IS NOT INITIAL AND is_ours( entry-package ) = abap_true.
        add_entry( entry ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_whole_table.
    DATA fields       TYPE ty_key_fields.
    DATA client_field TYPE fieldname.

    IF key_fields( EXPORTING table = table IMPORTING fields = fields client_field = client_field ) = abap_false.
      RETURN.
    ENDIF.
    APPEND VALUE #( table = table
                    tabkey = COND #( WHEN client_field IS INITIAL THEN '*' ELSE |{ sy-mandt }*| ) ) TO keys.
  ENDMETHOD.


  METHOD changed.
    DATA gone TYPE ty_files.

    SORT keys BY table tabkey.
    DELETE ADJACENT DUPLICATES FROM keys COMPARING table tabkey.

    DATA(tables) = keys.
    DELETE ADJACENT DUPLICATES FROM tables COMPARING table.
    LOOP AT tables INTO DATA(table).
      table_file( EXPORTING table = table-table CHANGING files = result gone = gone ).
    ENDLOOP.
    LOOP AT variants INTO DATA(variant).
      variant_file( EXPORTING entry = variant CHANGING files = result gone = gone ).
    ENDLOOP.
    LOOP AT notes INTO DATA(note).
      note_file( EXPORTING entry = note CHANGING files = result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD classify.
    DATA entry TYPE ty_entry.

    SELECT * FROM e071
      INTO TABLE @DATA(transport_entries)
      WHERE trkorr = @transport.

    LOOP AT transport_entries INTO DATA(transport_entry).
      CLEAR entry.
      entry-kind = kind_of( transport_entry ).
      IF entry-kind = kind-abapgit.
        CONTINUE.
      ENDIF.
      entry-trkorr   = transport_entry-trkorr.
      entry-pgmid    = transport_entry-pgmid.
      entry-object   = transport_entry-object.
      entry-obj_name = transport_entry-obj_name.
      entry-package  = owner_package( entry = transport_entry entry_kind = entry-kind ).
      APPEND entry TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD classify_request.
    SELECT trkorr FROM e070
      INTO TABLE @DATA(tasks)
      WHERE strkorr = @request.

    result = classify( request ).
    LOOP AT tasks INTO DATA(task).
      APPEND LINES OF classify( task-trkorr ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD constructor.
    me->remote_files = remote_files.
    me->packages     = packages.
  ENDMETHOD.


  METHOD describe.
    result = |{ entry-pgmid } { entry-object } { entry-obj_name }|.
    CONDENSE result.
    IF entry-trkorr IS NOT INITIAL.
      result = |{ result } ({ entry-trkorr })|.
    ENDIF.
  ENDMETHOD.


  METHOD file_name.
    " As abapGit does it: lower case, '/' becomes '#'.
    result = to_lower( condense( name ) ).
    REPLACE ALL OCCURRENCES OF '/' IN result WITH '#'.
    REPLACE ALL OCCURRENCES OF ` ` IN result WITH '_'.
  ENDMETHOD.


  METHOD has_entries.
    result = xsdbool( keys IS NOT INITIAL OR variants IS NOT INITIAL OR
                      notes IS NOT INITIAL OR missing IS NOT INITIAL ).
  ENDMETHOD.


  METHOD is_ours.
    result = xsdbool( line_exists( packages[ table_line = package ] ) ).
  ENDMETHOD.


  METHOD extra_table_range.
    SELECT sign, opti, low, high FROM tvarvc
      INTO TABLE @DATA(selection)
      WHERE name = 'ZTR_CONTENT_TABLES'
        AND type = 'S'.
    LOOP AT selection INTO DATA(row) WHERE low IS NOT INITIAL.
      APPEND VALUE #( sign = row-sign option = row-opti low = row-low high = row-high ) TO result.
    ENDLOOP.
    IF result IS INITIAL.
      " An empty range would take every table.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = '#NONE#' ) TO result.
    ENDIF.
  ENDMETHOD.


  METHOD is_content_variant.
    SELECT SINGLE devclass FROM tadir
      INTO @DATA(package)
      WHERE pgmid    = 'R3TR'
        AND object   = 'PROG'
        AND obj_name = @report
        AND delflag  = @abap_false.
    IF sy-subrc = 0 AND package CP zcl_tr_auth=>packages( ).
      result = abap_true.
      RETURN.
    ENDIF.

    variant_setting( IMPORTING pattern = DATA(pattern) package = DATA(variant_package) ).
    result = xsdbool( pattern IS NOT INITIAL AND variant_package IS NOT INITIAL AND
                      variant_package CP zcl_tr_auth=>packages( ) AND variant CP pattern ).
  ENDMETHOD.


  METHOD is_content_table.
    SELECT SINGLE devclass FROM tadir
      INTO @DATA(package)
      WHERE pgmid    = 'R3TR'
        AND object   = 'TABL'
        AND obj_name = @table
        AND delflag  = @abap_false.
    IF sy-subrc <> 0 OR package NP zcl_tr_auth=>packages( ).
      RETURN.
    ENDIF.

    SELECT SINGLE contflag, tabclass FROM dd02l
      INTO @DATA(definition)
      WHERE tabname  = @table
        AND as4local = 'A'.
    IF sy-subrc <> 0 OR definition-tabclass <> 'TRANSP'.
      RETURN.
    ENDIF.

    DATA(extra_tables) = extra_table_range( ).
    result = xsdbool( definition-contflag CA 'ESG' OR table IN extra_tables ).
  ENDMETHOD.


  METHOD key_fields.
    " The key fields of the table, without the client.
    DATA description TYPE REF TO cl_abap_typedescr.

    CLEAR: fields, client_field.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = table
      RECEIVING
        p_descr_ref    = description
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0 OR description->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.

    DATA(all_fields) = CAST cl_abap_structdescr( description )->get_ddic_field_list( ).
    LOOP AT all_fields INTO DATA(field) WHERE keyflag = abap_true.
      IF field-datatype = client_type AND client_field IS INITIAL AND fields IS INITIAL.
        client_field = field-fieldname.
        CONTINUE.
      ENDIF.
      APPEND field TO fields.
    ENDLOOP.
    result = abap_true.
  ENDMETHOD.


  METHOD key_of.
    " The key as the transport writes it in E071K: the key fields one
    " after the other, each in its full length, without the client.
    DATA buffer   TYPE c LENGTH 255.
    DATA position TYPE i.
    FIELD-SYMBOLS <value> TYPE any.

    LOOP AT fields INTO DATA(field).
      " A key field without a fixed length (string) cannot be part of a
      " transport key; the key ends there, as in E071K.
      IF field-leng <= 0 OR position + field-leng > 255.
        EXIT.
      ENDIF.
      ASSIGN COMPONENT field-fieldname OF STRUCTURE row TO <value>.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      buffer+position(field-leng) = <value>.
      position = position + field-leng.
    ENDLOOP.
    " A table whose only key is the client has an empty key.
    IF position > 0.
      result = buffer(position).
    ENDIF.
  ENDMETHOD.


  METHOD kind_of.
    DATA directory_entry TYPE tadir.
    DATA item            TYPE zif_abapgit_definitions=>ty_item.

    CASE entry-object.
      WHEN 'TABU' OR 'TDAT' OR 'VDAT' OR 'CDAT'.
        result = kind-rows.
        RETURN.
      WHEN 'VARX' OR 'VARI'.
        result = kind-variant.
        RETURN.
      WHEN 'SOTR'.
        result = kind-otr.
        RETURN.
      WHEN 'NOTE' OR 'CINS' OR 'CORR'.
        result = kind-note.
        RETURN.
      WHEN 'NSPC' OR 'RELE' OR 'MERG' OR 'COMM'.
        " Namespace and request administration, no content of its own.
        result = kind-abapgit.
        RETURN.
    ENDCASE.

    " A part of an object (method, report text, translation): its object.
    IF entry-pgmid = 'R3TR'.
      item-obj_type = entry-object.
      item-obj_name = entry-obj_name.
    ELSE.
      CALL FUNCTION 'TR_CHECK_TYPE'
        EXPORTING
          wi_e071  = entry
        IMPORTING
          we_tadir = directory_entry.
      item-obj_type = directory_entry-object.
      item-obj_name = directory_entry-obj_name.
    ENDIF.

    IF item-obj_type IS NOT INITIAL AND zcl_abapgit_objects=>is_supported( item ) = abap_true.
      result = kind-abapgit.
      RETURN.
    ENDIF.

    " Logical transport objects: SAP defines their tables and keys.
    SELECT SINGLE objectname FROM objh
      INTO @DATA(logical_object)
      WHERE objectname = @item-obj_type
        AND objecttype = 'L'.
    IF sy-subrc = 0 AND item-obj_type IS NOT INITIAL.
      result = kind-logical.
      RETURN.
    ENDIF.

    result = kind-uncovered.
  ENDMETHOD.


  METHOD mask_secrets.
    DATA(secrets) = secret_fields( table ).
    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <value> TYPE any.

    IF secrets IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT rows ASSIGNING <row>.
      LOOP AT secrets INTO DATA(secret).
        ASSIGN COMPONENT secret OF STRUCTURE <row> TO <value>.
        IF sy-subrc = 0.
          CLEAR <value>.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD secret_fields.
    DATA description TYPE REF TO cl_abap_typedescr.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = table
      RECEIVING
        p_descr_ref    = description
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0 OR description->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.

    LOOP AT CAST cl_abap_structdescr( description )->get_ddic_field_list( ) INTO DATA(field)
         WHERE keyflag = abap_false.
      DATA(names) = |{ field-fieldname } { field-rollname } { field-domname }|.
      IF names CS 'CRED' OR names CS 'PASS' OR names CS 'PWD' OR names CS 'SECRET' OR
         names CS 'TOKEN' OR names CS 'PRIVATE'.
        APPEND field-fieldname TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD matches.
    " A key in E071K is either exact or generic with '*'.
    DATA(pattern) = condense( CONV string( tabkey ) ).
    IF pattern NA '*'.
      result = xsdbool( key = CONV string( tabkey ) ).
      RETURN.
    ENDIF.
    pattern = CONV string( tabkey ).
    REPLACE ALL OCCURRENCES OF '#' IN pattern WITH '##'.
    REPLACE ALL OCCURRENCES OF '+' IN pattern WITH '#+'.
    result = xsdbool( key CP pattern ).
  ENDMETHOD.


  METHOD note_file.
    " SAP Note entries: which note in which version, not SAP's code.
    TYPES:
      BEGIN OF ty_note,
        pgmid    TYPE e071-pgmid,
        object   TYPE e071-object,
        obj_name TYPE e071-obj_name,
        note     TYPE cwbnthead-numm,
        version  TYPE cwbnthead-versno,
      END OF ty_note.
    DATA note TYPE ty_note.

    note-pgmid    = entry-pgmid.
    note-object   = entry-object.
    note-obj_name = entry-obj_name.
    IF entry-object = 'NOTE'.
      note-note = entry-obj_name.
      SELECT versno FROM cwbnthead UP TO 1 ROWS
        INTO @note-version
        WHERE numm = @note-note
        ORDER BY versno DESCENDING.
      ENDSELECT.
    ENDIF.

    TRY.
        DATA(json) = zcl_abapgit_ajson=>create_empty( iv_keep_item_order = abap_true
          )->set( iv_path = '/' iv_val = note )->stringify( iv_indent = 2 ).
        to_file( EXPORTING path = |{ folder }notes/|
                           filename = |{ file_name( entry-object ) }.{ file_name( entry-obj_name ) }.json|
                           json = json
                 CHANGING files = files ).
      CATCH zcx_abapgit_ajson_error.
        APPEND entry TO missing.
    ENDTRY.
  ENDMETHOD.


  METHOD owner_package.
    " The package decides the repository. For table rows it is the
    " package of the table; for rows of an SAP table (TVDIR, TDDAT, ...)
    " it is the package of the object the key names.
    CASE entry_kind.
      WHEN kind-rows.
        result = package_of( obj_name = entry-obj_name ).
        IF result IS INITIAL OR result NP zcl_tr_auth=>packages( ).
          SELECT tabkey FROM e071k UP TO 1 ROWS
            INTO @DATA(tabkey)
            WHERE trkorr   = @entry-trkorr
              AND mastername = @entry-obj_name.
          ENDSELECT.
          IF sy-subrc = 0 AND strlen( tabkey ) > 3.
            " The first key field after the client, as far as it goes.
            DATA(name) = condense( substring( val = tabkey off = 3
                                              len = nmin( val1 = 30 val2 = strlen( tabkey ) - 3 ) ) ).
            DATA(own) = package_of( obj_name = name ).
            IF own IS INITIAL.
              own = package_of( obj_name = condense( substring( val = tabkey
                                                                len = nmin( val1 = 30 val2 = strlen( tabkey ) ) ) ) ).
            ENDIF.
            IF own IS NOT INITIAL.
              result = own.
            ENDIF.
          ENDIF.
        ENDIF.
      WHEN kind-variant.
        " LIMU VARX: report (40 characters) and variant. A product variant of
        " an SAP report belongs to the package that maintains the variants.
        result = package_of( object = 'PROG' obj_name = entry-obj_name(40) ).
        IF result IS INITIAL OR result NP zcl_tr_auth=>packages( ).
          variant_setting( IMPORTING pattern = DATA(variant_pattern) package = DATA(variant_package) ).
          IF condense( entry-obj_name+40 ) CP variant_pattern.
            result = variant_package.
          ENDIF.
        ENDIF.
      WHEN kind-otr.
        " R3TR SOTR <package>: the texts of that package.
        result = CONV #( entry-obj_name ).
      WHEN OTHERS.
        result = package_of( object = entry-object obj_name = entry-obj_name ).
    ENDCASE.
  ENDMETHOD.


  METHOD package_of.
    IF object IS SUPPLIED AND object IS NOT INITIAL.
      SELECT SINGLE devclass FROM tadir
        INTO @result
        WHERE pgmid    = 'R3TR'
          AND object   = @object
          AND obj_name = @obj_name.
    ELSE.
      SELECT devclass FROM tadir UP TO 1 ROWS
        INTO @result
        WHERE pgmid    = 'R3TR'
          AND obj_name = @obj_name.
      ENDSELECT.
    ENDIF.
  ENDMETHOD.


  METHOD read_rows.
    " The rows of one key from the database. The table name comes from
    " the transport or from SAP's object definitions, never from a user,
    " and is checked against the dictionary; values are quoted.
    DATA where TYPE string.
    DATA tabkey_rest TYPE string.

    SELECT SINGLE tabname FROM dd02l
      INTO @DATA(existing)
      WHERE tabname  = @table
        AND as4local = 'A'
        AND tabclass IN ('TRANSP','CLUSTER','POOL').
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    tabkey_rest = tabkey.
    IF client_field IS NOT INITIAL.
      where = |{ client_field } = { cl_abap_dyn_prg=>quote( substring( val = tabkey len = 3 ) ) }|.
      tabkey_rest = substring( val = tabkey off = 3 ).
    ENDIF.

    " Narrow the selection by the first key field; the rest is compared
    " with the key below.
    READ TABLE fields INTO DATA(first) INDEX 1.
    IF sy-subrc = 0 AND tabkey_rest IS NOT INITIAL AND first-leng > 0.
      DATA(value) = substring( val = tabkey_rest len = nmin( val1 = first-leng val2 = strlen( tabkey_rest ) ) ).
      DATA(star) = find( val = value sub = '*' ).
      IF star < 0 AND strlen( value ) = first-leng.
        where = |{ where }{ COND #( WHEN where IS NOT INITIAL THEN ` AND ` ) }| &&
                |{ first-fieldname } = { cl_abap_dyn_prg=>quote( value ) }|.
      ELSEIF star > 0 OR ( star < 0 AND value IS NOT INITIAL ).
        DATA(prefix) = COND string( WHEN star > 0 THEN substring( val = value len = star ) ELSE value ).
        REPLACE ALL OCCURRENCES OF '#' IN prefix WITH '##'.
        REPLACE ALL OCCURRENCES OF '%' IN prefix WITH '#%'.
        REPLACE ALL OCCURRENCES OF '_' IN prefix WITH '#_'.
        where = |{ where }{ COND #( WHEN where IS NOT INITIAL THEN ` AND ` ) }| &&
                |{ first-fieldname } LIKE { cl_abap_dyn_prg=>quote( |{ prefix }%| ) } ESCAPE '#'|.
      ENDIF.
    ENDIF.

    TRY.
        IF client_field IS NOT INITIAL.
          SELECT * FROM (table) CLIENT SPECIFIED INTO TABLE rows WHERE (where).
        ELSEIF where IS INITIAL.
          SELECT * FROM (table) INTO TABLE rows.
        ELSE.
          SELECT * FROM (table) INTO TABLE rows WHERE (where).
        ENDIF.
      CATCH cx_sy_dynamic_osql_error.
        CLEAR rows.
        RETURN.
    ENDTRY.

    " Keep exactly the rows of the key.
    DATA(pattern) = COND string( WHEN client_field IS INITIAL THEN tabkey ELSE tabkey_rest ).
    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      IF matches( key = key_of( row = <row> fields = fields ) tabkey = pattern ) = abap_false.
        DELETE rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD remote_text.
    READ TABLE remote_files INTO DATA(remote) WITH KEY file_path COMPONENTS path = path filename = filename.
    IF sy-subrc = 0.
      TRY.
          result = zcl_abapgit_convert=>xstring_to_string_utf8( remote-data ).
        CATCH zcx_abapgit_exception.
          CLEAR result.
      ENDTRY.
    ENDIF.
  ENDMETHOD.


  METHOD removed.
    DATA files TYPE ty_files.

    SORT keys BY table tabkey.
    DELETE ADJACENT DUPLICATES FROM keys COMPARING table tabkey.

    DATA(tables) = keys.
    DELETE ADJACENT DUPLICATES FROM tables COMPARING table.
    LOOP AT tables INTO DATA(table).
      table_file( EXPORTING table = table-table CHANGING files = files gone = result ).
    ENDLOOP.
    LOOP AT variants INTO DATA(variant).
      variant_file( EXPORTING entry = variant CHANGING files = files gone = result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD table_file.
    " content/tables/<table>.json: the rows already in Git, minus the rows
    " of the keys of this transport, plus their rows as they are now. So
    " a deleted row leaves the file, and rows of other keys stay.
    DATA fields       TYPE ty_key_fields.
    DATA client_field TYPE fieldname.
    DATA rows         TYPE REF TO data.
    DATA current      TYPE REF TO data.
    DATA order        TYPE abap_sortorder_tab.
    DATA seen         TYPE ty_strings.
    FIELD-SYMBOLS <rows>    TYPE STANDARD TABLE.
    FIELD-SYMBOLS <current> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <row>     TYPE any.
    FIELD-SYMBOLS <client>  TYPE any.

    IF key_fields( EXPORTING table = table IMPORTING fields = fields client_field = client_field ) = abap_false.
      RETURN.
    ENDIF.

    DATA(path)     = |{ folder }tables/|.
    DATA(filename) = |{ file_name( table ) }.json|.
    DATA(table_keys) = VALUE ty_keys( FOR k IN keys WHERE ( table = table ) ( k ) ).

    CREATE DATA rows TYPE STANDARD TABLE OF (table).
    ASSIGN rows->* TO <rows>.
    CREATE DATA current TYPE STANDARD TABLE OF (table).
    ASSIGN current->* TO <current>.

    " What Git has. A file that no longer fits the table starts over.
    DATA(old_json) = remote_text( path = path filename = filename ).
    IF old_json IS NOT INITIAL.
      TRY.
          zcl_abapgit_ajson=>parse( old_json )->to_abap( IMPORTING ev_container = <rows> ).
        CATCH zcx_abapgit_ajson_error.
          CLEAR <rows>.
      ENDTRY.
    ENDIF.

    " Out with the rows of the transported keys ...
    LOOP AT <rows> ASSIGNING <row>.
      DATA(row_index) = sy-tabix.
      DATA(row_key) = key_of( row = <row> fields = fields ).
      DATA(is_transported) = abap_false.
      LOOP AT table_keys INTO DATA(table_key).
        DATA(pattern) = COND string( WHEN client_field IS INITIAL THEN table_key-tabkey
                                     ELSE substring( val = table_key-tabkey off = 3 ) ).
        IF matches( key = row_key tabkey = pattern ) = abap_true.
          is_transported = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF is_transported = abap_true.
        DELETE <rows> INDEX row_index.
      ENDIF.
    ENDLOOP.
    LOOP AT <rows> ASSIGNING <row>.
      INSERT key_of( row = <row> fields = fields ) INTO TABLE seen.
    ENDLOOP.

    " ... and in with their rows as they are on the system now.
    LOOP AT table_keys INTO table_key.
      CLEAR <current>.
      read_rows( EXPORTING table = table tabkey = table_key-tabkey fields = fields client_field = client_field
                 CHANGING rows = <current> ).
      LOOP AT <current> ASSIGNING <row>.
        row_key = key_of( row = <row> fields = fields ).
        INSERT row_key INTO TABLE seen.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        IF client_field IS NOT INITIAL.
          " Git holds the delivered content, not the client it came from.
          ASSIGN COMPONENT client_field OF STRUCTURE <row> TO <client>.
          CLEAR <client>.
        ENDIF.
        APPEND <row> TO <rows>.
      ENDLOOP.
    ENDLOOP.

    IF <rows> IS INITIAL.
      IF old_json IS NOT INITIAL.
        APPEND VALUE #( path = path filename = filename ) TO gone.
      ENDIF.
      RETURN.
    ENDIF.

    mask_secrets( EXPORTING table = table CHANGING rows = <rows> ).

    order = VALUE #( FOR f IN fields ( name = f-fieldname ) ).
    SORT <rows> BY (order).

    TRY.
        DATA(json) = zcl_abapgit_ajson=>create_empty( iv_keep_item_order = abap_true
          )->set( iv_path = '/' iv_val = <rows> )->stringify( iv_indent = 2 ).
      CATCH zcx_abapgit_ajson_error.
        APPEND VALUE #( object = 'TABU' obj_name = table kind = kind-uncovered ) TO missing.
        RETURN.
    ENDTRY.
    to_file( EXPORTING path = path filename = filename json = json CHANGING files = files ).
  ENDMETHOD.


  METHOD to_file.
    " Only what differs from Git; same newline at the end as an editor.
    DATA(text) = |{ json }\n|.
    IF text = remote_text( path = path filename = filename ).
      RETURN.
    ENDIF.
    TRY.
        APPEND VALUE #( path = path filename = filename
                        data = zcl_abapgit_convert=>string_to_xstring_utf8( text ) ) TO files.
      CATCH zcx_abapgit_exception.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  METHOD uncovered.
    result = missing.
  ENDMETHOD.


  METHOD variant_file.
    " content/variants/<report>.<variant>.json: header, texts and the
    " values in readable form.
    DATA values TYPE STANDARD TABLE OF rsparams WITH DEFAULT KEY.

    DATA(report)  = entry-obj_name(40).
    DATA(variant) = CONV rsvar-variant( entry-obj_name+40 ).
    DATA(path)     = |{ folder }variants/|.
    DATA(filename) = |{ file_name( report ) }.{ file_name( variant ) }.json|.

    SELECT SINGLE * FROM varid
      INTO @DATA(header)
      WHERE report  = @report
        AND variant = @variant.
    IF sy-subrc <> 0.
      IF remote_text( path = path filename = filename ) IS NOT INITIAL.
        APPEND VALUE #( path = path filename = filename ) TO gone.
      ENDIF.
      RETURN.
    ENDIF.
    SELECT * FROM varit
      INTO TABLE @DATA(texts)
      WHERE report  = @report
        AND variant = @variant
      ORDER BY PRIMARY KEY.

    " Readable values need the selection screen of the report. A system
    " can hold variants of reports it does not have (variants of
    " SAP reports on a system that has not got the component): then the stored
    " value records themselves, complete but not readable.
    SELECT SINGLE name FROM trdir
      INTO @DATA(program)
      WHERE name = @report.
    IF sy-subrc = 0.
      CALL FUNCTION 'RS_VARIANT_CONTENTS'
        EXPORTING
          report               = report
          variant              = variant
        TABLES
          valutab              = values
        EXCEPTIONS
          variant_non_existent = 1
          variant_obsolete     = 2
          OTHERS               = 3.
      IF sy-subrc <> 0.
        CLEAR values.
      ENDIF.
    ELSE.
      SELECT * FROM vari
        INTO TABLE @DATA(raw_values)
        WHERE report  = @report
          AND variant = @variant
        ORDER BY PRIMARY KEY.
      LOOP AT raw_values ASSIGNING FIELD-SYMBOL(<raw>).
        CLEAR: <raw>-mandt, <raw>-vdate, <raw>-vtime.
      ENDLOOP.
    ENDIF.

    " Nothing that changes with every save and says nothing about the content.
    CLEAR: header-mandt, header-aedat, header-aetime, header-aename, header-edat, header-etime, header-ename.
    LOOP AT texts ASSIGNING FIELD-SYMBOL(<text>).
      CLEAR <text>-mandt.
    ENDLOOP.

    TRY.
        DATA(json) = zcl_abapgit_ajson=>create_empty( iv_keep_item_order = abap_true ).
        json->set( iv_path = '/header' iv_val = header ).
        json->set( iv_path = '/texts'  iv_val = texts ).
        IF values IS NOT INITIAL.
          json->set( iv_path = '/values' iv_val = values ).
        ENDIF.
        IF raw_values IS NOT INITIAL.
          json->set( iv_path = '/raw_values' iv_val = raw_values ).
        ENDIF.
        to_file( EXPORTING path = path filename = filename json = json->stringify( iv_indent = 2 )
                 CHANGING files = files ).
      CATCH zcx_abapgit_ajson_error.
        APPEND entry TO missing.
    ENDTRY.
  ENDMETHOD.


  METHOD variant_setting.
    SELECT SINGLE low FROM tvarvc INTO @DATA(value)
      WHERE name = 'ZTR_VARIANT_PATTERN' AND type = 'P'.
    pattern = COND #( WHEN value IS NOT INITIAL THEN condense( CONV string( value ) ) ELSE default_variant_pattern ).
    CLEAR value.
    SELECT SINGLE low FROM tvarvc INTO @value
      WHERE name = 'ZTR_VARIANT_PACKAGE' AND type = 'P'.
    package = COND #( WHEN value IS NOT INITIAL THEN CONV devclass( value ) ELSE default_variant_package ).
  ENDMETHOD.
ENDCLASS.
