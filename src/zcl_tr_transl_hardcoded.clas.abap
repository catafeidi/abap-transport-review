"! Hardcoded texts: literals in the source code that the user sees when
"! the product runs. They cannot be translated, because a literal is not
"! a text of SE63: the fix is in the code (a message of a message class,
"! or a text symbol such as TEXT-001 or 'Text'(001)), then it is
"! translated like the other texts.
"!
"! What is found, per statement of every include of the object:
"!   message      MESSAGE 'literal' TYPE ..., or a string template
"!   message text a literal with words after WITH of a MESSAGE statement
"!   list output  a literal in WRITE
"!   title        a literal after WITH of SET TITLEBAR
"!   screen text  a literal given to a parameter or field that is shown:
"!                popups (TITEL, TITLEBAR, TEXT_QUESTION, TXT1, ...), ALV
"!                (COLTEXT, SCRTEXT_*, GRID_TITLE, ...), SALV (SET_LONG_TEXT,
"!                SET_LIST_HEADER, ...), exception texts (TEXT = '...')
"!   text constant CONSTANTS ... VALUE 'literal with words': only shown for a
"!                review, many are technical
"! A literal with a text symbol ('Text'(001)) is translatable and not
"! listed. A literal that is first put into a variable and shown later is
"! not found: the list is a help for the review, not a proof.
"! ABAP 7.40 syntax.
CLASS zcl_tr_transl_hardcoded DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_kind TYPE c LENGTH 15.
    TYPES:
      BEGIN OF ty_finding,
        object   TYPE trobjtype,
        obj_name TYPE trobj_name,
        devclass TYPE devclass,
        include  TYPE progname,
        line     TYPE i,
        kind     TYPE ty_kind,
        text     TYPE string,
      END OF ty_finding.
    TYPES ty_findings TYPE STANDARD TABLE OF ty_finding WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF kind,
        message       TYPE ty_kind VALUE 'message',
        message_text  TYPE ty_kind VALUE 'message text',
        generic_message TYPE ty_kind VALUE 'message 00',
        list_output   TYPE ty_kind VALUE 'list output',
        title         TYPE ty_kind VALUE 'title',
        screen_text   TYPE ty_kind VALUE 'screen text',
        text_constant TYPE ty_kind VALUE 'text constant',
      END OF kind.

    "! The hardcoded texts of one source. OBJECT, OBJ_NAME, DEVCLASS and
    "! INCLUDE stay empty; LINE is the line in SOURCE.
    METHODS scan_source
      IMPORTING
        source        TYPE string_table
      RETURNING
        VALUE(result) TYPE ty_findings.
    "! The hardcoded texts of programs, function groups and classes; other
    "! object types have no source and are skipped.
    METHODS check_objects
      IMPORTING
        objects       TYPE zcl_tr_transl_check=>ty_objects
      RETURNING
        VALUE(result) TYPE ty_findings.

  PRIVATE SECTION.
    TYPES ty_tokens TYPE STANDARD TABLE OF stokes WITH DEFAULT KEY.
    TYPES ty_names TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    CONSTANTS letters TYPE string VALUE `ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzÄÖÜäöüß`.

    METHODS main_program
      IMPORTING
        object        TYPE zcl_tr_transl_check=>ty_object
      RETURNING
        VALUE(result) TYPE progname.
    METHODS includes
      IMPORTING
        program       TYPE progname
        obj_name      TYPE trobj_name
      RETURNING
        VALUE(result) TYPE string_table.
    METHODS belongs_to
      IMPORTING
        include       TYPE csequence
        obj_name      TYPE trobj_name
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS package_of
      IMPORTING
        object        TYPE zcl_tr_transl_check=>ty_object
      RETURNING
        VALUE(result) TYPE devclass.
    METHODS merge_templates
      IMPORTING
        tokens        TYPE ty_tokens
      RETURNING
        VALUE(result) TYPE ty_tokens.
    METHODS scan_statement
      IMPORTING
        tokens   TYPE ty_tokens
      CHANGING
        findings TYPE ty_findings.
    METHODS add
      IMPORTING
        token    TYPE stokes
        kind     TYPE ty_kind
        text     TYPE string OPTIONAL
      CHANGING
        findings TYPE ty_findings.
    METHODS is_generic_message
      IMPORTING
        tokens        TYPE ty_tokens
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS statement_text
      IMPORTING
        tokens        TYPE ty_tokens
      RETURNING
        VALUE(result) TYPE string.
    METHODS is_literal
      IMPORTING
        token         TYPE stokes
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS text_of
      IMPORTING
        token         TYPE stokes
      RETURNING
        VALUE(result) TYPE string.
    METHODS has_words
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS has_letters
      IMPORTING
        text          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS shown_parameters
      RETURNING
        VALUE(result) TYPE ty_names.
    METHODS shown_methods
      RETURNING
        VALUE(result) TYPE ty_names.
    METHODS last_part
      IMPORTING
        name          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS without_expressions
      IMPORTING
        text          TYPE string
        placeholder   TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS namespace_of
      IMPORTING
        name          TYPE csequence
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.



