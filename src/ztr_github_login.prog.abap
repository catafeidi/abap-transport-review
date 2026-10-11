*&---------------------------------------------------------------------*
*& Report ZTR_GITHUB_LOGIN
*&---------------------------------------------------------------------*
*& Logs the SAP user in to GitHub, once. After that every push and every
*& pull request of this user from this system runs under their own
*& GitHub account, also in background jobs.
*&
*& How: GitHub's device flow. The report asks GitHub for a code, shows
*& it, and waits until the developer entered it on github.com/login/device
*& and allowed the GitHub App. The token that GitHub gives back is kept
*& encrypted on this system, for this user only (class ZCL_TR_AUTH).
*& The same login popup appears by itself when somebody who is not
*& logged in releases a task or request in SAP GUI.
*&
*& Log out removes the token from SAP. The access on the GitHub side is
*& revoked on GitHub, under Settings, Applications.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_github_login NO STANDARD PAGE HEADING.

" Texts of the selection screen, set in code so that no text elements
" have to be maintained after the paste. The COMMENT statements declare
" the variables.

SELECTION-SCREEN BEGIN OF BLOCK action WITH FRAME TITLE t_frame.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_login  RADIOBUTTON GROUP act DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(70) t_login FOR FIELD p_login.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_status RADIOBUTTON GROUP act.
SELECTION-SCREEN COMMENT 3(70) t_status FOR FIELD p_status.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_logout RADIOBUTTON GROUP act.
SELECTION-SCREEN COMMENT 3(70) t_logout FOR FIELD p_logout.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK action.

INITIALIZATION.
  t_frame  = |GitHub account of SAP user { sy-uname }|.
  t_login  = 'Log in to GitHub, once. The token stays on this system'.
  t_status = 'Show which GitHub account this SAP user is logged in with'.
  t_logout = 'Log out: remove the token from this system'.

CLASS lcl_login DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run
      RAISING
        zcx_abapgit_exception.
  PRIVATE SECTION.
    METHODS login
      RAISING
        zcx_abapgit_exception.
    METHODS status
      RAISING
        zcx_abapgit_exception.
    METHODS logout
      RAISING
        zcx_abapgit_exception.
ENDCLASS.


CLASS lcl_login IMPLEMENTATION.

  METHOD run.
    IF p_login = abap_true.
      login( ).
    ELSEIF p_logout = abap_true.
      logout( ).
    ELSE.
      status( ).
    ENDIF.
  ENDMETHOD.


  METHOD login.
    DATA(login) = zcl_tr_auth=>login_with_popup( ).
    IF login IS INITIAL.
      MESSAGE 'Login cancelled, nothing stored' TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    WRITE: / |Logged in to GitHub as { login }. Pushes and pull requests of { sy-uname } now run under this account.|.

    DATA(missing) = zcl_tr_auth=>repositories_without_access( ).
    IF missing IS INITIAL.
      MESSAGE |Logged in to GitHub as { login }| TYPE 'S'.
    ELSE.
      WRITE: / |Warning: { zcl_tr_auth=>describe_no_access( missing ) }. Until that is fixed no release is possible.|.
      MESSAGE |{ login }: { zcl_tr_auth=>describe_no_access( missing ) }| TYPE 'S' DISPLAY LIKE 'W'.
    ENDIF.
  ENDMETHOD.


  METHOD status.
    " Also tells whether the account reaches the repositories.
    IF zcl_tr_auth=>is_logged_in( ) = abap_true.
      WRITE: / |{ sy-uname } is logged in to GitHub as { zcl_tr_auth=>login( ) }|.
      DATA(missing) = zcl_tr_auth=>repositories_without_access( ).
      IF missing IS INITIAL.
        WRITE: / 'The account has access to every linked repository.'.
      ELSE.
        WRITE: / zcl_tr_auth=>describe_no_access( missing ).
      ENDIF.
    ELSE.
      WRITE: / zcl_tr_auth=>not_logged_in_text( ).
    ENDIF.
  ENDMETHOD.


  METHOD logout.
    IF zcl_tr_auth=>is_logged_in( ) = abap_false.
      WRITE: / |{ sy-uname } was not logged in|.
      RETURN.
    ENDIF.
    DATA(login) = zcl_tr_auth=>login( ).
    zcl_tr_auth=>remove( ).
    WRITE: / |Token of { login } removed from { sy-sysid }. To revoke it on GitHub too: Settings, Applications, Authorized GitHub Apps.|.
  ENDMETHOD.


ENDCLASS.


START-OF-SELECTION.
  TRY.
      NEW lcl_login( )->run( ).
    CATCH zcx_abapgit_exception INTO DATA(error).
      WRITE: / error->get_text( ).
      MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
  ENDTRY.
