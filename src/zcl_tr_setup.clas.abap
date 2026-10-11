CLASS zcl_tr_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_packages TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_settings,
        client_id         TYPE string,
        packages          TYPE devclass,
        require_complete  TYPE abap_bool,
        variant_pattern   TYPE string,
        variant_package   TYPE devclass,
        abaplint_url      TYPE string,
        abaplint_depth    TYPE i,
        abaplint_version  TYPE string,
        abaplint_packages TYPE ty_packages,
        clean_abap        TYPE abap_bool,
        replace_existing  TYPE abap_bool,
        write             TYPE abap_bool,
      END OF ty_settings.

    " One line of the result. kind is one of the states below; heading, note and
    " blank are for the layout only, ok, todo and info are the lights.
    TYPES:
      BEGIN OF ty_line,
        kind TYPE c LENGTH 1,
        text TYPE string,
      END OF ty_line.
    TYPES ty_lines TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY.

    CONSTANTS:
      BEGIN OF state,
        ok      TYPE c LENGTH 1 VALUE 'O',
        todo    TYPE c LENGTH 1 VALUE 'T',
        info    TYPE c LENGTH 1 VALUE 'I',
        heading TYPE c LENGTH 1 VALUE 'H',
        note    TYPE c LENGTH 1 VALUE 'N',
        blank   TYPE c LENGTH 1 VALUE 'B',
      END OF state.

    CONSTANTS:
      BEGIN OF parameter_name,
        client_id        TYPE rvari_vnam VALUE 'ZTR_CLIENT_ID',
        packages         TYPE rvari_vnam VALUE 'ZTR_PACKAGES',
        require_complete TYPE rvari_vnam VALUE 'ZTR_REQUIRE_COMPLETE',
        variant_pattern  TYPE rvari_vnam VALUE 'ZTR_VARIANT_PATTERN',
        variant_package  TYPE rvari_vnam VALUE 'ZTR_VARIANT_PACKAGE',
      END OF parameter_name.

    " The stored value of a STVARV parameter, empty when there is none.
    CLASS-METHODS parameter
      IMPORTING
        name          TYPE rvari_vnam
      RETURNING
        VALUE(result) TYPE string.
    " Server and dependency depth of the abaplint client on this system.
    CLASS-METHODS abaplint_setting
      EXPORTING
        url   TYPE string
        depth TYPE i.

    METHODS constructor
      IMPORTING
        settings TYPE ty_settings.
    " Writes the settings when asked, then checks the system. The result is
    " what a screen, a console or a page shows; nothing is written to a list here.
    METHODS run
      RETURNING
        VALUE(result) TYPE ty_lines.

  PRIVATE SECTION.
    CONSTANTS ssl_client        TYPE ssfapplssl VALUE 'ANONYM'.
    CONSTANTS release_check     TYPE exit_imp VALUE 'ZTR_RELEASE_CHECK'.
    CONSTANTS export_feedback   TYPE exit_imp VALUE 'ZTR_EXPORT'.
    CONSTANTS abaplint_global   TYPE tabname VALUE 'ZABAPLINT_GLOB'.
    CONSTANTS abaplint_package  TYPE tabname VALUE 'ZABAPLINT_PACK'.
    CONSTANTS abaplint_check    TYPE seoclsname VALUE 'ZCL_ABAPLINT_CHECK'.
    CONSTANTS abaplint_variant  TYPE sci_chkv VALUE 'Z_ABAPLINT'.
    CONSTANTS minimum_dependency_depth TYPE i VALUE 10.

    DATA settings TYPE ty_settings.
    DATA to_do    TYPE i.
    DATA lines    TYPE ty_lines.

    CLASS-METHODS abaplint_installed
      RETURNING
        VALUE(result) TYPE abap_bool.

    METHODS heading
      IMPORTING
        text TYPE csequence.
    METHODS line
      IMPORTING
        kind TYPE c
        text TYPE csequence.
    METHODS http
      IMPORTING
        method   TYPE string DEFAULT 'GET'
        url      TYPE string
        body     TYPE string OPTIONAL
      EXPORTING
        status   TYPE i
        response TYPE string
        error    TYPE string.
    METHODS method_contains
      IMPORTING
        class         TYPE seoclsname
        method        TYPE seocpdname
        text          TYPE string
      RETURNING
        VALUE(result) TYPE char1.

    METHODS write_settings.
    METHODS may_change
      IMPORTING
        table         TYPE tabname
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS set_parameter
      IMPORTING
        name  TYPE rvari_vnam
        value TYPE csequence.
    METHODS write_abaplint.
    METHODS clean_abap_json
      RETURNING
        VALUE(result) TYPE string.
    METHODS abaplint_json
      RETURNING
        VALUE(result) TYPE string.
    METHODS set_component
      IMPORTING
        name  TYPE string
        value TYPE any
      CHANGING
        row   TYPE any.

    METHODS show_settings.
    METHODS check_tools.
    METHODS check_github.
    METHODS check_repositories.
    METHODS check_release_settings.
    METHODS check_abaplint.
    METHODS manual_steps.
