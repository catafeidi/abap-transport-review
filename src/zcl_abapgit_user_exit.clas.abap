CLASS zcl_abapgit_user_exit DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES zif_abapgit_exit .
  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_git_host TYPE string VALUE 'github.com' ##NO_TEXT.
    CONSTANTS c_git_destination TYPE rfcdest VALUE 'Z_GITHUB_GIT' ##NO_TEXT.
ENDCLASS.



CLASS ZCL_ABAPGIT_USER_EXIT IMPLEMENTATION.


  METHOD zif_abapgit_exit~adjust_display_commit_url.
  ENDMETHOD.


  METHOD zif_abapgit_exit~adjust_display_filename.
  ENDMETHOD.


  METHOD zif_abapgit_exit~allow_sap_objects.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_committer_info.
    " Without this, abapGit commits as <user>@localhost.
    DATA ls_address TYPE bapiaddr3.
    DATA lt_return TYPE STANDARD TABLE OF bapiret2.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username = sy-uname
      IMPORTING
        address  = ls_address
      TABLES
        return   = lt_return.

    IF ls_address-fullname IS NOT INITIAL.
      cv_name = ls_address-fullname.
    ENDIF.
    IF ls_address-e_mail IS NOT INITIAL.
      cv_email = ls_address-e_mail.
    ENDIF.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_local_host.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_max_parallel_processes.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_proxy_authentication.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_proxy_port.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_proxy_url.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_rfc_server_group.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_supported_data_objects.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_supported_object_types.
  ENDMETHOD.


  METHOD zif_abapgit_exit~change_tadir.
  ENDMETHOD.


METHOD zif_abapgit_exit~create_http_client.
*----------------------------------------------------------------------*
* abapGit user exit ZCL_ABAPGIT_USER_EXIT, method
* ZIF_ABAPGIT_EXIT~CREATE_HTTP_CLIENT. Replaces the version that built
* the client from an SM59 destination for GitHub.
*
* Git traffic to github.com runs with the GitHub token of the SAP user,
* from an encrypted cluster table (class ZCL_TR_AUTH). No stored user, no
* shared account: a user without a token gets a clear error, in a job
* that cancels the job with the text in the job log.
*
* GitHub takes a token on its Git endpoint only as Basic authentication
* (user x-access-token), not as a Bearer header, so the header is set
* here. abapGit keeps that header for the session after the first call.
*
* SE24, ZCL_ABAPGIT_USER_EXIT, replace the method body with this one.
* The constants c_git_host and c_git_destination of the class are no
* longer needed. ABAP 7.40 syntax.
*----------------------------------------------------------------------*
  CONSTANTS ssl_client TYPE ssfapplssl VALUE 'ANONYM'.

  " Only the host github.com itself gets the token. A URL that merely contains the name, such
  " as https://github.com.example.org/ or https://example.org/github.com/, does not.
  IF zcl_tr_auth=>is_github_url( iv_url ) = abap_false.
    RETURN.
  ENDIF.

  " Raises "<user> is not logged in to GitHub ..." when there is no token.
  DATA(authorization) = zcl_tr_auth=>git_authorization( ).

  cl_http_client=>create_by_url(
    EXPORTING
      url    = iv_url
      ssl_id = ssl_client
    IMPORTING
      client = ri_client
    EXCEPTIONS
      OTHERS = 1 ).
  IF sy-subrc <> 0.
    zcx_abapgit_exception=>raise( |no HTTP client for { iv_url }| ).
  ENDIF.

  " No logon popup, not even in the dialog: the token decides.
  ri_client->propertytype_logon_popup = if_http_client=>co_disabled.
  ri_client->request->set_header_field(
    name  = 'authorization'
    value = authorization ).
ENDMETHOD.


  METHOD zif_abapgit_exit~custom_serialize_abap_clif.
  ENDMETHOD.


  METHOD zif_abapgit_exit~deserialize_postprocess.
  ENDMETHOD.


  METHOD zif_abapgit_exit~determine_transport_request.
  ENDMETHOD.


  METHOD zif_abapgit_exit~enhance_any_toolbar.
  ENDMETHOD.


  METHOD zif_abapgit_exit~enhance_repo_toolbar.
  ENDMETHOD.


  METHOD zif_abapgit_exit~get_ci_tests.
  ENDMETHOD.


  METHOD zif_abapgit_exit~get_ssl_id.
  ENDMETHOD.


  METHOD zif_abapgit_exit~http_client.
  ENDMETHOD.


  METHOD zif_abapgit_exit~on_event.
  ENDMETHOD.


  METHOD zif_abapgit_exit~pre_calculate_repo_status.
  ENDMETHOD.


  METHOD zif_abapgit_exit~serialize_postprocess.
  ENDMETHOD.


  METHOD zif_abapgit_exit~validate_before_push.
  ENDMETHOD.


  METHOD zif_abapgit_exit~wall_message_list.
  ENDMETHOD.


  METHOD zif_abapgit_exit~wall_message_repo.
  ENDMETHOD.
ENDCLASS.
