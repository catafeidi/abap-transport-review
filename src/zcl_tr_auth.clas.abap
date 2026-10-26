*----------------------------------------------------------------------*
* Class ZCL_TR_AUTH: the GitHub account of the SAP user.
*
* Every developer logs in to GitHub once, with report ZTR_GITHUB_LOGIN
* and GitHub's device flow: GitHub shows a code, the developer enters it
* in the browser and allows the GitHub App. The token GitHub gives back
* is kept per SAP user in the cluster table INDX (area ZT), encrypted
* with AES-256. Pushes and API calls of that user then run under that
* account, also in background jobs.
*
* Why not SAP's secure storage (RSECTAB): the kernel only lets programs
* write there that are listed in its own table RSECACHK, and customer
* programs cannot be added (a try ends with "not in the registered
* namespace").
*
* The AES key is made once per system and kept in the same cluster. On
* a development system everybody who can run ABAP can therefore read the
* tokens with own code, the same as any other storage that a job can
* read without a person present. The encryption keeps the tokens out of
* SE16, database views and table exports; the rule of the team keeps the
* rest.
*
* Nothing is shared between users. A user without a token cannot push
* and cannot release a task or a request with objects of the packages under Git.
*
* With "Expire user authorization tokens" switched on in the GitHub App,
* a token lives 8 hours and comes with a refresh token (6 months). The
* class then renews the token by itself before it expires, so a copied
* token dies within hours. Refresh tokens work once only, so the renewal
* runs under a lock per user. Without expiry nothing is renewed.
*
* Setup, see GITHUB-LOGIN.md: GitHub App with device flow enabled and
* expiring user tokens; its client ID in STVARV as
* ZTR_CLIENT_ID (parameter). Optional STVARV parameter
* ZTR_PACKAGES: the package pattern of the system, for example
* /MYNS/* on another system; without it Z*.
*
* Create in SE24 as a local object, source-based editor, paste this file.
* Needs abapGit (JSON reader ZCL_ABAPGIT_AJSON, exception class).
* ABAP 7.40 syntax.
*----------------------------------------------------------------------*
CLASS zcl_tr_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_device_code,
        device_code      TYPE string,
        user_code        TYPE string,
        verification_uri TYPE string,
        expires_in       TYPE i,
        interval         TYPE i,
      END OF ty_device_code.
    TYPES:
      BEGIN OF ty_tokens,
        token         TYPE string,
        refresh_token TYPE string,   " empty when the GitHub App's tokens do not expire
        expires_in    TYPE i,        " seconds, 0 = does not expire
      END OF ty_tokens.
    TYPES BEGIN OF ty_poll.
    INCLUDE TYPE ty_tokens.
    TYPES error TYPE string.   " authorization_pending, slow_down, expired_token, access_denied
    TYPES END OF ty_poll.

    CONSTANTS login_report      TYPE progname VALUE 'ZTR_GITHUB_LOGIN'.
    " The packages of this system that are under Git: the pattern from
    " STVARV parameter ZTR_PACKAGES, else Z*.
    CONSTANTS default_packages  TYPE devclass VALUE 'Z*'.
    CONSTANTS packages_variable TYPE rvari_vnam VALUE 'ZTR_PACKAGES'.
    CONSTANTS client_id_variable TYPE rvari_vnam VALUE 'ZTR_CLIENT_ID'.
    CONSTANTS:
      BEGIN OF poll_error,
        pending  TYPE string VALUE 'authorization_pending',
        slower   TYPE string VALUE 'slow_down',
        expired  TYPE string VALUE 'expired_token',
        denied   TYPE string VALUE 'access_denied',
      END OF poll_error.

    " Package pattern of this system, for example Z* or /MYNS/*. The
    " release check, the push report and the access check all use it.
    " What repositories_without_access returns when GitHub does not accept the token any more.
    CONSTANTS token_rejected TYPE string VALUE '*TOKEN REJECTED*'.
    " The sentence for the result of repositories_without_access (not empty).
    CLASS-METHODS describe_no_access
      IMPORTING
        missing       TYPE string
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS packages
      RETURNING
        VALUE(result) TYPE devclass.
    " The GitHub login name that belongs to the stored token.
    CLASS-METHODS login
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS is_logged_in
      RETURNING
        VALUE(result) TYPE abap_bool.
    " Text for the developer who has no token.
    CLASS-METHODS not_logged_in_text
      RETURNING
        VALUE(result) TYPE string.
    " True only for URLs on the host github.com itself. A URL that merely contains the name, such
    " as https://github.com.example.org/ or https://example.org/github.com/, is not one: the token
    " must never go there.
    CLASS-METHODS is_github_url
      IMPORTING
        url           TYPE csequence
      RETURNING
        VALUE(result) TYPE abap_bool.
    " Authorization header for Git over HTTPS on github.com.
    CLASS-METHODS git_authorization
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    " Authorization header for api.github.com.
    CLASS-METHODS api_authorization
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS store
      IMPORTING
        tokens TYPE ty_tokens
        login  TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS remove
      RAISING
        zcx_abapgit_exception.

    " The event that asks GitHub to merge a released request is signed with
    " a secret that only this system and the GitHub environment sap-merge
    " know (HMAC-SHA256). The secret is kept encrypted like the tokens and
    " never leaves this class: callers get the signature, not the key.
    CLASS-METHODS store_event_secret
      IMPORTING
        secret TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS has_event_secret
      RETURNING
        VALUE(result) TYPE abap_bool.
    " Lower-case hex. The text that is signed is built here and in
    " .github/scripts/merge-released-request.mjs (signedText), the same.
    CLASS-METHODS sign_release_event
      IMPORTING
        request       TYPE string
        pull_request  TYPE i
        sha           TYPE string
        timestamp     TYPE string
        title         TYPE string
        message       TYPE string
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    " Seconds since 1 January 1970, UTC.
    CLASS-METHODS now_in_seconds
      RETURNING
        VALUE(result) TYPE string.

    " The whole login in the dialog: code popup, wait, store. Returns the
    " GitHub login name, or empty when the developer cancelled. Used by
    " the login report and by the release check.
    CLASS-METHODS login_with_popup
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    " The GitHub repositories linked in abapGit for the packages under Git
    " that the current user's account cannot reach. Empty = all fine.
    CLASS-METHODS repositories_without_access
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.

    " GitHub's device flow, piece by piece.
    CLASS-METHODS request_device_code
      RETURNING
        VALUE(result) TYPE ty_device_code
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS poll_for_token
      IMPORTING
        device_code   TYPE string
      RETURNING
        VALUE(result) TYPE ty_poll
      RAISING
        zcx_abapgit_exception.
    " The login name behind a token, from GitHub. Proves the token.
    CLASS-METHODS login_of_token
      IMPORTING
        token         TYPE string
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.

    " Login that needs two runs, as in the ADT console, which shows its output
    " only when a run has ended: the first run asks GitHub for a code and keeps
    " it here, the second run finishes the login. Kept per SAP user in the same
    " cluster as the token, until the code expires.
    CLASS-METHODS keep_device_code
      IMPORTING
        device TYPE ty_device_code.
    " Empty when there is none or when it has expired.
    CLASS-METHODS kept_device_code
      RETURNING
        VALUE(result) TYPE ty_device_code.
    CLASS-METHODS forget_device_code.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_pending,
        device     TYPE ty_device_code,
        created_on TYPE d,
        created_at TYPE t,
      END OF ty_pending.

    TYPES:
      BEGIN OF ty_record,
        login TYPE string,
        token TYPE xstring,   " AES-256 encrypted
      END OF ty_record.
    " Kept as a second parameter next to the record in the same cluster
    " row, so rows stored before this existed are still read.
    TYPES:
      BEGIN OF ty_refresh,
        token      TYPE xstring,     " AES-256 encrypted
        expires_at TYPE timestampl,  " of the access token, UTC; initial = does not expire
      END OF ty_refresh.

    CONSTANTS area             TYPE indx-relid VALUE 'ZT'.
    CONSTANTS key_id           TYPE indx-srtfd VALUE 'KEY:SYSTEM'.
    CONSTANTS event_secret_id  TYPE indx-srtfd VALUE 'SECRET:EVENT'.
    CONSTANTS min_secret_length TYPE i VALUE 32.
    CONSTANTS key_length       TYPE i VALUE 32.
    CONSTANTS github           TYPE string VALUE 'https://github.com'.
    CONSTANTS api              TYPE string VALUE 'https://api.github.com'.
    CONSTANTS ssl_client       TYPE ssfapplssl VALUE 'ANONYM'.
    CONSTANTS device_code_path TYPE string VALUE '/login/device/code'.
    CONSTANTS token_path       TYPE string VALUE '/login/oauth/access_token'.
    CONSTANTS device_grant     TYPE string VALUE 'urn:ietf:params:oauth:grant-type:device_code'.
    CONSTANTS refresh_grant    TYPE string VALUE 'refresh_token'.
    CONSTANTS git_user         TYPE string VALUE 'x-access-token'.

    CONSTANTS extra_seconds    TYPE i VALUE 5.
    " Renew this long before the token expires, so that a push started
    " just before does not run into the end.
    CONSTANTS refresh_margin   TYPE i VALUE 300.
    CONSTANTS lock_table       TYPE tabname VALUE 'INDX'.
    CONSTANTS lock_exclusive   TYPE enqmode VALUE 'E'.

    CLASS-METHODS show_code
      IMPORTING
        device        TYPE ty_device_code
      RETURNING
        VALUE(result) TYPE abap_bool.
    CLASS-METHODS wait_for_token
      IMPORTING
        device        TYPE ty_device_code
      RETURNING
        VALUE(result) TYPE ty_tokens
      RAISING
        zcx_abapgit_exception.
    " The token of the user who runs this, decrypted, empty when there is none. Nobody can ask for
    " the token of another user through this class.
    CLASS-METHODS token
      RETURNING
        VALUE(result) TYPE string.
    " Distinct ids in the cluster, so that no user name can reach the row of another kind.
    CLASS-METHODS token_id
      RETURNING
        VALUE(result) TYPE indx-srtfd.
    CLASS-METHODS pending_id
      RETURNING
        VALUE(result) TYPE indx-srtfd.
    CLASS-METHODS read_record
      RETURNING
        VALUE(result) TYPE ty_record.
    CLASS-METHODS read_refresh
      RETURNING
        VALUE(result) TYPE ty_refresh.
    " The answer of GitHub's token endpoint, for the device flow and for the refresh alike.
    CLASS-METHODS tokens_from_response
      IMPORTING
        response      TYPE string
      RETURNING
        VALUE(result) TYPE ty_poll
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS needs_refresh
      IMPORTING
        expires_at    TYPE timestampl
        now           TYPE timestampl
      RETURNING
        VALUE(result) TYPE abap_bool.
    CLASS-METHODS expiry_time
      IMPORTING
        expires_in    TYPE i
      RETURNING
        VALUE(result) TYPE timestampl.
    " The renewed token, or empty when GitHub refuses the refresh token or cannot be reached.
    CLASS-METHODS refreshed_token
      RETURNING
        VALUE(result) TYPE string.
    CLASS-METHODS refresh_if_still_needed
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception
        cx_sec_sxml_encrypt_error.
    CLASS-METHODS request_refresh
      IMPORTING
        refresh_token TYPE string
      RETURNING
        VALUE(result) TYPE ty_poll
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS lock
      RETURNING
        VALUE(result) TYPE abap_bool.
    CLASS-METHODS unlock.
    CLASS-METHODS lock_key
      RETURNING
        VALUE(result) TYPE rstable-varkey.
    CLASS-METHODS encrypt
      IMPORTING
        plaintext     TYPE string
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS decrypt
      IMPORTING
        ciphertext    TYPE xstring
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception
        cx_sec_sxml_encrypt_error.
    CLASS-METHODS event_secret
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS encryption_key
      RETURNING
        VALUE(result) TYPE xstring
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS client_id
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS call
      IMPORTING
        url           TYPE string
        method        TYPE string
        body          TYPE string OPTIONAL
        authorization TYPE string OPTIONAL
      EXPORTING
        status        TYPE i
        response      TYPE string
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS json_value
      IMPORTING
        json          TYPE string
        path          TYPE string
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
ENDCLASS.



CLASS ZCL_TR_AUTH IMPLEMENTATION.


  METHOD api_authorization.
    DATA(stored) = token( ).
    IF stored IS INITIAL.
      zcx_abapgit_exception=>raise( not_logged_in_text( ) ).
    ENDIF.
    result = |Bearer { stored }|.
  ENDMETHOD.


  METHOD call.
    DATA client  TYPE REF TO if_http_client.
    DATA message TYPE string.

    cl_http_client=>create_by_url(
      EXPORTING
        url    = url
        ssl_id = ssl_client
      IMPORTING
        client = client
      EXCEPTIONS
        OTHERS = 1 ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |no HTTP client for { url }| ).
    ENDIF.

    client->propertytype_logon_popup = if_http_client=>co_disabled.
    client->request->set_method( method ).
    client->request->set_header_field( name = 'Accept'     value = 'application/json' ).
    client->request->set_header_field( name = 'User-Agent' value = 'abap-transport-automation' ).
    IF authorization IS NOT INITIAL.
      client->request->set_header_field( name = 'Authorization' value = authorization ).
    ENDIF.
    IF body IS NOT INITIAL.
      client->request->set_content_type( 'application/x-www-form-urlencoded' ).
      client->request->set_cdata( body ).
    ENDIF.

    client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      client->get_last_error( IMPORTING message = message ).
      client->close( ).
      zcx_abapgit_exception=>raise( |GitHub does not respond ({ message })| ).
    ENDIF.

    client->response->get_status( IMPORTING code = status ).
    response = client->response->get_cdata( ).
    client->close( ).
  ENDMETHOD.


  METHOD client_id.
    " The client ID of the GitHub App is public, so STVARV is the right
    " place: one value per system, no code change when it changes.
    SELECT SINGLE low FROM tvarvc
      INTO @result
      WHERE name = @client_id_variable
        AND type = 'P'.
    IF sy-subrc <> 0 OR result IS INITIAL.
      zcx_abapgit_exception=>raise( |STVARV parameter { client_id_variable } is missing: the client ID of the GitHub App| ).
    ENDIF.
    CONDENSE result.
  ENDMETHOD.


  METHOD encryption_key.
    " One key per system, made on first use.
    DATA header TYPE indx.

    IMPORT key = result FROM DATABASE indx(zt) ID key_id.
    IF sy-subrc = 0 AND xstrlen( result ) = key_length.
      RETURN.
    ENDIF.

    CALL FUNCTION 'GENERATE_SEC_RANDOM'
      EXPORTING
        length = key_length
      IMPORTING
        random = result
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0 OR xstrlen( result ) <> key_length.
      zcx_abapgit_exception=>raise( 'no random key from GENERATE_SEC_RANDOM' ).
    ENDIF.

    header-aedat = sy-datum.
    header-usera = sy-uname.
    EXPORT key = result TO DATABASE indx(zt) FROM header ID key_id.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |the key could not be stored (INDX { area })| ).
    ENDIF.
  ENDMETHOD.


  METHOD git_authorization.
    " GitHub takes a token on its Git endpoint only as Basic authentication.
    DATA(stored) = token( ).
    IF stored IS INITIAL.
      zcx_abapgit_exception=>raise( not_logged_in_text( ) ).
    ENDIF.
    result = |Basic { cl_http_utility=>encode_base64( |{ git_user }:{ stored }| ) }|.
  ENDMETHOD.


  METHOD is_logged_in.
    result = xsdbool( token( ) IS NOT INITIAL ).
  ENDMETHOD.


  METHOD json_value.
    TRY.
        result = zcl_abapgit_ajson=>parse( json )->get_string( path ).
      CATCH zcx_abapgit_ajson_error INTO DATA(error).
        zcx_abapgit_exception=>raise( |response of GitHub not understood, { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD describe_no_access.
    IF missing = token_rejected.
      result = |GitHub does not accept the token of { sy-uname } any more (revoked or expired). Log in again: report { login_report }|.
    ELSE.
      result = |The account has no access to: { missing }|.
    ENDIF.
  ENDMETHOD.


  METHOD is_github_url.
    result = xsdbool( matches( val   = to_lower( url )
                               regex = '^https://github\.com(:443)?/.*' ) ).
  ENDMETHOD.


  METHOD token_id.
    result = |TOK:{ sy-uname }|.
  ENDMETHOD.


  METHOD pending_id.
    result = |PEND:{ sy-uname }|.
  ENDMETHOD.


  METHOD keep_device_code.
    DATA pending TYPE ty_pending.
    DATA header  TYPE indx.
    DATA id      TYPE indx-srtfd.

    id = pending_id( ).
    pending = VALUE #( device     = device
                       created_on = sy-datum
                       created_at = sy-uzeit ).
    header-aedat = sy-datum.
    header-usera = sy-uname.
    EXPORT pending = pending TO DATABASE indx(zt) FROM header ID id.
  ENDMETHOD.


  METHOD kept_device_code.
    DATA pending TYPE ty_pending.
    DATA id      TYPE indx-srtfd.
    DATA elapsed TYPE i.

    id = pending_id( ).
    IMPORT pending = pending FROM DATABASE indx(zt) ID id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    elapsed = ( sy-datum - pending-created_on ) * 86400 + ( sy-uzeit - pending-created_at ).
    IF elapsed >= pending-device-expires_in.
      forget_device_code( ).
      RETURN.
    ENDIF.
    result = pending-device.
  ENDMETHOD.


  METHOD forget_device_code.
    DATA id TYPE indx-srtfd.

    id = pending_id( ).
    DELETE FROM DATABASE indx(zt) ID id.
  ENDMETHOD.


  METHOD login.
    result = read_record( )-login.
  ENDMETHOD.


  METHOD login_of_token.
    DATA status   TYPE i.
    DATA response TYPE string.

    call(
      EXPORTING
        url           = |{ api }/user|
        method        = 'GET'
        authorization = |Bearer { token }|
      IMPORTING
        status        = status
        response      = response ).
    IF status <> 200.
      zcx_abapgit_exception=>raise( |GitHub does not accept the token, HTTP { status }| ).
    ENDIF.
    result = json_value( json = response path = '/login' ).
  ENDMETHOD.


  METHOD login_with_popup.
    DATA(device) = request_device_code( ).

    IF show_code( device ) = abap_false.
      RETURN.
    ENDIF.

    DATA(tokens) = wait_for_token( device ).

    " Prove the token before keeping it, and learn the account name.
    result = login_of_token( tokens-token ).
    store( tokens = tokens login = result ).
  ENDMETHOD.


  METHOD not_logged_in_text.
    result = |{ sy-uname } is not logged in to GitHub on { sy-sysid }. | &&
             |Run report { login_report } once (SE38), or in ADT class ZCL_TR_CONSOLE_LOGIN, then try again|.
  ENDMETHOD.


  METHOD packages.
    " One value per system in STVARV, so the same sources run on every
    " system without a code change.
    SELECT SINGLE low FROM tvarvc
      INTO @result
      WHERE name = @packages_variable
        AND type = 'P'.
    CONDENSE result.
    IF result IS INITIAL.
      result = default_packages.
    ENDIF.
  ENDMETHOD.


  METHOD poll_for_token.
    DATA status   TYPE i.
    DATA response TYPE string.

    call(
      EXPORTING
        url      = |{ github }{ token_path }|
        method   = 'POST'
        body     = |client_id={ client_id( ) }&device_code={ device_code }| &&
                   |&grant_type={ cl_http_utility=>escape_url( device_grant ) }|
      IMPORTING
        status   = status
        response = response ).
    IF status <> 200.
      zcx_abapgit_exception=>raise( |GitHub responds with HTTP { status } while waiting for the login| ).
    ENDIF.

    result = tokens_from_response( response ).
  ENDMETHOD.


  METHOD tokens_from_response.
    result-error = json_value( json = response path = '/error' ).
    IF result-error IS NOT INITIAL.
      RETURN.
    ENDIF.

    result-token = json_value( json = response path = '/access_token' ).
    IF result-token IS INITIAL.
      zcx_abapgit_exception=>raise( 'GitHub sent no token' ).
    ENDIF.
    result-refresh_token = json_value( json = response path = '/refresh_token' ).
    result-expires_in    = json_value( json = response path = '/expires_in' ).
  ENDMETHOD.


  METHOD read_record.
    DATA id TYPE indx-srtfd.

    id = token_id( ).
    IMPORT record = result FROM DATABASE indx(zt) ID id.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.
  ENDMETHOD.


  METHOD read_refresh.
    DATA id TYPE indx-srtfd.

    " Rows stored before the refresh existed have no such parameter; IMPORT then leaves it initial.
    id = token_id( ).
    IMPORT refresh = result FROM DATABASE indx(zt) ID id.
    IF sy-subrc <> 0.
      CLEAR result.
    ENDIF.
  ENDMETHOD.


  METHOD needs_refresh.
    IF expires_at IS INITIAL.
      RETURN.
    ENDIF.
    result = xsdbool( cl_abap_tstmp=>subtract( tstmp1 = expires_at
                                               tstmp2 = now ) < refresh_margin ).
  ENDMETHOD.


  METHOD expiry_time.
    DATA now TYPE timestampl.

    IF expires_in <= 0.
      RETURN.
    ENDIF.
    GET TIME STAMP FIELD now.
    result = cl_abap_tstmp=>add( tstmp = now
                                 secs  = expires_in ).
  ENDMETHOD.


  METHOD refreshed_token.
    " A refresh token works once. Two jobs of the same user that renew at
    " the same moment would make GitHub refuse the second one, so the
    " renewal runs under a lock.
    IF lock( ) = abap_false.
      RETURN.
    ENDIF.

    TRY.
        result = refresh_if_still_needed( ).
      CATCH zcx_abapgit_exception cx_sec_sxml_encrypt_error.
        " GitHub not reachable or the stored data not readable: no token,
        " the caller asks to log in again.
        CLEAR result.
    ENDTRY.

    unlock( ).
  ENDMETHOD.


  METHOD refresh_if_still_needed.
    DATA now TYPE timestampl.

    " Another job may have renewed the token while this one waited for the lock.
    DATA(record)  = read_record( ).
    DATA(refresh) = read_refresh( ).
    GET TIME STAMP FIELD now.
    IF needs_refresh( expires_at = refresh-expires_at now = now ) = abap_false.
      result = decrypt( record-token ).
      RETURN.
    ENDIF.

    DATA(tokens) = request_refresh( decrypt( refresh-token ) ).
    IF tokens-error IS NOT INITIAL.
      " Refresh token revoked or older than 6 months: only a new login helps.
      remove( ).
      RETURN.
    ENDIF.

    " Kept in the current LUW like every other store. Should the caller roll
    " back, GitHub has already replaced the refresh token and the next use
    " asks for a new login.
    store( tokens = CORRESPONDING #( tokens ) login = record-login ).
    result = tokens-token.
  ENDMETHOD.


  METHOD request_refresh.
    DATA status   TYPE i.
    DATA response TYPE string.

    " Tokens from the device flow are renewed without the client secret of the App.
    call(
      EXPORTING
        url      = |{ github }{ token_path }|
        method   = 'POST'
        body     = |client_id={ client_id( ) }&grant_type={ refresh_grant }| &&
                   |&refresh_token={ cl_http_utility=>escape_url( refresh_token ) }|
      IMPORTING
        status   = status
        response = response ).
    IF status <> 200.
      zcx_abapgit_exception=>raise( |GitHub responds with HTTP { status } to the token renewal| ).
    ENDIF.

    result = tokens_from_response( response ).
  ENDMETHOD.


  METHOD lock.
    DATA(key) = lock_key( ).

    CALL FUNCTION 'ENQUEUE_E_TABLE'
      EXPORTING
        mode_rstable   = lock_exclusive
        tabname        = lock_table
        varkey         = key
        _wait          = abap_true
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD unlock.
    DATA(key) = lock_key( ).

    CALL FUNCTION 'DEQUEUE_E_TABLE'
      EXPORTING
        mode_rstable = lock_exclusive
        tabname      = lock_table
        varkey       = key.
  ENDMETHOD.


  METHOD lock_key.
    result = |{ sy-mandt }{ area }{ token_id( ) }|.
  ENDMETHOD.


  METHOD encrypt.
    TRY.
        cl_sec_sxml_writer=>encrypt(
          EXPORTING
            plaintext  = cl_abap_codepage=>convert_to( plaintext )
            key        = encryption_key( )
            algorithm  = cl_sec_sxml_writer=>co_aes256_algorithm_pem
          IMPORTING
            ciphertext = result ).
      CATCH cx_sec_sxml_encrypt_error INTO DATA(error).
        zcx_abapgit_exception=>raise( |the token could not be encrypted: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD decrypt.
    DATA plaintext TYPE xstring.

    cl_sec_sxml_writer=>decrypt(
      EXPORTING
        ciphertext = ciphertext
        key        = encryption_key( )
        algorithm  = cl_sec_sxml_writer=>co_aes256_algorithm_pem
      IMPORTING
        plaintext  = plaintext ).
    result = cl_abap_codepage=>convert_from( plaintext ).
  ENDMETHOD.


  METHOD remove.
    DATA(id) = token_id( ).
    DELETE FROM DATABASE indx(zt) ID id.
  ENDMETHOD.


  METHOD store_event_secret.
    DATA ciphertext TYPE xstring.
    DATA header     TYPE indx.

    IF strlen( secret ) < min_secret_length.
      zcx_abapgit_exception=>raise( |the secret must have at least { min_secret_length } characters| ).
    ENDIF.

    TRY.
        cl_sec_sxml_writer=>encrypt(
          EXPORTING
            plaintext  = cl_abap_codepage=>convert_to( secret )
            key        = encryption_key( )
            algorithm  = cl_sec_sxml_writer=>co_aes256_algorithm_pem
          IMPORTING
            ciphertext = ciphertext ).
      CATCH cx_sec_sxml_encrypt_error INTO DATA(error).
        zcx_abapgit_exception=>raise( |the secret could not be encrypted: { error->get_text( ) }| ).
    ENDTRY.

    header-aedat = sy-datum.
    header-usera = sy-uname.
    EXPORT secret = ciphertext TO DATABASE indx(zt) FROM header ID event_secret_id.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |the secret could not be stored (INDX { area })| ).
    ENDIF.
  ENDMETHOD.


  METHOD has_event_secret.
    DATA ciphertext TYPE xstring.

    IMPORT secret = ciphertext FROM DATABASE indx(zt) ID event_secret_id.
    result = xsdbool( sy-subrc = 0 AND ciphertext IS NOT INITIAL ).
  ENDMETHOD.


  METHOD event_secret.
    DATA ciphertext TYPE xstring.

    IMPORT secret = ciphertext FROM DATABASE indx(zt) ID event_secret_id.
    IF sy-subrc <> 0 OR ciphertext IS INITIAL.
      zcx_abapgit_exception=>raise( |no secret for the merge event on { sy-sysid }. | &&
                                    |Run report ZTR_SET_EVENT_SECRET once (SE38)| ).
    ENDIF.

    TRY.
        cl_sec_sxml_writer=>decrypt(
          EXPORTING
            ciphertext = ciphertext
            key        = encryption_key( )
            algorithm  = cl_sec_sxml_writer=>co_aes256_algorithm_pem
          IMPORTING
            plaintext  = result ).
      CATCH cx_sec_sxml_encrypt_error INTO DATA(error).
        zcx_abapgit_exception=>raise( |the secret for the merge event cannot be read: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD sign_release_event.
    DATA mac TYPE string.

    DATA(newline) = cl_abap_char_utilities=>newline.
    DATA(text) = |{ request }{ newline }{ pull_request }{ newline }{ sha }{ newline }{ timestamp }| &&
                 |{ newline }{ title }{ newline }{ message }|.

    TRY.
        cl_abap_hmac=>calculate_hmac_for_raw(
          EXPORTING
            if_algorithm  = 'SHA256'
            if_key        = event_secret( )
            if_data       = cl_abap_codepage=>convert_to( text )
          IMPORTING
            ef_hmacstring = mac ).
      CATCH cx_abap_message_digest INTO DATA(error).
        zcx_abapgit_exception=>raise( |the merge event could not be signed: { error->get_text( ) }| ).
    ENDTRY.
    result = to_lower( mac ).
  ENDMETHOD.


  METHOD now_in_seconds.
    DATA now     TYPE timestamp.
    DATA seconds TYPE p LENGTH 15 DECIMALS 0.

    GET TIME STAMP FIELD now.
    seconds = cl_abap_tstmp=>subtract(
      tstmp1 = now
      tstmp2 = '19700101000000' ).
    result = |{ seconds }|.
  ENDMETHOD.


  METHOD repositories_without_access.
    " Asks GitHub for every linked repository of the packages under Git.
    " 200 = the account may read it; a private repository the account
    " may not read returns 404.
    DATA status   TYPE i.
    DATA response TYPE string.
    DATA owner    TYPE string.
    DATA name     TYPE string.

    DATA(authorization) = api_authorization( ).
    DATA(repositories)  = zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ).

    LOOP AT repositories INTO DATA(repository).
      IF repository->get_package( ) NP packages( ).
        CONTINUE.
      ENDIF.
      DATA(online) = CAST zif_abapgit_repo_online( repository ).
      " https://github.com/<owner>/<repository>.git
      FIND REGEX 'github\.com/([^/]+)/([^/]+)$' IN online->get_url( ) SUBMATCHES owner name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      REPLACE REGEX '\.git$' IN name WITH ''.

      call(
        EXPORTING
          url           = |{ api }/repos/{ owner }/{ name }|
          method        = 'GET'
          authorization = authorization
        IMPORTING
          status        = status
          response      = response ).
      IF status = 401.
        " The token exists but GitHub does not accept it any more: revoked, or expired.
        result = token_rejected.
        RETURN.
      ENDIF.
      IF status <> 200.
        result = COND #( WHEN result IS INITIAL THEN name ELSE |{ result }, { name }| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD request_device_code.
    DATA status   TYPE i.
    DATA response TYPE string.

    call(
      EXPORTING
        url      = |{ github }{ device_code_path }|
        method   = 'POST'
        body     = |client_id={ client_id( ) }|
      IMPORTING
        status   = status
        response = response ).
    IF status <> 200.
      zcx_abapgit_exception=>raise( |GitHub responds with HTTP { status } to the login request| ).
    ENDIF.

    result-device_code      = json_value( json = response path = '/device_code' ).
    result-user_code        = json_value( json = response path = '/user_code' ).
    result-verification_uri = json_value( json = response path = '/verification_uri' ).
    result-expires_in       = json_value( json = response path = '/expires_in' ).
    result-interval         = json_value( json = response path = '/interval' ).
    IF result-device_code IS INITIAL OR result-user_code IS INITIAL.
      zcx_abapgit_exception=>raise( |GitHub sent no login code: { response }| ).
    ENDIF.
    IF result-interval < 5.
      result-interval = 5.
    ENDIF.
  ENDMETHOD.


  METHOD show_code.
    " A popup with input fields: their content can be selected and copied
    " with Ctrl+C. Clipboard and browser calls to the frontend are
    " security-relevant for SAP GUI and hang the session on some PCs, so
    " the developer opens the page by hand.
    DATA fields     TYPE STANDARD TABLE OF sval.
    DATA returncode TYPE c LENGTH 1.

    " POPUP_GET_VALUES wants a different DDIC field per line; the fields
    " only lend their type, plain characters. '02' = display only; the
    " text can still be selected with the mouse and copied with Ctrl+C.
    fields = VALUE #( field_attr = '02'
      ( tabname = 'SVAL'   fieldname = 'VALUE'  fieldtext = 'Code'    value = device-user_code )
      ( tabname = 'TVARVC' fieldname = 'LOW'    fieldtext = 'Address' value = device-verification_uri )
      ( tabname = 'TVARVC' fieldname = 'HIGH'   fieldtext = 'What to do'
        value = 'Open the address, enter the code, allow the app. Then Continue' )
      " The popup shows 79 characters of a value.
      ( tabname = 'TLINE'  fieldname = 'TDLINE' fieldtext = 'Why'
        value = 'Releases via GitHub. No release until you are logged in to GitHub.' ) ).

    CALL FUNCTION 'POPUP_GET_VALUES'
      EXPORTING
        popup_title     = 'Log in to GitHub: select the text, Ctrl+C copies it'
        no_value_check  = abap_true
      IMPORTING
        returncode      = returncode
      TABLES
        fields          = fields
      EXCEPTIONS
        error_in_fields = 1
        OTHERS          = 2.
    result = xsdbool( sy-subrc = 0 AND returncode IS INITIAL ).
  ENDMETHOD.


  METHOD store.
    DATA record  TYPE ty_record.
    DATA refresh TYPE ty_refresh.
    DATA header  TYPE indx.

    record-token = encrypt( tokens-token ).
    record-login = login.
    IF tokens-refresh_token IS NOT INITIAL.
      refresh-token      = encrypt( tokens-refresh_token ).
      refresh-expires_at = expiry_time( tokens-expires_in ).
    ENDIF.

    header-aedat = sy-datum.
    header-usera = sy-uname.
    DATA(id) = token_id( ).
    EXPORT record = record refresh = refresh TO DATABASE indx(zt) FROM header ID id.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |the token could not be stored (INDX { area })| ).
    ENDIF.
  ENDMETHOD.


  METHOD token.
    DATA now TYPE timestampl.

    DATA(record) = read_record( ).
    IF record-token IS INITIAL.
      RETURN.
    ENDIF.

    DATA(refresh) = read_refresh( ).
    GET TIME STAMP FIELD now.
    IF refresh-token IS NOT INITIAL
        AND needs_refresh( expires_at = refresh-expires_at now = now ) = abap_true.
      result = refreshed_token( ).
      RETURN.
    ENDIF.

    TRY.
        result = decrypt( record-token ).
      CATCH cx_sec_sxml_encrypt_error zcx_abapgit_exception.
        " A token that cannot be read is no token: log in again.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD wait_for_token.
    " GitHub says how often it may be asked. Asking too often makes it
    " ask for a longer pause.
    DATA(interval) = device-interval.
    DATA(waited)   = 0.

    WHILE waited < device-expires_in.
      CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
        EXPORTING
          text = |Code { device-user_code } on { device-verification_uri }. Waiting for you to enter it ({ waited } s)|.
      WAIT UP TO interval SECONDS.
      waited = waited + interval.

      DATA(poll) = poll_for_token( device-device_code ).
      CASE poll-error.
        WHEN ''.
          result = CORRESPONDING #( poll ).
          RETURN.
        WHEN poll_error-pending.
          CONTINUE.
        WHEN poll_error-slower.
          interval = interval + extra_seconds.
        WHEN poll_error-denied.
          zcx_abapgit_exception=>raise( 'You did not allow the app on GitHub. Nothing stored' ).
        WHEN poll_error-expired.
          EXIT.
        WHEN OTHERS.
          zcx_abapgit_exception=>raise( |GitHub responds with { poll-error } while waiting for the login| ).
      ENDCASE.
    ENDWHILE.

    zcx_abapgit_exception=>raise( 'The code expired before it was entered on GitHub. Try again' ).
  ENDMETHOD.
ENDCLASS.