ENDCLASS.


CLASS zcl_tr_setup IMPLEMENTATION.

  METHOD parameter.
    SELECT SINGLE low FROM tvarvc
      INTO @DATA(value)
      WHERE name = @name
        AND type = 'P'
        AND numb = '0000'.
    IF sy-subrc = 0.
      result = value.
      CONDENSE result.
    ENDIF.
  ENDMETHOD.


  METHOD abaplint_installed.
    SELECT SINGLE tabname FROM dd02l
      INTO @DATA(found)
      WHERE tabname  = @abaplint_global
        AND as4local = 'A'
        AND as4vers  = '0000'.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD abaplint_setting.
    " The tables belong to the abaplint client, which may not be
    " installed: no static reference to them anywhere in this program.
    DATA row TYPE REF TO data.
    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <field> TYPE any.

    CLEAR: url, depth.
    IF abaplint_installed( ) = abap_false.
      RETURN.
    ENDIF.
    CREATE DATA row TYPE (abaplint_global).
    ASSIGN row->* TO <row>.
    SELECT SINGLE * FROM (abaplint_global) INTO <row> WHERE sysid = sy-sysid.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    ASSIGN COMPONENT 'URL' OF STRUCTURE <row> TO <field>.
    IF sy-subrc = 0.
      url = <field>.
    ENDIF.
    ASSIGN COMPONENT 'DEPTH' OF STRUCTURE <row> TO <field>.
    IF sy-subrc = 0.
      depth = <field>.
    ENDIF.
  ENDMETHOD.


  METHOD constructor.
    me->settings = settings.
  ENDMETHOD.


  METHOD run.
    IF settings-write = abap_true.
      write_settings( ).
    ENDIF.
    show_settings( ).
    check_tools( ).
    check_github( ).
    check_repositories( ).
    check_release_settings( ).
    check_abaplint( ).
    manual_steps( ).

    line( kind = state-blank
          text = `` ).
    IF to_do = 0.
      line( kind = state-ok text = |Nothing left to do on { sy-sysid }, apart from the manual steps above| ).
    ELSE.
      line( kind = state-todo text = |{ to_do } point(s) with a red light need attention| ).
    ENDIF.

    result = lines.
  ENDMETHOD.


  METHOD heading.
    line( kind = state-heading
          text = text ).
  ENDMETHOD.


  METHOD line.
    IF kind = state-todo.
      to_do = to_do + 1.
    ENDIF.
    INSERT VALUE #( kind = kind
                    text = text ) INTO TABLE lines.
  ENDMETHOD.


  METHOD http.
    DATA client TYPE REF TO if_http_client.

    CLEAR: status, response, error.
    cl_http_client=>create_by_url(
      EXPORTING
        url    = url
        ssl_id = ssl_client
      IMPORTING
        client = client
      EXCEPTIONS
        OTHERS = 1 ).
    IF sy-subrc <> 0.
      error = |no HTTP client for { url }|.
      RETURN.
    ENDIF.

    client->propertytype_logon_popup = if_http_client=>co_disabled.
    client->request->set_method( method ).
    client->request->set_header_field( name = 'Accept'     value = 'application/json' ).
    client->request->set_header_field( name = 'User-Agent' value = 'abap-transport-automation' ).
    IF body IS NOT INITIAL.
      client->request->set_content_type( 'application/x-www-form-urlencoded' ).
      client->request->set_cdata( body ).
    ENDIF.

    client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      client->get_last_error( IMPORTING message = error ).
      IF error IS INITIAL.
        error = 'no response'.
      ENDIF.
      client->close( ).
      RETURN.
    ENDIF.

    client->response->get_status( IMPORTING code = status ).
    response = client->response->get_cdata( ).
    client->close( ).
  ENDMETHOD.


  METHOD method_contains.
    " 'X' = the method contains the text, ' ' = it does not,
    " '?' = class or method does not exist.
    DATA include TYPE programm.
    DATA source  TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    cl_oo_classname_service=>get_method_include(
      EXPORTING
        mtdkey              = VALUE #( clsname = class cpdname = method )
      RECEIVING
        result              = include
      EXCEPTIONS
        class_not_existing  = 1
        method_not_existing = 2
        OTHERS              = 3 ).
    IF sy-subrc <> 0.
      result = '?'.
      RETURN.
    ENDIF.
    READ REPORT include INTO source.
    IF sy-subrc <> 0.
      result = '?'.
      RETURN.
    ENDIF.
    FIND text IN TABLE source IGNORING CASE.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD may_change.
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD table.
    result = xsdbool( sy-subrc = 0 ).
    IF result = abap_false.
      line( kind = state-todo text = |No authorization to change { table } (S_TABU_NAM, activity 02): nothing was written there| ).
    ENDIF.
  ENDMETHOD.


  METHOD write_settings.
    IF may_change( `TVARVC` ) = abap_false.
      RETURN.
    ENDIF.
    heading( |Settings written on { sy-sysid }, client { sy-mandt }| ).
    set_parameter( name = parameter_name-client_id        value = settings-client_id ).
    set_parameter( name = parameter_name-packages         value = settings-packages ).
    set_parameter( name = parameter_name-require_complete value = settings-require_complete ).
    set_parameter( name = parameter_name-variant_pattern  value = settings-variant_pattern ).
    set_parameter( name = parameter_name-variant_package  value = settings-variant_package ).
    write_abaplint( ).
    COMMIT WORK.
  ENDMETHOD.


  METHOD set_parameter.
    " An empty value removes the parameter, so the default of the tools
    " applies again.
    DATA entry TYPE tvarvc.

    IF value IS INITIAL.
      DELETE FROM tvarvc WHERE name = name AND type = 'P'.
      IF sy-subrc = 0.
        line( kind = state-info text = |STVARV { name }: removed, the default applies| ).
      ENDIF.
      RETURN.
    ENDIF.

    entry-name = name.
    entry-type = 'P'.
    entry-numb = '0000'.
    entry-low  = value.
    MODIFY tvarvc FROM entry.
    line( kind = state-ok text = |STVARV { name } = { value }| ).
  ENDMETHOD.


  METHOD write_abaplint.
    DATA row      TYPE REF TO data.
    DATA existing TYPE devclass.
    FIELD-SYMBOLS <row>   TYPE any.
    FIELD-SYMBOLS <field> TYPE any.

    IF abaplint_installed( ) = abap_false.
      RETURN.
    ENDIF.
    IF may_change( abaplint_global ) = abap_false OR may_change( abaplint_package ) = abap_false.
      RETURN.
    ENDIF.

    IF settings-abaplint_url IS NOT INITIAL.
      CREATE DATA row TYPE (abaplint_global).
      ASSIGN row->* TO <row>.
      SELECT SINGLE * FROM (abaplint_global) INTO <row> WHERE sysid = sy-sysid.
      set_component( EXPORTING name = `SYSID` value = sy-sysid               CHANGING row = <row> ).
      set_component( EXPORTING name = `URL`   value = settings-abaplint_url   CHANGING row = <row> ).
      set_component( EXPORTING name = `DEPTH` value = settings-abaplint_depth CHANGING row = <row> ).
      ASSIGN COMPONENT 'HTTP_TIMEOUT' OF STRUCTURE <row> TO <field>.
      IF sy-subrc = 0 AND <field> IS INITIAL.
        <field> = 6000.
      ENDIF.
      ASSIGN COMPONENT 'SSL_ID' OF STRUCTURE <row> TO <field>.
      IF sy-subrc = 0 AND <field> IS INITIAL.
        <field> = ssl_client.
      ENDIF.
      MODIFY (abaplint_global) FROM <row>.
      line( kind = state-ok
            text = |abaplint: server { settings-abaplint_url }, dependency depth { settings-abaplint_depth }| ).
    ENDIF.

    " One configuration per package. An existing one is kept: it may
    " hold rules and exclusions that were added by hand.
    LOOP AT settings-abaplint_packages INTO DATA(package).
      SELECT SINGLE devclass FROM (abaplint_package) INTO existing WHERE devclass = package.
      IF sy-subrc = 0 AND settings-replace_existing = abap_false.
        line( kind = state-info text = |abaplint: configuration of package { package } exists, kept as it is| ).
        CONTINUE.
      ENDIF.
      CREATE DATA row TYPE (abaplint_package).
      ASSIGN row->* TO <row>.
      set_component( EXPORTING name = `DEVCLASS` value = package          CHANGING row = <row> ).
      set_component( EXPORTING name = `JSON`     value = abaplint_json( ) CHANGING row = <row> ).
      MODIFY (abaplint_package) FROM <row>.
      line( kind = state-ok
            text = |abaplint: package { package } configured, syntax { settings-abaplint_version }| &&
                   COND string( WHEN settings-clean_abap = abap_true THEN |, with the Clean ABAP rules| ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD clean_abap_json.
    " The rules of SAP's Clean ABAP guide that abaplint can check, as on
    " GitHub (abaplint-clean.json), without the four that are wrong when
    " abaplint sees one object alone: unused_variables, prefer_inline,
    " unused_methods, unused_types. Meant for packages that follow
    " this style; older code gets thousands of findings. Source of this
    " text: github-templates/abaplint-sap-package.json.
    DATA(nl) = cl_abap_char_utilities=>newline.

    result = `{` && nl &&
             ` "global": {` && nl &&
             `  "files": "/src/**/*.*"` && nl &&
             ` },` && nl &&
             ` "syntax": {` && nl &&
             `  "version": "` && settings-abaplint_version && `",` && nl &&
             `  "errorNamespace": "^(Z|Y|LCL_|LTC_|LIF_|LTD_)"` && nl &&
             ` },` && nl &&
             ` "rules": {` && nl &&
             `  "align_parameters": true,` && nl &&
             `  "avoid_use": true,` && nl &&
             `  "change_if_to_case": true,` && nl &&
             `  "chain_mainly_declarations": true,` && nl &&
             `  "check_subrc": true,` && nl &&
             `  "class_attribute_names": {` && nl &&
             `   "instance": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "static": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "constants": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "exceptions": "^[a-z][a-z0-9_]*$"` && nl &&
             `  },` && nl &&
             `  "clear_exporting_parameters": true,` && nl &&
             `  "colon_missing_space": true,` && nl &&
             `  "constructor_visibility_public": true,` && nl &&
             `  "cyclomatic_complexity": {` && nl &&
             `   "max": 10` && nl &&
             `  },` && nl &&
             `  "double_space": true,` && nl &&
             `  "else_after_all_returns": true,` && nl &&
             `  "empty_line_in_statement": true,` && nl &&
             `  "empty_statement": true,` && nl &&
             `  "empty_structure": true,` && nl &&
             `  "exit_or_check": true,` && nl &&
             `  "exporting": true,` && nl &&
             `  "fully_type_constants": true,` && nl &&
             `  "fully_type_itabs": true,` && nl &&
             `  "functional_writing": true,` && nl &&
             `  "identical_conditions": true,` && nl &&
             `  "identical_contents": true,` && nl &&
             `  "if_in_if": true,` && nl &&
             `  "indentation": true,` && nl &&
             `  "keep_single_parameter_on_one_line": true,` && nl &&
             `  "keyword_case": {` && nl &&
             `   "style": "upper",` && nl &&
             `   "ignoreGlobalClassBegin": true` && nl &&
             `  },` && nl &&
             `  "line_break_multiple_parameters": true,` && nl &&
             `  "line_length": {` && nl &&
             `   "length": 120` && nl &&
             `  },` && nl &&
             `  "local_variable_names": {` && nl &&
             `   "expectedData": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "expectedConstant": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "expectedFS": "^<[a-z][a-z0-9_]*>$"` && nl &&
             `  },` && nl &&
             `  "many_parentheses": true,` && nl &&
             `  "max_one_method_parameter_per_line": true,` && nl &&
             `  "max_one_statement": true,` && nl &&
             `  "method_length": {` && nl &&
             `   "statements": 30` && nl &&
             `  },` && nl &&
             `  "method_parameter_names": {` && nl &&
             `   "importing": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "exporting": "^[a-z][a-z0-9_]*$",` && nl &&
             `   "returning": "^result$",` && nl &&
             `   "changing": "^[a-z][a-z0-9_]*$"` && nl &&
             `  },` && nl &&
             `  "mix_returning": true,` && nl &&
             `  "nesting": {` && nl &&
             `   "depth": 3` && nl &&
             `  },` && nl &&
             `  "newline_between_methods": true,` && nl &&
             `  "no_aliases": true,` && nl &&
             `  "no_chained_assignment": true,` && nl &&
             `  "no_comments_between_methods": true,` && nl &&
             `  "no_prefixes": true,` && nl &&
             `  "no_public_attributes": {` && nl &&
             `   "allowReadOnly": true,` && nl &&
             `   "exclude": [` && nl &&
             `    "[.]testclasses[.]"` && nl &&
             `   ]` && nl &&
             `  },` && nl &&
             `  "no_yoda_conditions": true,` && nl &&
             `  "nrob_consistency": true,` && nl &&
             `  "obsolete_statement": true,` && nl &&
             `  "omit_parameter_name": true,` && nl &&
             `  "omit_receiving": true,` && nl &&
             `  "prefer_abap_bool_values": true,` && nl &&
             `  "prefer_corresponding": true,` && nl &&
             `  "prefer_insert_into_table": true,` && nl &&
             `  "prefer_is_not": true,` && nl &&
             `  "prefer_pragmas": true,` && nl &&
             `  "prefer_returning_to_exporting": true,` && nl &&
             `  "prefer_string_template": true,` && nl &&
             `  "prefer_xsdbool": true,` && nl &&
             `  "redundant_conversion": true,` && nl &&
             `  "reduce_string_templates": true,` && nl &&
             `  "select_single_full_key": true,` && nl &&
             `  "sequential_blank": true,` && nl &&
             `  "short_case": true,` && nl &&
             `  "space_before_dot": true,` && nl &&
             `  "static_call_via_instance": true,` && nl &&
             `  "sy_modification": true,` && nl &&
             `  "unnecessary_chaining": true,` && nl &&
             `  "unnecessary_loop_guard": true,` && nl &&
             `  "unnecessary_pragma": true,` && nl &&
             `  "unnecessary_return": true,` && nl &&
             `  "unreachable_code": true,` && nl &&
             `  "use_bool_expression": true,` && nl &&
             `  "use_class_based_exceptions": true,` && nl &&
             `  "use_line_exists": true,` && nl &&
             `  "use_new": true,` && nl &&
             `  "when_others_last": true,` && nl &&
             `  "whitespace_end": true,` && nl &&
             `  "parser_error": true,` && nl &&
             `  "check_syntax": true` && nl &&
             ` }` && nl &&
             `}`.
  ENDMETHOD.


  METHOD abaplint_json.
    " Syntax of the lowest supported release, and the full syntax check,
    " which inside SAP knows the dictionary. Names outside the namespaces
    " below are SAP's and are not reported when unknown.
    IF settings-clean_abap = abap_true.
      result = clean_abap_json( ).
      RETURN.
    ENDIF.

    DATA(nl) = cl_abap_char_utilities=>newline.

    result = `{` && nl &&
             `  "global": {` && nl &&
             `    "files": "/src/**/*.*"` && nl &&
             `  },` && nl &&
             `  "syntax": {` && nl &&
             `    "version": "` && settings-abaplint_version && `",` && nl &&
             `    "errorNamespace": "^(Z|Y|LCL_|LTC_|LIF_|LTD_)"` && nl &&
             `  },` && nl &&
             `  "rules": {` && nl &&
             `    "parser_error": true,` && nl &&
             `    "check_syntax": true` && nl &&
             `  }` && nl &&
             `}`.
  ENDMETHOD.


  METHOD set_component.
    FIELD-SYMBOLS <field> TYPE any.

    ASSIGN COMPONENT name OF STRUCTURE row TO <field>.
    IF sy-subrc = 0.
      <field> = value.
    ENDIF.
  ENDMETHOD.


  METHOD show_settings.
    heading( |Settings on { sy-sysid }, client { sy-mandt }| ).

    DATA(client_id) = parameter( parameter_name-client_id ).
    IF client_id IS INITIAL.
      line( kind = state-todo text = |STVARV { parameter_name-client_id } is missing: the client ID of the GitHub App| ).
    ELSE.
      line( kind = state-ok text = |GitHub App client ID: { client_id }| ).
    ENDIF.

    DATA(stored_packages) = parameter( parameter_name-packages ).
    line( kind = state-ok
          text = |Packages under Git: { zcl_tr_auth=>packages( ) }| &&
                 COND string( WHEN stored_packages IS INITIAL
                              THEN | (default, STVARV { parameter_name-packages } is not set)| ) ).

    IF parameter( parameter_name-require_complete ) = abap_true.
      line( kind = state-ok text = 'A request with entries that cannot be written to Git is refused at release' ).
    ELSE.
      line( kind = state-info
            text = |Entries that cannot be written to Git are only listed (STVARV { parameter_name-require_complete } is not X)| ).
    ENDIF.

    DATA(pattern) = parameter( parameter_name-variant_pattern ).
    DATA(package) = parameter( parameter_name-variant_package ).
    line( kind = state-info
          text = |Variants of reports: pattern { COND string( WHEN pattern IS INITIAL THEN `not set (variants are not written to Git)` ELSE pattern ) }| &&
                 |, package { COND string( WHEN package IS INITIAL THEN `not set` ELSE package ) }| ).
  ENDMETHOD.


  METHOD check_tools.
    heading( 'Tools on this system' ).

    line( kind = state-ok text = |abapGit developer version { zif_abapgit_version=>c_abap_version }| ).

    " The user exit sends the Git traffic with the token of the user.
    CASE method_contains( class = 'ZCL_ABAPGIT_USER_EXIT' method = 'ZIF_ABAPGIT_EXIT~CREATE_HTTP_CLIENT'
                          text  = `zcl_tr_auth` ).
      WHEN abap_true.
        line( kind = state-ok text = 'abapGit user exit ZCL_ABAPGIT_USER_EXIT uses the GitHub login of the user' ).
      WHEN abap_false.
        line( kind = state-todo
              text = 'ZCL_ABAPGIT_USER_EXIT exists, but CREATE_HTTP_CLIENT does not use ZCL_TR_AUTH: pull the tools again' ).
      WHEN OTHERS.
        line( kind = state-todo text = 'abapGit user exit ZCL_ABAPGIT_USER_EXIT is missing: pull the tools with abapGit' ).
    ENDCASE.

    " The release check. abapGit activates it with the pull.
    SELECT SINGLE active FROM sxc_attr
      INTO @DATA(active)
      WHERE imp_name = @release_check.
    IF sy-subrc <> 0.
      line( kind = state-todo text = |BAdI implementation { release_check } (CTS_REQUEST_CHECK) is missing: pull the tools with abapGit| ).
    ELSEIF active = abap_true.
      line( kind = state-ok text = |Release check { release_check } (CTS_REQUEST_CHECK) is active| ).
    ELSE.
      line( kind = state-todo text = |Release check { release_check } is NOT active: SE19, activate the implementation| ).
    ENDIF.

    " Its job runs as DDIC, who has no GitHub account.
    SELECT SINGLE active FROM sxc_attr
      INTO @active
      WHERE imp_name = @export_feedback.
    IF sy-subrc = 0 AND active = abap_true.
      line( kind = state-todo text = |BAdI implementation { export_feedback } is active: SE19, deactivate or delete it| ).
    ENDIF.

    " abapGit writes no file for documentation objects with a namespace
    " unless its DOCV class has the fix of ABAPGIT-DOCV-FIX.md.
    CASE method_contains( class = 'ZCL_ABAPGIT_OBJECT_DOCV' method = 'CONSTRUCTOR'
                          text  = `obj_name(1) <> '/'` ).
      WHEN abap_true.
        line( kind = state-ok text = 'abapGit writes documentation objects with a namespace (DOCV fix is in)' ).
      WHEN abap_false.
        line( kind = state-info
              text = 'abapGit DOCV fix is missing: only needed for documentation objects with a namespace, see ABAPGIT-DOCV-FIX.md' ).
    ENDCASE.
  ENDMETHOD.


  METHOD check_github.
    DATA status   TYPE i.
    DATA response TYPE string.
    DATA error    TYPE string.

    heading( 'GitHub' ).

    http( EXPORTING url = `https://api.github.com/zen` IMPORTING status = status error = error ).
    IF error IS INITIAL.
      line( kind = state-ok text = |api.github.com responds over SSL (HTTP { status })| ).
    ELSE.
      line( kind = state-todo
            text = |api.github.com is not reachable: { error }. STRUST, SSL client Anonymous: import GitHub's certificate chain; check proxy and firewall| ).
    ENDIF.

    http( EXPORTING url = `https://github.com/` IMPORTING status = status error = error ).
    IF error IS INITIAL.
      line( kind = state-ok text = |github.com responds over SSL (HTTP { status })| ).
    ELSE.
      line( kind = state-todo text = |github.com is not reachable: { error }| ).
      RETURN.
    ENDIF.

    " Asks GitHub for a device code, as the login does. The code is not
    " used and expires on its own.
    DATA(client_id) = parameter( parameter_name-client_id ).
    IF client_id IS NOT INITIAL.
      http( EXPORTING method = `POST` url = `https://github.com/login/device/code`
                      body   = |client_id={ cl_http_utility=>escape_url( client_id ) }|
            IMPORTING status = status response = response error = error ).
      IF error IS INITIAL AND status = 200 AND response CS 'device_code'.
        line( kind = state-ok text = 'The GitHub App accepts the client ID and has the device flow enabled' ).
      ELSE.
        line( kind = state-todo
              text = |The GitHub App does not accept the client ID or has no device flow (HTTP { status } { error }): | &&
                     substring( val = response len = nmin( val1 = 80 val2 = strlen( response ) ) ) ).
      ENDIF.
    ENDIF.

    IF zcl_tr_auth=>is_logged_in( ) = abap_true.
      line( kind = state-ok text = |{ sy-uname } is logged in to GitHub as { zcl_tr_auth=>login( ) }| ).
    ELSE.
      line( kind = state-info
            text = |{ sy-uname } is not logged in to GitHub: report { zcl_tr_auth=>login_report }, once per developer| ).
    ENDIF.
  ENDMETHOD.


  METHOD check_repositories.
    DATA linked TYPE i.

    heading( |abapGit repositories for packages { zcl_tr_auth=>packages( ) }| ).

    TRY.
        DATA(pattern) = zcl_tr_auth=>packages( ).
        LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(repository).
          IF repository->get_package( ) NP pattern.
            CONTINUE.
          ENDIF.
          linked = linked + 1.
          line( kind = state-ok
                text = |{ repository->get_package( ) } is linked to { CAST zif_abapgit_repo_online( repository )->get_url( ) }| ).
        ENDLOOP.
        IF linked = 0.
          line( kind = state-todo
                text = |No online repository is linked for these packages: ZABAPGIT, New Online, one per package| ).
          RETURN.
        ENDIF.

        IF zcl_tr_auth=>is_logged_in( ) = abap_true.
          DATA(no_access) = zcl_tr_auth=>repositories_without_access( ).
          IF no_access IS INITIAL.
            line( kind = state-ok text = |{ zcl_tr_auth=>login( ) } has access to every linked repository| ).
          ELSE.
            line( kind = state-todo
                  text = |{ zcl_tr_auth=>login( ) } has no access to { no_access }: install the GitHub App on it, give the user write access| ).
          ENDIF.
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(error).
        line( kind = state-todo text = |The repositories could not be checked: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD check_release_settings.
    heading( 'Release settings of the Transport Organizer' ).

    SELECT SINGLE bg_release FROM wbosyscust
      INTO @DATA(background)
      WHERE id = 'WBO'.
    IF sy-subrc = 0 AND background IS NOT INITIAL.
      line( kind = state-info
            text = 'Requests are released in the background: a refused release only shows in the job log (SM37). SE03, Global Customizing' ).
    ELSE.
      line( kind = state-ok text = 'Requests are released in the dialog: a refused release shows on the screen' ).
    ENDIF.
  ENDMETHOD.


  METHOD check_abaplint.
    DATA status   TYPE i.
    DATA response TYPE string.
    DATA error    TYPE string.
    DATA packages TYPE ty_packages.

    heading( 'abaplint inside SAP (Code Inspector and ATC)' ).

    IF abaplint_installed( ) = abap_false.
      line( kind = state-info
            text = 'The abaplint client is not installed: ZABAPGIT, New Online, https://github.com/abaplint/abaplint-sci-client, package $ABAPLINT' ).
      RETURN.
    ENDIF.
    line( kind = state-ok text = 'The abaplint client is installed' ).

    SELECT SINGLE name FROM scitests
      INTO @DATA(test)
      WHERE name = @abaplint_check.
    IF sy-subrc = 0.
      line( kind = state-ok text = |The check { abaplint_check } is active in Code Inspector| ).
    ELSE.
      line( kind = state-todo text = |The check { abaplint_check } is not active: SCI, Goto, Management of, Tests| ).
    ENDIF.

    SELECT checkvname FROM scichkv_hd UP TO 1 ROWS
      INTO @DATA(variant)
      WHERE checkvname = @abaplint_variant
        AND ciuser     = @space.
    ENDSELECT.
    IF sy-subrc = 0.
      line( kind = state-ok text = |Global check variant { abaplint_variant } exists| ).
    ELSE.
      line( kind = state-info text = |Global check variant { abaplint_variant } does not exist: SCI, create it with the abaplint check only| ).
    ENDIF.

    abaplint_setting( IMPORTING url = DATA(url) depth = DATA(depth) ).
    IF url IS INITIAL.
      line( kind = state-todo text = 'No abaplint server is configured: enter the server above and run with "Write the settings"' ).
      RETURN.
    ENDIF.

    http( EXPORTING url = |{ url }/api/v1/ping| IMPORTING status = status response = response error = error ).
    IF error IS INITIAL AND status = 200.
      line( kind = state-ok
            text = |abaplint server { url } responds: { substring( val = response len = nmin( val1 = 90 val2 = strlen( response ) ) ) }| ).
    ELSE.
      line( kind = state-todo
            text = |abaplint server { url } does not respond (HTTP { status } { error }): container running? firewall rule for this system?| ).
    ENDIF.

    " The client does not cut the dependencies off at this depth: it ends
    " the check of the object with an error. 0 is its own default, 20.
    IF depth = 0 OR depth >= minimum_dependency_depth.
      line( kind = state-ok
            text = |Dependency depth { COND string( WHEN depth = 0 THEN `0 (default of the client: 20)` ELSE |{ depth }| ) }| ).
    ELSE.
      line( kind = state-todo
            text = |Dependency depth { depth } is too low: every class with a longer chain of dependencies gets the finding | &&
                   |"Max depth reached" instead of a check. Set 20 above and write the settings| ).
    ENDIF.

    SELECT devclass FROM (abaplint_package) INTO TABLE packages.
    IF packages IS INITIAL.
      line( kind = state-todo text = 'No package has an abaplint configuration: enter the packages above and write the settings' ).
    ELSE.
      line( kind = state-ok text = |Packages with an abaplint configuration: { concat_lines_of( table = packages sep = `, ` ) }| ).
    ENDIF.
  ENDMETHOD.


  METHOD manual_steps.
    heading( 'What this report cannot do' ).
    line( kind = state-note text = '- STRUST, SSL client Anonymous: the certificate chain of github.com and api.github.com, if GitHub is not reachable.' ).
    line( kind = state-note text = '- GitHub: the GitHub App installed on every repository of this system; every developer with write access.' ).
    line( kind = state-note text = '- Every developer, once: report ZTR_GITHUB_LOGIN.' ).
    line( kind = state-note text = '- ZABAPGIT: one online repository per package under Git, branch master.' ).
    line( kind = state-note text = '- abaplint: SCI, activate the check and create the variants; ATC, global check variant and behavior on release;' ).
    line( kind = state-note text = '  on the abaplint server, a firewall rule for this system.' ).
    line( kind = state-note text = '- SE03, Global Customizing: release in the dialog, not in the background.' ).
  ENDMETHOD.

ENDCLASS.
