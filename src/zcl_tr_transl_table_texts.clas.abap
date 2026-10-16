"! Texts in table entries: tables with a language in their key (text
"! tables such as /MYNS/TEXTS or the notification templates) hold
"! texts that the user sees, and SE63 does not list them with the other
"! texts of the object. An entry that exists in one required language and
"! not in another is missing its translation.
"!
"! Only the entries of the current client are read (at most
"! MAX_ROWS per table). The text shown is the first character field of
"! the entry that is not part of the key. The entries are translated in
"! the maintenance view (SM30) in the logon language, or in SE63
"! (menu Translation, ABAP Objects, Transport Object: the TABU entries).
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_table_texts DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_finding,
        tabname         TYPE tabname,
        devclass        TYPE devclass,
        entry_key       TYPE string,
        language        TYPE spras,
        source_language TYPE spras,
        source_text     TYPE string,
      END OF ty_finding.
    TYPES ty_findings TYPE STANDARD TABLE OF ty_finding WITH DEFAULT KEY.

    CONSTANTS max_rows TYPE i VALUE 50000.

    "! @parameter languages | the required languages
    METHODS constructor
      IMPORTING
        languages TYPE zcl_tr_transl_check=>ty_languages.
    "! The entries without translation of the tables among the objects.
    "! Objects that are not transparent tables with a language key are
    "! skipped.
    METHODS check_objects
      IMPORTING
        objects       TYPE zcl_tr_transl_check=>ty_objects
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! The entries without translation of one table, from its rows.
    "! @parameter rows | the rows of the table, any line type
    "! @parameter key_fields | key fields without client and language
    "! @parameter language_field | the language key field
    "! @parameter text_field | the field whose text is shown; may be empty
    METHODS check_rows
      IMPORTING
        rows           TYPE ANY TABLE
        key_fields     TYPE string_table
        language_field TYPE fieldname
        text_field     TYPE fieldname
      RETURNING
        VALUE(result)  TYPE ty_findings.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_entry,
        entry_key TYPE string,
        language  TYPE spras,
        text      TYPE string,
      END OF ty_entry.
    TYPES ty_entries TYPE SORTED TABLE OF ty_entry WITH UNIQUE KEY entry_key language.

    DATA languages TYPE zcl_tr_transl_check=>ty_languages.

    METHODS check_table
      IMPORTING
        tabname       TYPE tabname
        devclass      TYPE devclass
      RETURNING
        VALUE(result) TYPE ty_findings.
ENDCLASS.



CLASS zcl_tr_transl_table_texts IMPLEMENTATION.


  METHOD constructor.
    me->languages = languages.
  ENDMETHOD.


  METHOD check_objects.
    IF lines( languages ) < 2.
      " With one language nothing can be missing.
      RETURN.
    ENDIF.
    LOOP AT objects INTO DATA(object) WHERE object = 'TABL'.
      DATA(tabname) = CONV tabname( object-obj_name ).
      SELECT SINGLE tabclass FROM dd02l
        INTO @DATA(table_class)
        WHERE tabname  = @tabname
          AND as4local = 'A'.
      IF sy-subrc <> 0 OR table_class <> 'TRANSP'.
        CONTINUE.
      ENDIF.
      SELECT SINGLE devclass FROM tadir
        INTO @DATA(devclass)
        WHERE pgmid    = 'R3TR'
          AND object   = 'TABL'
          AND obj_name = @object-obj_name.
      APPEND LINES OF check_table( tabname = tabname devclass = devclass ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_table.
    DATA key_fields     TYPE string_table.
    DATA language_field TYPE fieldname.
    DATA text_field     TYPE fieldname.
    DATA rows           TYPE REF TO data.
    FIELD-SYMBOLS <rows> TYPE STANDARD TABLE.

    SELECT fieldname, keyflag, datatype, position FROM dd03l
      INTO TABLE @DATA(fields)
      WHERE tabname  = @tabname
        AND as4local = 'A'
        AND fieldname NOT LIKE '.%'
      ORDER BY position.
    " The client is not part of an entry: only the current one is read.
    LOOP AT fields INTO DATA(field) WHERE datatype <> 'CLNT'.
      IF field-keyflag = abap_true.
        IF field-datatype = 'LANG'.
          language_field = field-fieldname.
        ELSE.
          APPEND CONV string( field-fieldname ) TO key_fields.
        ENDIF.
      ELSEIF text_field IS INITIAL AND ( field-datatype = 'CHAR' OR field-datatype = 'SSTR' OR field-datatype = 'STRG' ).
        text_field = field-fieldname.
      ENDIF.
    ENDLOOP.
    IF language_field IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        CREATE DATA rows TYPE STANDARD TABLE OF (tabname).
        ASSIGN rows->* TO <rows>.
        SELECT * FROM (tabname) INTO TABLE @<rows> UP TO @max_rows ROWS.
      CATCH cx_sy_create_data_error cx_sy_dynamic_osql_error.
        RETURN.
    ENDTRY.

    result = check_rows( rows = <rows> key_fields = key_fields language_field = language_field text_field = text_field ).
    LOOP AT result ASSIGNING FIELD-SYMBOL(<finding>).
      <finding>-tabname  = tabname.
      <finding>-devclass = devclass.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_rows.
    DATA entries TYPE ty_entries.
    DATA keys    TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT rows ASSIGNING FIELD-SYMBOL(<row>).
      DATA(entry_key) = ``.
      LOOP AT key_fields INTO DATA(key_field).
        ASSIGN COMPONENT key_field OF STRUCTURE <row> TO FIELD-SYMBOL(<value>).
        IF sy-subrc = 0.
          entry_key = COND #( WHEN entry_key IS INITIAL THEN condense( CONV string( <value> ) )
                              ELSE |{ entry_key } / { condense( CONV string( <value> ) ) }| ).
        ENDIF.
      ENDLOOP.
      ASSIGN COMPONENT language_field OF STRUCTURE <row> TO FIELD-SYMBOL(<language>).
      IF sy-subrc <> 0 OR <language> IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(text) = ``.
      IF text_field IS NOT INITIAL.
        ASSIGN COMPONENT text_field OF STRUCTURE <row> TO FIELD-SYMBOL(<text>).
        IF sy-subrc = 0.
          text = <text>.
        ENDIF.
      ENDIF.
      INSERT VALUE #( entry_key = entry_key language = <language> text = text ) INTO TABLE entries.
      INSERT entry_key INTO TABLE keys.
    ENDLOOP.

    " An entry that is in none of the required languages is not a text of
    " the product (a customer entry in Romanian, for example).
    LOOP AT keys INTO DATA(key).
      DATA(source) = VALUE ty_entry( ).
      LOOP AT languages INTO DATA(language).
        READ TABLE entries INTO source WITH TABLE KEY entry_key = key language = language.
        IF sy-subrc = 0.
          EXIT.
        ENDIF.
      ENDLOOP.
      IF source IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT languages INTO language.
        IF NOT line_exists( entries[ entry_key = key language = language ] ).
          APPEND VALUE #( entry_key = key language = language
                          source_language = source-language source_text = source-text ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
