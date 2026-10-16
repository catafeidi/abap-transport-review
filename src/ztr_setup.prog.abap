*&---------------------------------------------------------------------*
*& Report ZTR_SETUP
*&---------------------------------------------------------------------*
*& Sets up and checks the GitHub workflow tools on this system, after
*& they were pulled with abapGit from the repository of these tools.
*&
*& What it does:
*&   - shows the settings of this system and, with "Write the settings",
*&     saves them: the STVARV parameters ZTR_CLIENT_ID (client ID of
*&     the GitHub App), ZTR_PACKAGES (package pattern under Git),
*&     ZTR_REQUIRE_COMPLETE, ZTR_VARIANT_PATTERN / _PACKAGE, and
*&     the configuration of the abaplint client (server, dependency
*&     depth, one configuration per package) if that client is installed,
*&     and the translation check: ZTR_TRANSL_LANGUAGES (required
*&     languages), ZTR_TRANSL_MODE (OFF, INFORM, BLOCK), ZTR_TRANSL_EXCLUDE
*&     (object names never checked) and ZTR_TRANSL_RECORD;
*&   - checks everything the workflow needs and lists it with a green,
*&     yellow or red light: abapGit, the user exit, the release check
*&     (BAdI), GitHub over SSL, the device flow of the GitHub App, the
*&     login of the current user, the linked repositories and the access
*&     to them, the release settings, abaplint, the translation check.
*&
*& Without "Write the settings" nothing is changed: it is a check run.
*&
*& What it cannot do is listed at the end of its output: certificates in
*& STRUST, the GitHub App on GitHub, the login of each developer, linking
*& the repositories in abapGit, activating the abaplint check in SCI, the
*& ATC settings, the firewall of the abaplint server.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_setup NO STANDARD PAGE HEADING LINE-SIZE 200.

DATA g_package  TYPE devclass.
DATA g_language TYPE spras.
DATA g_objname  TYPE trobj_name.

" Texts of the selection screen, set in code so that no text elements
" have to be maintained. The COMMENT statements declare the variables.
SELECTION-SCREEN BEGIN OF BLOCK git WITH FRAME TITLE t_git.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_client FOR FIELD p_client.
PARAMETERS p_client TYPE c LENGTH 40 LOWER CASE.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_pack FOR FIELD p_pack.
PARAMETERS p_pack   TYPE devclass.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_reqc   AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_reqc FOR FIELD p_reqc.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_vpat FOR FIELD p_vpat.
PARAMETERS p_vpat   TYPE c LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_vpkg FOR FIELD p_vpkg.
PARAMETERS p_vpkg   TYPE devclass.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK git.

SELECTION-SCREEN BEGIN OF BLOCK lint WITH FRAME TITLE t_lint.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_alurl FOR FIELD p_alurl.
PARAMETERS p_alurl  TYPE c LENGTH 120 LOWER CASE VISIBLE LENGTH 40.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_aldep FOR FIELD p_aldep.
PARAMETERS p_aldep  TYPE i DEFAULT 20.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_alver FOR FIELD p_alver.
PARAMETERS p_alver  TYPE c LENGTH 20 LOWER CASE DEFAULT 'v740sp08'.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_alpkg FOR FIELD s_alpkg.
SELECT-OPTIONS s_alpkg FOR g_package NO INTERVALS.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_clean  AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_clean FOR FIELD p_clean.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_repl   AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_repl FOR FIELD p_repl.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK lint.

SELECTION-SCREEN BEGIN OF BLOCK transl WITH FRAME TITLE t_transl.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_tlang FOR FIELD s_tlang.
SELECT-OPTIONS s_tlang FOR g_language NO INTERVALS.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_tmode FOR FIELD p_tmode.
PARAMETERS p_tmode TYPE c LENGTH 6 AS LISTBOX VISIBLE LENGTH 30.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_trec AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_trec FOR FIELD p_trec.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_texcl FOR FIELD s_texcl.
SELECT-OPTIONS s_texcl FOR g_objname.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK transl.

SELECTION-SCREEN BEGIN OF BLOCK mode WITH FRAME TITLE t_mode.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_write  AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_write FOR FIELD p_write.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK mode.

