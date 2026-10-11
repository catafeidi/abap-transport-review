class ZCL_IM_TR_RELEASE_CHECK definition
  public
  final
  create public .

public section.

  interfaces IF_EX_CTS_REQUEST_CHECK .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_TR_RELEASE_CHECK IMPLEMENTATION.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_ADD_OBJECTS.
  endmethod.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_CHANGING_OWNER.
  endmethod.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_CREATION.
  endmethod.


METHOD if_ex_cts_request_check~check_before_release.
*----------------------------------------------------------------------*
* BAdI implementation for CTS_REQUEST_CHECK (classic BAdI).
*
*   Anybody who releases -> must be logged in to GitHub. Everything on
*                       GitHub runs under that person's own account. In
*                       the dialog the login popup comes up right here,
*                       and after the login the release goes on. In the
*                       background or from ADT the release is refused
*                       with the name of the login report.
*   Task released    -> start the job that pushes the task to its review
*                       branch on GitHub and opens the pull request.
*   Request released -> refuse the release unless the current state of
*                       every object of the request is reviewed: it is on
*                       the review branch and the pull request of that
*                       branch is approved, or it is on the base branch
*                       already, after a merge by hand.
*                       With an approved pull request the release goes on
*                       and a job squashes and merges the pull request as
*                       soon as the request really is released.
*                       If something is on neither branch, the objects of
*                       the request are pushed to the review branch, so
*                       that also a change that never went through a task
*                       gets reviewed, and the developer is told so.
*
* A refusal is always visible:
*   release in the dialog     -> popup with the reason, then the error
*   release in the background -> the job RELEASE OF <request> is
*                                cancelled and its log holds the reason
*   release from ADT          -> the error message in Eclipse
*
* Implementation ZTR_RELEASE_CHECK, class ZCL_IM_TR_RELEASE_CHECK, created in SE19.
* Paste ONLY the method below into
* IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_RELEASE. Leave the other four
* methods empty. Activate the class and the implementation.
*
* When it runs: BEFORE the release of a task or request
* (TRINT_RELEASE_WITHOUT_TRANSP, form USER_EXIT_BEFORE_RELEASE), in the
* dialog of the developer or in the release job. The check of a request
* compares with GitHub and takes some seconds.
*
* Way out for an emergency: a request whose short text contains #NOREVIEW
* is released without the check. The marker stays visible in the request.
*
* The check does nothing, and never stops a release, when
*   - STVARV parameter ZTR_DISABLED is X (the switch to turn the tools off), or
*   - STVARV parameter ZTR_CLIENT_ID is empty: the system is not set up yet
*     (report ZTR_SETUP writes it).
*
* If the check itself fails, for example because GitHub cannot be reached
* or an unexpected error occurs, the release is NOT refused (it fails
* open). No job is started. In the dialog the developer gets an
* information message that the review was not checked; in the background
* nothing is shown. Without a reviewed pull request the base branch then
* takes the change only if its rules allow it.
*
* If this class cannot be loaded at all, for example because class
* ZCL_TR_AUTH or abapGit was changed and is inactive, every release of the
* system fails with a short dump. Then deactivate the implementation
* ZTR_RELEASE_CHECK in SE19; the switch ZTR_DISABLED cannot help there.
* ABAP 7.40 syntax.
*----------------------------------------------------------------------*
  CONSTANTS development_task  TYPE trfunction VALUE 'S'.
  CONSTANTS repair_task       TYPE trfunction VALUE 'R'.
  CONSTANTS workbench_request TYPE trfunction VALUE 'K'.
  CONSTANTS customizing_task  TYPE trfunction VALUE 'Q'.
  CONSTANTS customizing_request TYPE trfunction VALUE 'W'.
  CONSTANTS skip_marker       TYPE string VALUE '#NOREVIEW'.
  " Results of report ZTR_PUSH_TRANSPORT in check mode.
  CONSTANTS check_memory      TYPE c LENGTH 20 VALUE 'ZTR_CHECK'.
  CONSTANTS base_is_complete  TYPE c LENGTH 1 VALUE 'O'.
  CONSTANTS review_is_approved TYPE c LENGTH 1 VALUE 'A'.
  CONSTANTS review_is_pending TYPE c LENGTH 1 VALUE 'P'.
  CONSTANTS files_differ      TYPE c LENGTH 1 VALUE 'D'.
  CONSTANTS push_is_running   TYPE c LENGTH 1 VALUE 'B'.
  CONSTANTS not_in_git        TYPE c LENGTH 1 VALUE 'U'.

  DATA job_name        TYPE tbtcjob-jobname.
  DATA job_number      TYPE tbtcjob-jobcount.
  DATA is_review_push  TYPE abap_bool.
  DATA is_merge        TYPE abap_bool.
  DATA is_refused      TYPE abap_bool.
  DATA status          TYPE c LENGTH 1.
  DATA differences     TYPE i.
  DATA detail          TYPE string.
  DATA link            TYPE string.
  DATA fields          TYPE STANDARD TABLE OF sval.
  DATA returncode      TYPE c LENGTH 1.
  DATA github_login    TYPE string.
  DATA login_failure   TYPE string.
  DATA no_access       TYPE string.
  " Message 001 of class 00 shows its four variables one after the other.
  DATA part_1          TYPE sy-msgv1.
  DATA part_2          TYPE sy-msgv2.
  DATA part_3          TYPE sy-msgv3.
  DATA part_4          TYPE sy-msgv4.
  DATA is_under_git    TYPE abap_bool.
  DATA object_package  TYPE devclass.
  DATA directory_entry TYPE tadir.

  " Nothing happens before the tools are set up, and nothing when they
  " are switched off. Read from STVARV directly: no other class is needed.
  SELECT SINGLE low FROM tvarvc
    INTO @DATA(switch_off)
    WHERE name = 'ZTR_DISABLED' AND type = 'P' AND numb = '0000'.
  IF switch_off = abap_true.
    RETURN.
  ENDIF.
  SELECT SINGLE low FROM tvarvc
    INTO @DATA(client_id)
    WHERE name = 'ZTR_CLIENT_ID' AND type = 'P' AND numb = '0000'.
  IF client_id IS INITIAL.
    RETURN.
  ENDIF.

  TRY.
  " Only tasks and requests that carry objects of the packages under Git
  " on this system: STVARV ZTR_PACKAGES, default Z*. The package of an
  " object is read from the object directory; only an object without
  " an entry (a deleted one) is judged by its name.
  DATA(package_pattern) = zcl_tr_auth=>packages( ).
  LOOP AT objects INTO DATA(object_entry).
    CLEAR: object_package, directory_entry.
    IF object_entry-pgmid = 'R3TR'.
      SELECT SINGLE devclass FROM tadir
        INTO @object_package
        WHERE pgmid    = 'R3TR'
          AND object   = @object_entry-object
          AND obj_name = @object_entry-obj_name.
    ELSE.
      CALL FUNCTION 'TR_CHECK_TYPE'
        EXPORTING
          wi_e071  = VALUE e071( pgmid = object_entry-pgmid object = object_entry-object obj_name = object_entry-obj_name )
        IMPORTING
          we_tadir = directory_entry
        EXCEPTIONS
          OTHERS   = 1.
      IF sy-subrc = 0 AND directory_entry-obj_name IS NOT INITIAL.
        SELECT SINGLE devclass FROM tadir
          INTO @object_package
          WHERE pgmid    = @directory_entry-pgmid
            AND object   = @directory_entry-object
            AND obj_name = @directory_entry-obj_name.
      ENDIF.
    ENDIF.

    IF object_package IS NOT INITIAL.
      IF object_package CP package_pattern.
        is_under_git = abap_true.
        EXIT.
      ENDIF.
    ELSEIF object_entry-obj_name CP package_pattern.
      is_under_git = abap_true.
      EXIT.
    ENDIF.
  ENDLOOP.
  IF is_under_git = abap_false.
    RETURN.
  ENDIF.

  " Workbench and customizing, tasks and requests. Never transports of
  " copies, relocations or other types.
  IF type <> development_task AND type <> repair_task AND type <> workbench_request AND
     type <> customizing_task AND type <> customizing_request.
    RETURN.
  ENDIF.
  DATA(is_request) = xsdbool( type = workbench_request OR type = customizing_request ).
  IF is_request = abap_true AND text CS skip_marker.
    RETURN.
  ENDIF.

