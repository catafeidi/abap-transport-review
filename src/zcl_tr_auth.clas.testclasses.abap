CLASS ltc_tokens DEFINITION DEFERRED.
CLASS zcl_tr_auth DEFINITION LOCAL FRIENDS ltc_tokens.

" Tests of the code of a login that is kept between two runs (the ADT console). They write to the
" cluster table INDX, to the row of the user who runs them only (id PEND:<user>), and remove it again.
" That is why the risk level is DANGEROUS: run them on a development system.
CLASS ltc_pending_code DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL DANGEROUS.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS device
      IMPORTING
        expires_in    TYPE i DEFAULT 900
      RETURNING
        VALUE(result) TYPE zcl_tr_auth=>ty_device_code.
    METHODS nothing_kept_gives_nothing FOR TESTING.
    METHODS kept_code_is_returned FOR TESTING.
    METHODS forgotten_code_is_gone FOR TESTING.
    METHODS expired_code_is_gone FOR TESTING.
    METHODS keeping_again_replaces FOR TESTING.
ENDCLASS.


CLASS ltc_pending_code IMPLEMENTATION.

  METHOD teardown.
    zcl_tr_auth=>forget_device_code( ).
  ENDMETHOD.


  METHOD device.
    result = VALUE #( device_code      = 'DEVICE-CODE'
                      user_code        = 'ABCD-1234'
                      verification_uri = 'https://github.com/login/device'
                      expires_in       = expires_in
                      interval         = 5 ).
  ENDMETHOD.


  METHOD nothing_kept_gives_nothing.
    zcl_tr_auth=>forget_device_code( ).

    cl_abap_unit_assert=>assert_initial( zcl_tr_auth=>kept_device_code( ) ).
  ENDMETHOD.


  METHOD kept_code_is_returned.
    zcl_tr_auth=>keep_device_code( device( ) ).

    DATA(kept) = zcl_tr_auth=>kept_device_code( ).

    cl_abap_unit_assert=>assert_equals( exp = device( )
                                        act = kept ).
  ENDMETHOD.


  METHOD forgotten_code_is_gone.
    zcl_tr_auth=>keep_device_code( device( ) ).

    zcl_tr_auth=>forget_device_code( ).

    cl_abap_unit_assert=>assert_initial( zcl_tr_auth=>kept_device_code( ) ).
  ENDMETHOD.


  METHOD expired_code_is_gone.
    " A code that is valid for 0 seconds is expired when it is read, and is removed then.
    zcl_tr_auth=>keep_device_code( device( 0 ) ).

    cl_abap_unit_assert=>assert_initial( zcl_tr_auth=>kept_device_code( ) ).
    cl_abap_unit_assert=>assert_initial( zcl_tr_auth=>kept_device_code( ) ).
  ENDMETHOD.


  METHOD keeping_again_replaces.
    zcl_tr_auth=>keep_device_code( device( ) ).
    DATA(second) = device( ).
    second-user_code = 'WXYZ-9876'.
    zcl_tr_auth=>keep_device_code( second ).

    cl_abap_unit_assert=>assert_equals( exp = second
                                        act = zcl_tr_auth=>kept_device_code( ) ).
  ENDMETHOD.

ENDCLASS.


" The token goes to the host github.com and nowhere else.
CLASS ltc_github_url DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS is_github_url
      IMPORTING
        url           TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS the_host_itself FOR TESTING.
    METHODS upper_case_host FOR TESTING.
    METHODS with_the_default_port FOR TESTING.
    METHODS host_with_the_name_as_prefix FOR TESTING.
    METHODS name_in_the_path FOR TESTING.
    METHODS name_as_user_info FOR TESTING.
    METHODS other_scheme FOR TESTING.
    METHODS another_port FOR TESTING.
    METHODS api_host_is_not_the_git_host FOR TESTING.
    METHODS empty_url FOR TESTING.
ENDCLASS.


CLASS ltc_github_url IMPLEMENTATION.

  METHOD is_github_url.
    result = zcl_tr_auth=>is_github_url( url ).
  ENDMETHOD.


  METHOD the_host_itself.
    cl_abap_unit_assert=>assert_true( is_github_url( `https://github.com/owner/repo.git` ) ).
  ENDMETHOD.


  METHOD upper_case_host.
    cl_abap_unit_assert=>assert_true( is_github_url( `HTTPS://GitHub.com/owner/repo.git` ) ).
  ENDMETHOD.


  METHOD with_the_default_port.
    cl_abap_unit_assert=>assert_true( is_github_url( `https://github.com:443/owner/repo.git` ) ).
  ENDMETHOD.


  METHOD host_with_the_name_as_prefix.
    cl_abap_unit_assert=>assert_false( is_github_url( `https://github.com.evil.example/x.git` ) ).
  ENDMETHOD.


  METHOD name_in_the_path.
    cl_abap_unit_assert=>assert_false( is_github_url( `https://evil.example/github.com/x.git` ) ).
  ENDMETHOD.


  METHOD name_as_user_info.
    cl_abap_unit_assert=>assert_false( is_github_url( `https://github.com@evil.example/x.git` ) ).
  ENDMETHOD.


  METHOD other_scheme.
    cl_abap_unit_assert=>assert_false( is_github_url( `http://github.com/owner/repo.git` ) ).
  ENDMETHOD.


  METHOD another_port.
    cl_abap_unit_assert=>assert_false( is_github_url( `https://github.com:8443/owner/repo.git` ) ).
  ENDMETHOD.


  METHOD api_host_is_not_the_git_host.
    cl_abap_unit_assert=>assert_false( is_github_url( `https://api.github.com/user` ) ).
  ENDMETHOD.


  METHOD empty_url.
    cl_abap_unit_assert=>assert_false( is_github_url( `` ) ).
  ENDMETHOD.