INITIALIZATION.
  t_git    = 'GitHub workflow'.
  t_client = 'Client ID of the GitHub App'.
  t_pack   = 'Packages under Git, e.g. Z*'.
  t_reqc   = 'Refuse requests with entries that cannot be written to Git'.
  t_vpat   = 'Report variants: name pattern'.
  t_vpkg   = 'Report variants: package'.
  t_lint   = 'abaplint client (only if it is installed)'.
  t_alurl  = 'abaplint server, http://host:3000'.
  t_aldep  = 'Dependency depth (0 = default 20)'.
  t_alver  = 'Syntax version for new packages'.
  t_alpkg  = 'Packages to configure'.
  t_clean  = 'Also the Clean ABAP rules (for packages that follow them)'.
  t_repl   = 'Replace the configuration of a package that has one'.
  t_transl = 'Translation check at release'.
  t_tlang  = 'Required languages'.
  t_tmode  = 'Mode'.
  t_texcl  = 'Object names never checked'.
  t_trec   = 'At release: record the existing translations in the task'.
  t_mode   = 'Mode'.
  t_write  = 'Write the settings above. Without it: only check'.

  " The values this system has today.
  p_client = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-client_id ).
  p_pack   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-packages ).
  p_reqc   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-require_complete ).
  p_vpat   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_pattern ).
  p_vpkg   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_package ).
  p_tmode = zcl_tr_transl_check=>configured_mode( ).
  p_trec  = zcl_tr_transl_check=>configured_record( ).
  LOOP AT zcl_tr_transl_check=>configured_languages( ) INTO DATA(g_tlang).
    APPEND VALUE #( sign = 'I' option = 'EQ' low = g_tlang ) TO s_tlang.
  ENDLOOP.
  LOOP AT zcl_tr_transl_check=>configured_exclusions( ) INTO DATA(g_texcl).
    APPEND VALUE #( sign = g_texcl-sign option = g_texcl-option low = g_texcl-low high = g_texcl-high ) TO s_texcl.
  ENDLOOP.
  zcl_tr_setup=>abaplint_setting( IMPORTING url = DATA(g_url) depth = DATA(g_depth) ).
  IF g_url IS NOT INITIAL.
    p_alurl = g_url.
    p_aldep = g_depth.
  ENDIF.

AT SELECTION-SCREEN OUTPUT.
  " The three modes of the translation check as a list box.
  CALL FUNCTION 'VRM_SET_VALUES'
    EXPORTING
      id     = 'P_TMODE'
      values = VALUE vrm_values( ( key = zcl_tr_transl_check=>mode-off    text = 'OFF: no check at release' )
                                 ( key = zcl_tr_transl_check=>mode-inform text = 'INFORM: show, release goes on' )
                                 ( key = zcl_tr_transl_check=>mode-block  text = 'BLOCK: refuse the release' ) )
    EXCEPTIONS
      OTHERS = 1.

START-OF-SELECTION.
  DATA(g_settings) = VALUE zcl_tr_setup=>ty_settings(
    client_id        = p_client
    packages         = p_pack
    require_complete = p_reqc
    variant_pattern  = p_vpat
    variant_package  = p_vpkg
    abaplint_url     = p_alurl
    abaplint_depth   = p_aldep
    abaplint_version = p_alver
    clean_abap       = p_clean
    replace_existing = p_repl
    transl_mode      = COND #( WHEN p_tmode IS INITIAL THEN zcl_tr_transl_check=>mode-off ELSE CONV string( p_tmode ) )
    transl_record    = p_trec
    write            = p_write ).
  LOOP AT s_tlang INTO DATA(g_selected_language) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
    APPEND g_selected_language-low TO g_settings-transl_languages.
  ENDLOOP.
  LOOP AT s_texcl INTO DATA(g_selected_name) WHERE low IS NOT INITIAL.
    APPEND VALUE #( sign = g_selected_name-sign option = g_selected_name-option
                    low  = g_selected_name-low  high   = g_selected_name-high ) TO g_settings-transl_exclude.
  ENDLOOP.
  LOOP AT s_alpkg INTO DATA(g_selected) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
    APPEND g_selected-low TO g_settings-abaplint_packages.
  ENDLOOP.

  DATA(g_lines) = NEW zcl_tr_setup( g_settings )->run( ).
  DATA g_icon TYPE c LENGTH 4.
  LOOP AT g_lines INTO DATA(g_line).
    CASE g_line-kind.
      WHEN zcl_tr_setup=>state-heading.
        SKIP.
        FORMAT COLOR COL_HEADING INTENSIFIED ON.
        WRITE / g_line-text.
        FORMAT RESET.
      WHEN zcl_tr_setup=>state-blank.
        SKIP.
      WHEN zcl_tr_setup=>state-note.
        WRITE / g_line-text.
      WHEN OTHERS.
        CASE g_line-kind.
          WHEN zcl_tr_setup=>state-ok.
            g_icon = icon_green_light.
          WHEN zcl_tr_setup=>state-todo.
            g_icon = icon_red_light.
          WHEN OTHERS.
            g_icon = icon_yellow_light.
        ENDCASE.
        WRITE: / g_icon AS ICON, g_line-text.
    ENDCASE.
  ENDLOOP.
