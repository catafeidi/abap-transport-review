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
*&     depth, one configuration per package) if that client is installed;
*&   - checks everything the workflow needs and lists it with a green,
*&     yellow or red light: abapGit, the user exit, the release check
*&     (BAdI), GitHub over SSL, the device flow of the GitHub App, the
*&     login of the current user, the linked repositories and the access
*&     to them, the release settings, abaplint.
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

DATA g_package TYPE devclass.

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
  t_mode   = 'Mode'.
  t_write  = 'Write the settings above. Without it: only check'.

  " The values this system has today.
  p_client = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-client_id ).
  p_pack   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-packages ).
  p_reqc   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-require_complete ).
  p_vpat   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_pattern ).
  p_vpkg   = zcl_tr_setup=>parameter( zcl_tr_setup=>parameter_name-variant_package ).
  zcl_tr_setup=>abaplint_setting( IMPORTING url = DATA(g_url) depth = DATA(g_depth) ).
  IF g_url IS NOT INITIAL.
    p_alurl = g_url.
    p_aldep = g_depth.
  ENDIF.

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
    write            = p_write ).
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