* ---- the person who releases must be logged in to GitHub ------------
  " The jobs run as this user and push with this user's GitHub account.
  " On the screen the login happens right here, once.
  IF zcl_tr_auth=>is_logged_in( ) = abap_false AND
     dialog = abap_true AND adt = abap_false AND sy-batch = abap_false.
    TRY.
        github_login = zcl_tr_auth=>login_with_popup( ).
      CATCH zcx_abapgit_exception INTO DATA(login_error).
        login_failure = login_error->get_text( ).
    ENDTRY.
    IF github_login IS NOT INITIAL.
      MESSAGE |Logged in to GitHub as { github_login }| TYPE 'S'.
    ENDIF.
  ENDIF.

  " Logged in, but the account cannot reach a repository: the push would
  " fail. Say it now, while the developer can still ask for the access.
  IF zcl_tr_auth=>is_logged_in( ) = abap_true.
    TRY.
        no_access = zcl_tr_auth=>repositories_without_access( ).
      CATCH zcx_abapgit_exception.
        CLEAR no_access.   " GitHub not reachable: the push job will say so
    ENDTRY.
  ENDIF.

  IF no_access = zcl_tr_auth=>token_rejected.
    part_1 = |GitHub does not accept the token of { sy-uname }|.
    part_2 = | any more (revoked or expired).|.
    part_3 = ' Log in again: report'.
    part_4 = | { zcl_tr_auth=>login_report }, then release again.|.
    is_refused = abap_true.

  ELSEIF no_access IS NOT INITIAL.
    part_1 = |GitHub account { zcl_tr_auth=>login( ) } of { sy-uname }|.
    part_2 = | has no access to: { no_access }.|.
    part_3 = ' Ask the repository admin for it,'.
    part_4 = ' then release again.'.
    is_refused = abap_true.

  ELSEIF zcl_tr_auth=>is_logged_in( ) = abap_false.
    part_1 = |{ sy-uname } is not logged in to GitHub on { sy-sysid }.|.
    IF dialog = abap_true AND adt = abap_false AND sy-batch = abap_false.
      part_2 = | { login_failure }|.
      " Each part holds 50 characters.
      part_3 = ' Log in by releasing again, or via report'.
      part_4 = | { zcl_tr_auth=>login_report }, then release again.|.
    ELSE.
      part_2 = | Nothing can be pushed for review. Run report|.
      part_3 = | { zcl_tr_auth=>login_report } once (SE38), or in ADT|.
      part_4 = ' class ZCL_TR_CONSOLE_LOGIN, then release again.'.
    ENDIF.
    is_refused = abap_true.

  ELSEIF is_request = abap_false.
