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