ENDCLASS.


" Token renewal: when a token is renewed, and what the token endpoint of GitHub answers.
CLASS ltc_tokens DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    CONSTANTS now TYPE timestampl VALUE '20261026120000'.

    METHODS no_expiry_never_renews FOR TESTING.
    METHODS far_from_expiry FOR TESTING.
    METHODS just_outside_the_margin FOR TESTING.
    METHODS inside_the_margin FOR TESTING.
    METHODS already_expired FOR TESTING.
    METHODS expiring_token_answer FOR TESTING RAISING zcx_abapgit_exception.
    METHODS non_expiring_token_answer FOR TESTING RAISING zcx_abapgit_exception.
    METHODS refused_refresh_token FOR TESTING RAISING zcx_abapgit_exception.
    METHODS answer_without_token FOR TESTING.

    METHODS needs_refresh
      IMPORTING
        expires_at    TYPE timestampl
      RETURNING
        VALUE(result) TYPE abap_bool.
ENDCLASS.


CLASS ltc_tokens IMPLEMENTATION.

  METHOD needs_refresh.
    result = zcl_tr_auth=>needs_refresh( expires_at = expires_at now = now ).
  ENDMETHOD.


  METHOD no_expiry_never_renews.
    cl_abap_unit_assert=>assert_false( needs_refresh( VALUE #( ) ) ).
  ENDMETHOD.


  METHOD far_from_expiry.
    cl_abap_unit_assert=>assert_false( needs_refresh( '20261026200000' ) ).
  ENDMETHOD.


  METHOD just_outside_the_margin.
    " 5 minutes and 1 second left
    cl_abap_unit_assert=>assert_false( needs_refresh( '20261026120501' ) ).
  ENDMETHOD.


  METHOD inside_the_margin.
    " 4 minutes left
    cl_abap_unit_assert=>assert_true( needs_refresh( '20261026120400' ) ).
  ENDMETHOD.


  METHOD already_expired.
    cl_abap_unit_assert=>assert_true( needs_refresh( '20261026080000' ) ).
  ENDMETHOD.


  METHOD expiring_token_answer.
    DATA(tokens) = zcl_tr_auth=>tokens_from_response(
      `{"access_token":"ghu_access","expires_in":28800,"refresh_token":"ghr_refresh",` &&
      `"refresh_token_expires_in":15897600,"token_type":"bearer","scope":""}` ).

    cl_abap_unit_assert=>assert_equals( act = tokens-token         exp = `ghu_access` ).
    cl_abap_unit_assert=>assert_equals( act = tokens-refresh_token exp = `ghr_refresh` ).
    cl_abap_unit_assert=>assert_equals( act = tokens-expires_in    exp = 28800 ).
    cl_abap_unit_assert=>assert_initial( tokens-error ).
  ENDMETHOD.


  METHOD non_expiring_token_answer.
    DATA(tokens) = zcl_tr_auth=>tokens_from_response(
      `{"access_token":"ghu_access","token_type":"bearer","scope":""}` ).

    cl_abap_unit_assert=>assert_equals( act = tokens-token exp = `ghu_access` ).
    cl_abap_unit_assert=>assert_initial( tokens-refresh_token ).
    cl_abap_unit_assert=>assert_initial( tokens-expires_in ).
  ENDMETHOD.


  METHOD refused_refresh_token.
    DATA(tokens) = zcl_tr_auth=>tokens_from_response(
      `{"error":"bad_refresh_token","error_description":"The refresh token passed is incorrect or expired."}` ).

    cl_abap_unit_assert=>assert_equals( act = tokens-error exp = `bad_refresh_token` ).
    cl_abap_unit_assert=>assert_initial( tokens-token ).
  ENDMETHOD.


  METHOD answer_without_token.
    TRY.
        zcl_tr_auth=>tokens_from_response( `{"token_type":"bearer"}` ).
        cl_abap_unit_assert=>fail( 'an answer without token and without error must raise' ).
      CATCH zcx_abapgit_exception.
        RETURN.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