*   ---- task: push it to the review branch ----------------------------
    is_review_push = abap_true.

  ELSE.
*   ---- request: only after the review --------------------------------
    " Ask the report whether everything is reviewed. It runs here,
    " before the release, because the result decides about the release.
    FREE MEMORY ID check_memory.
    SUBMIT ztr_push_transport
      WITH p_trkorr = request
      WITH p_check  = abap_true
      EXPORTING LIST TO MEMORY
      AND RETURN.
    IMPORT status      = status
           differences = differences
           detail      = detail
           link        = link
           FROM MEMORY ID check_memory.
    IF sy-subrc <> 0.
      CLEAR status.
      detail = 'no result from ZTR_PUSH_TRANSPORT'.
    ENDIF.

    CASE status.
      WHEN base_is_complete.
        RETURN.

      WHEN review_is_approved.
        " Everything is on the review branch and its pull request is
        " approved. Release, and merge once the release went through.
        is_merge = abap_true.

      WHEN review_is_pending.
        part_1 = |{ request } is not released:|.
        part_2 = | { detail }.|.
        part_3 = ' Get the pull request approved on GitHub,'.
        part_4 = ' then release again.'.
        is_refused = abap_true.

      WHEN files_differ.
        " Something of the request is on no branch. Make sure that
        " everything is on the review branch, then say so.
        is_review_push = abap_true.
        part_1 = |{ request }: { differences } file(s) not reviewed yet.|.
        part_2 = ' They are pushed to the review branch now.'.
        part_3 = ' Get the pull request approved on GitHub,'.
        part_4 = ' then release again.'.
        is_refused = abap_true.

      WHEN push_is_running.
        part_1 = 'Another push to GitHub is running.'.
        part_2 = ' Release the request again in a minute.'.
        is_refused = abap_true.

      WHEN not_in_git.
        " Something of the request cannot be written to Git at all, so it
        " could never be reviewed there.
        part_1 = |{ request }: not everything can go to Git:|.
        part_2 = | { detail }.|.
        part_3 = ' Remove it from the request, or release'.
        part_4 = ' with #NOREVIEW in the request text.'.
        is_refused = abap_true.

      WHEN OTHERS.
        " The check itself failed. Do not stop every release for that.
        IF dialog = abap_true.
          part_1 = |The review of { request } was NOT checked:|.
          part_2 = | { detail }|.
          MESSAGE ID '00' TYPE 'I' NUMBER '001' WITH part_1 part_2.
        ENDIF.
        RETURN.
    ENDCASE.
  ENDIF.

