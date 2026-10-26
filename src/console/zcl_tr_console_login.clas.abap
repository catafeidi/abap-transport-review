"! Console class for ADT (Run As, ABAP Application (Console), F9): the one-time GitHub login of
"! the SAP user who runs it. The console shows its output only when a run has ended, so the login
"! takes two runs:
"!   1st run: asks GitHub for a code and prints it with the address to open.
"!   2nd run: after the code was entered on GitHub, finishes the login and keeps the token.
"! Run it again after the login to see the status.
"! Only the main method touches the console object: its type differs between releases.
CLASS zcl_tr_console_login DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    DATA lines TYPE string_table.

    METHODS login
      RAISING
        zcx_abapgit_exception.
    METHODS show_status
      RAISING
        zcx_abapgit_exception.
    METHODS start_login
      RAISING
        zcx_abapgit_exception.
    METHODS finish_login
      IMPORTING
        device TYPE zcl_tr_auth=>ty_device_code
      RAISING
        zcx_abapgit_exception.
    METHODS add
      IMPORTING
        text TYPE string.
ENDCLASS.


CLASS zcl_tr_console_login IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    TRY.
        login( ).
      CATCH zcx_abapgit_exception INTO DATA(error).
        add( error->get_text( ) ).
    ENDTRY.

    LOOP AT lines INTO DATA(line).
      out->write( line ).
    ENDLOOP.
  ENDMETHOD.


  METHOD login.
    IF zcl_tr_auth=>is_logged_in( ) = abap_true.
      show_status( ).
      RETURN.
    ENDIF.

    DATA(device) = zcl_tr_auth=>kept_device_code( ).
    IF device IS INITIAL.
      start_login( ).
    ELSE.
      finish_login( device ).
    ENDIF.
  ENDMETHOD.


  METHOD show_status.
    add( |{ sy-uname } is logged in to GitHub as { zcl_tr_auth=>login( ) }| ).
    DATA(missing) = zcl_tr_auth=>repositories_without_access( ).
    IF missing IS INITIAL.
      add( 'The account has access to every linked repository.' ).
    ELSE.
      add( zcl_tr_auth=>describe_no_access( missing ) ).
    ENDIF.
  ENDMETHOD.


  METHOD start_login.
    DATA(device) = zcl_tr_auth=>request_device_code( ).
    zcl_tr_auth=>keep_device_code( device ).
    add( |1. Open { device-verification_uri }| ).
    add( |2. Enter the code { device-user_code } and allow the app| ).
    add( |3. Run this class again within { device-expires_in / 60 } minutes to finish the login| ).
  ENDMETHOD.


  METHOD finish_login.
    DATA(poll) = zcl_tr_auth=>poll_for_token( device-device_code ).
    CASE poll-error.
      WHEN ''.
        DATA(account) = zcl_tr_auth=>login_of_token( poll-token ).
        zcl_tr_auth=>store( tokens = CORRESPONDING #( poll )
                            login  = account ).
        zcl_tr_auth=>forget_device_code( ).
        add( |Logged in to GitHub as { account }. Pushes and pull requests of { sy-uname } now run under this account.| ).
        DATA(missing) = zcl_tr_auth=>repositories_without_access( ).
        IF missing IS NOT INITIAL.
          add( |Warning: { zcl_tr_auth=>describe_no_access( missing ) }| ).
        ENDIF.
      WHEN zcl_tr_auth=>poll_error-pending OR zcl_tr_auth=>poll_error-slower.
        add( |GitHub has not got the code yet. Enter { device-user_code } on { device-verification_uri }, then run this class again.| ).
      WHEN zcl_tr_auth=>poll_error-denied.
        zcl_tr_auth=>forget_device_code( ).
        add( 'You did not allow the app on GitHub. Nothing stored. Run this class again to start over.' ).
      WHEN zcl_tr_auth=>poll_error-expired.
        zcl_tr_auth=>forget_device_code( ).
        add( 'The code expired before it was entered. Run this class again to get a new one.' ).
      WHEN OTHERS.
        zcl_tr_auth=>forget_device_code( ).
        add( |GitHub responds with { poll-error } while waiting for the login. Run this class again to start over.| ).
    ENDCASE.
  ENDMETHOD.


  METHOD add.
    INSERT text INTO TABLE lines.
  ENDMETHOD.

ENDCLASS.