CLASS zcl_tr_transl_hardcoded IMPLEMENTATION.


  METHOD check_objects.
    DATA source TYPE string_table.

    LOOP AT objects INTO DATA(object).
      DATA(program) = main_program( object ).
      IF program IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(devclass) = package_of( object ).
      DATA(include_names) = includes( program = program obj_name = object-obj_name ).
      LOOP AT include_names INTO DATA(include_name).
        DATA(include) = CONV progname( include_name ).
        CLEAR source.
        READ REPORT include INTO source.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        DATA(source_findings) = scan_source( source ).
        LOOP AT source_findings INTO DATA(finding).
          finding-object   = object-object.
          finding-obj_name = object-obj_name.
          finding-devclass = devclass.
          finding-include  = include.
          APPEND finding TO result.
        ENDLOOP.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD main_program.
    result = zcl_tr_transl_check=>main_program( object ).
  ENDMETHOD.


  METHOD includes.
    " The main program and its includes, without the SAP includes that a
    " generated maintenance dialog or a function group pulls in.
    DATA include_names TYPE STANDARD TABLE OF progname WITH DEFAULT KEY.

    CALL FUNCTION 'RS_GET_ALL_INCLUDES'
      EXPORTING
        program      = program
      TABLES
        includetab   = include_names
      EXCEPTIONS
        not_existent = 1
        no_program   = 2
        OTHERS       = 3.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    APPEND program TO result.
    LOOP AT include_names INTO DATA(include).
      IF belongs_to( include = include obj_name = obj_name ) = abap_true.
        APPEND CONV string( include ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD belongs_to.
    " Same namespace as the object; without namespace, a customer name.
    DATA(namespace) = namespace_of( obj_name ).
    IF namespace IS NOT INITIAL.
      result = xsdbool( include CP |{ namespace }*| ).
    ELSEIF obj_name(1) <> '/'.
      result = xsdbool( include CP 'Z*' OR include CP 'Y*' OR include CP 'LZ*' OR include CP 'LY*' ).
    ENDIF.
  ENDMETHOD.


  METHOD package_of.
    SELECT SINGLE devclass FROM tadir
      INTO @result
      WHERE pgmid    = 'R3TR'
        AND object   = @object-object
        AND obj_name = @object-obj_name.
  ENDMETHOD.


  METHOD scan_source.
    DATA tokens     TYPE ty_tokens.
    DATA statements TYPE STANDARD TABLE OF sstmnt WITH DEFAULT KEY.

    SCAN ABAP-SOURCE source TOKENS INTO tokens STATEMENTS INTO statements.
    IF sy-subrc <> 0.
      " A source that does not scan (an include of macros, for example)
      " has nothing to show here.
      RETURN.
    ENDIF.
    LOOP AT statements INTO DATA(statement) WHERE from > 0.
      IF statement-to < statement-from.
        CONTINUE.
      ENDIF.
      DATA(statement_tokens) = VALUE ty_tokens( FOR index = statement-from THEN index + 1 UNTIL index > statement-to
                                                ( tokens[ index ] ) ).
      scan_statement(
        EXPORTING
          tokens   = merge_templates( statement_tokens )
        CHANGING
          findings = result ).
    ENDLOOP.
  ENDMETHOD.


  METHOD merge_templates.
    " SCAN splits a string template into its parts: |File { name } not
    " found| comes as |, `File `, {, NAME, }, ` not found`, |. The parts
    " become one token again, |File {...} not found|: the text parts as
    " they are, each embedded expression as {...}.
    DATA template TYPE stokes.
    DATA depth    TYPE i.

    LOOP AT tokens INTO DATA(token).
      IF template IS INITIAL.
        IF token-str = `|`.
          template = token.
        ELSE.
          APPEND token TO result.
        ENDIF.
        CONTINUE.
      ENDIF.
      CASE token-str.
        WHEN `|`.
          IF depth = 0.
            template-str = template-str && `|`.
            APPEND template TO result.
            CLEAR template.
          ENDIF.
        WHEN `{`.
          IF depth = 0.
            template-str = template-str && `{...}`.
          ENDIF.
          depth = depth + 1.
        WHEN `}`.
          depth = depth - 1.
        WHEN OTHERS.
          DATA(length) = strlen( token-str ).
          IF depth = 0 AND length >= 2 AND token-str(1) = '`'.
            template-str = template-str && substring( val = token-str off = 1 len = length - 2 ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
    IF template IS NOT INITIAL.
      APPEND template TO result.
    ENDIF.
  ENDMETHOD.


  METHOD scan_statement.
    DATA(keyword) = to_upper( tokens[ 1 ]-str ).
    DATA(count) = lines( tokens ).
    DATA(parameters) = shown_parameters( ).
    DATA(methods) = shown_methods( ).
    DATA(after_with) = abap_false.

    CASE keyword.
      WHEN 'MESSAGE'.
        IF is_generic_message( tokens ) = abap_true.
          add( EXPORTING token = tokens[ 1 ] kind = kind-generic_message text = statement_text( tokens )
               CHANGING findings = findings ).
          RETURN.
        ENDIF.
        IF count >= 2 AND is_literal( tokens[ 2 ] ) = abap_true AND has_letters( text_of( tokens[ 2 ] ) ) = abap_true.
          add( EXPORTING token = tokens[ 2 ] kind = kind-message CHANGING findings = findings ).
        ENDIF.
        LOOP AT tokens INTO DATA(token) FROM 3.
          IF to_upper( token-str ) = 'WITH'.
            after_with = abap_true.
          ELSEIF after_with = abap_true AND is_literal( token ) = abap_true AND has_words( text_of( token ) ) = abap_true.
            add( EXPORTING token = token kind = kind-message_text CHANGING findings = findings ).
          ENDIF.
        ENDLOOP.
        RETURN.
      WHEN 'WRITE'.
        LOOP AT tokens INTO token FROM 2.
          DATA(write_position) = sy-tabix.
          " USING EDIT MASK '==ALPHA' is a format, not a text.
          IF is_literal( token ) = abap_true AND has_letters( text_of( token ) ) = abap_true
             AND to_upper( tokens[ write_position - 1 ]-str ) <> 'MASK'.
            add( EXPORTING token = token kind = kind-list_output CHANGING findings = findings ).
          ENDIF.
        ENDLOOP.
        RETURN.
      WHEN 'SET'.
        IF count >= 2 AND to_upper( tokens[ 2 ]-str ) = 'TITLEBAR'.
          LOOP AT tokens INTO token FROM 3.
            IF to_upper( token-str ) = 'WITH'.
              after_with = abap_true.
            ELSEIF after_with = abap_true AND is_literal( token ) = abap_true AND has_letters( text_of( token ) ) = abap_true.
              add( EXPORTING token = token kind = kind-title CHANGING findings = findings ).
            ENDIF.
          ENDLOOP.
        ENDIF.
        RETURN.
      WHEN 'CONSTANTS'.
        LOOP AT tokens INTO token FROM 2.
          DATA(position) = sy-tabix.
          IF position > 2 AND to_upper( tokens[ position - 1 ]-str ) = 'VALUE' AND is_literal( token ) = abap_true
             AND has_words( text_of( token ) ) = abap_true.
            add( EXPORTING token = token kind = kind-text_constant CHANGING findings = findings ).
          ENDIF.
        ENDLOOP.
        RETURN.
    ENDCASE.

    " Any other statement: a literal given to a parameter or field that is
    " shown (name = 'literal'), or to a method that sets a shown text
    " (set_long_text( 'literal' )).
    LOOP AT tokens INTO token.
      position = sy-tabix.
      IF position < 2 OR is_literal( token ) = abap_false OR has_letters( text_of( token ) ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(previous) = to_upper( tokens[ position - 1 ]-str ).
      IF previous = '=' AND position > 2.
        IF line_exists( parameters[ table_line = last_part( to_upper( tokens[ position - 2 ]-str ) ) ] ).
          add( EXPORTING token = token kind = kind-screen_text CHANGING findings = findings ).
        ENDIF.
      ELSEIF previous CP '*('.
        DATA(method) = last_part( substring( val = previous len = strlen( previous ) - 1 ) ).
        IF line_exists( methods[ table_line = method ] ).
          add( EXPORTING token = token kind = kind-screen_text CHANGING findings = findings ).
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add.
    APPEND VALUE #( line = token-row kind = kind
                    text = COND #( WHEN text IS SUPPLIED THEN text ELSE text_of( token ) ) ) TO findings.
  ENDMETHOD.


  METHOD is_generic_message.
    " A message of class 00 (001 is "&1&2&3&4") shows whatever its
    " variables hold: MESSAGE ID '00' ... or MESSAGE e001(00).
    LOOP AT tokens INTO DATA(token) FROM 2.
      DATA(position) = sy-tabix.
      DATA(word) = to_upper( token-str ).
      IF word = 'ID' AND position < lines( tokens ) AND tokens[ position + 1 ]-str = `'00'`.
        result = abap_true.
        RETURN.
      ENDIF.
      " E001(00): type, number, class 00.
      IF strlen( word ) = 8 AND word(1) CA `AEISWX` AND word+1(3) CO `0123456789` AND word+4(4) = `(00)`.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD statement_text.
    " The statement as it is written, for the reviewer.
    LOOP AT tokens INTO DATA(token).
      result = COND #( WHEN result IS INITIAL THEN token-str ELSE |{ result } { token-str }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD is_literal.
    " 'text', `text` or a string template; not 'text'(001), which has a
    " text symbol and is translated.
    DATA(text) = token-str.
    IF text IS INITIAL.
      RETURN.
    ENDIF.
    CASE text(1).
      WHEN `'`.
        " 'text'(001): a quote, an opening bracket, three characters and
        " the closing bracket at the end.
        DATA(length) = strlen( text ).
        result = xsdbool( NOT ( length >= 7
                                AND substring( val = text off = length - 6 len = 2 ) = `'(`
                                AND substring( val = text off = length - 1 len = 1 ) = `)` ) ).
      WHEN '`' OR '|'.
        result = abap_true.
    ENDCASE.
  ENDMETHOD.


  METHOD text_of.
    " Without the quotes; of a string template the text parts, the
    " embedded expressions as {...}.
    DATA(text) = token-str.
    CASE text(1).
      WHEN `'` OR '`'.
        DATA(length) = strlen( text ).
        result = COND #( WHEN length >= 2 THEN substring( val = text off = 1 len = length - 2 ) ELSE `` ).
      WHEN OTHERS.
        result = without_expressions( text = text placeholder = `{...}` ).
        REPLACE ALL OCCURRENCES OF `|` IN result WITH ``.
    ENDCASE.
  ENDMETHOD.


  METHOD has_letters.
    " At least two letters one after the other: not a type such as 'E' or
    " a number. A name such as /MYNS/BUTTON_ON or a URL is no text.
    IF text CO `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/` OR text CS `://`.
      RETURN.
    ENDIF.
    DATA(plain) = without_expressions( text = text placeholder = ` ` ).
    DATA(run) = 0.
    DO strlen( plain ) TIMES.
      DATA(position) = sy-index - 1.
      IF plain+position(1) CA letters.
        run = run + 1.
        IF run >= 2.
          result = abap_true.
          RETURN.
        ENDIF.
      ELSE.
        run = 0.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD has_words.
    " Two words of two letters or more: "Not found", not 'X' or
    " 'SAPLSE_AUTH'. A word ends at a character that is no letter, digit
    " or underscore. Markup such as <item><NAME> is not a text.
    IF ( text CS `<` AND text CS `>` ) OR text CS `://`.
      RETURN.
    ENDIF.
    DATA(plain) = |{ without_expressions( text = text placeholder = ` ` ) } |.
    DATA(word) = ``.
    DATA(words) = 0.
    DO strlen( plain ) TIMES.
      DATA(position) = sy-index - 1.
      DATA(character) = substring( val = plain off = position len = 1 ).
      IF character CA letters OR character CA `0123456789_`.
        word = word && character.
        CONTINUE.
      ENDIF.
      IF strlen( word ) >= 2 AND word CO letters.
        words = words + 1.
      ENDIF.
      CLEAR word.
    ENDDO.
    result = xsdbool( words >= 2 ).
  ENDMETHOD.


  METHOD without_expressions.
    " The embedded expressions { ... } of a string template replaced.
    " The placeholder may itself contain braces: only the rest of the
    " text is searched.
    DATA(rest) = text.
    WHILE rest CS `{`.
      DATA(after_open) = substring_after( val = rest sub = `{` ).
      IF after_open NS `}`.
        EXIT.
      ENDIF.
      result = result && substring_before( val = rest sub = `{` ) && placeholder.
      rest = substring_after( val = after_open sub = `}` ).
    ENDWHILE.
    result = result && rest.
  ENDMETHOD.


  METHOD namespace_of.
    " /MYNS/AUTH -> /MYNS/; empty without namespace.
    IF name IS INITIAL OR name(1) <> '/'.
      RETURN.
    ENDIF.
    DATA(rest) = substring( val = name off = 1 ).
    IF rest NS `/`.
      RETURN.
    ENDIF.
    result = |/{ substring_before( val = rest sub = `/` ) }/|.
  ENDMETHOD.


  METHOD last_part.
    " LAYOUT-GRID_TITLE -> GRID_TITLE, GRID->SET_TEXT -> SET_TEXT,
    " CL_X=>SET_TEXT -> SET_TEXT.
    DATA(position) = strlen( name ).
    WHILE position > 0.
      DATA(previous) = position - 1.
      IF substring( val = name off = previous len = 1 ) CN `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_`.
        EXIT.
      ENDIF.
      position = previous.
    ENDWHILE.
    result = substring( val = name off = position ).
  ENDMETHOD.


  METHOD shown_parameters.
    result = VALUE #(
      " Popups.
      ( `TITEL` ) ( `TITLEBAR` ) ( `TITLE` ) ( `TEXT_QUESTION` ) ( `TEXT_BUTTON_1` ) ( `TEXT_BUTTON_2` )
      ( `TXT1` ) ( `TXT2` ) ( `TXT3` ) ( `TXT4` ) ( `TEXTLINE1` ) ( `TEXTLINE2` ) ( `TEXTLINE3` )
      ( `DIAGNOSE_OBJECT` ) ( `TEXT_BEFORE` ) ( `TEXT_AFTER` ) ( `INFO_TEXT` ) ( `I_TITLE` )
      ( `WINDOW_TITLE` )
      " ALV field catalog and layout.
      ( `COLTEXT` ) ( `SCRTEXT_S` ) ( `SCRTEXT_M` ) ( `SCRTEXT_L` ) ( `REPTEXT` ) ( `REPTEXT_DDIC` )
      ( `SELTEXT_S` ) ( `SELTEXT_M` ) ( `SELTEXT_L` ) ( `GRID_TITLE` ) ( `TOOLTIP` ) ( `QUICKINFO` )
      ( `TEXT` ) ( `BUTTONTEXT` ) ( `ICON_TEXT` ) ( `I_GRID_TITLE` ) ( `LIST_HEADER` ) ).
  ENDMETHOD.


  METHOD shown_methods.
    result = VALUE #(
      ( `SET_LONG_TEXT` ) ( `SET_MEDIUM_TEXT` ) ( `SET_SHORT_TEXT` ) ( `SET_LIST_HEADER` )
      ( `SET_TITLE` ) ( `SET_TEXT` ) ( `SET_TOOLTIP` ) ( `ADD_TEXT` ) ( `SET_HEADER` ) ).
  ENDMETHOD.

ENDCLASS.