* ---- push to the review branch, or merge, as a background job --------
  " No push or merge here. It takes a while and would freeze the screen,
  " and a merge must not happen before the release went through.
  " For a task and for a merge the job waits until the task or request
  " really is released and gives up quietly if the release was cancelled.
  IF is_review_push = abap_true OR is_merge = abap_true.
    IF is_merge = abap_true.
      job_name = |GIT_MERGE_{ request }|.
    ELSE.
      job_name = |GIT_REVIEW_{ request }|.
    ENDIF.

    CALL FUNCTION 'JOB_OPEN'
      EXPORTING
        jobname          = job_name
      IMPORTING
        jobcount         = job_number
      EXCEPTIONS
        cant_create_job  = 1
        invalid_job_data = 2
        jobname_missing  = 3
        OTHERS           = 4.
    IF sy-subrc = 0.
      IF is_request = abap_true AND is_merge = abap_false.
        SUBMIT ztr_push_transport
          WITH p_trkorr = request
          WITH p_review = abap_true
          VIA JOB job_name NUMBER job_number
          AND RETURN.
      ELSE.
        SUBMIT ztr_push_transport
          WITH p_trkorr = request
          VIA JOB job_name NUMBER job_number
          AND RETURN.
      ENDIF.

      CALL FUNCTION 'JOB_CLOSE'
        EXPORTING
          jobcount             = job_number
          jobname              = job_name
          strtimmed            = abap_true
        EXCEPTIONS
          cant_start_immediate = 1
          invalid_startdate    = 2
          jobname_missing      = 3
          job_close_failed     = 4
          job_nosteps          = 5
          job_notex            = 6
          lock_failed          = 7
          invalid_target       = 8
          OTHERS               = 9.
      IF sy-subrc <> 0.
        CLEAR job_number.   " not started, the report can be run by hand
      ENDIF.
    ENDIF.
  ENDIF.

* ---- the refusal, visible wherever the release runs -------------------
  IF is_refused = abap_true.
    IF sy-batch = abap_true.
      " Release in the background: this cancels the job RELEASE OF
      " <request>, and the reason stays in its job log (SM37).
      MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4.
    ENDIF.

    IF dialog = abap_true AND adt = abap_false.
      " On the screen: a popup with the whole reason first, because the
      " error line at the bottom is easy to miss. Input fields, so that
      " the link can be selected and copied with Ctrl+C.
      " POPUP_GET_VALUES wants a different DDIC field per line; the
      " fields only lend their type, plain characters. '02' = display
      " only; the link can still be selected and copied with Ctrl+C.
      fields = VALUE #( field_attr = '02'
        ( tabname = 'SVAL'   fieldname = 'VALUE' fieldtext = 'Reason' value = |{ part_1 }{ part_2 }| )
        ( tabname = 'TVARVC' fieldname = 'LOW'   fieldtext = ''       value = |{ part_3 }{ part_4 }| ) ).
      IF link IS NOT INITIAL.
        APPEND VALUE #( tabname = 'TVARVC' fieldname = 'HIGH' fieldtext = 'GitHub' field_attr = '02' value = link ) TO fields.
      ENDIF.
      CALL FUNCTION 'POPUP_GET_VALUES'
        EXPORTING
          popup_title     = 'Release refused. Select the text, Ctrl+C copies it'
          no_value_check  = abap_true
        IMPORTING
          returncode      = returncode
        TABLES
          fields          = fields
        EXCEPTIONS
          OTHERS          = 1.
    ENDIF.
    MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4 RAISING cancel.
  ENDIF.

  CATCH cx_root INTO DATA(unexpected).
    " An error of the check itself never stops a release. See the header.
    IF dialog = abap_true.
      MESSAGE |The review of { request } was NOT checked: { unexpected->get_text( ) }| TYPE 'I'.
    ENDIF.
  ENDTRY.
ENDMETHOD.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_RELEASE_SLIN.
  endmethod.
ENDCLASS.
