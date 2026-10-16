*&---------------------------------------------------------------------*
*& Report ZTR_PUSH_TRANSPORT
*&---------------------------------------------------------------------*
*& Pushes the objects of ONE released task or request to GitHub.
*&
*& Task released     -> commit on branch review/<request>. The branch is
*&                      created from the base branch if it is missing.
*&                      A pull request from that branch is the code
*&                      review. This report opens it, as the developer,
*&                      so GitHub keeps the rule that the author cannot
*&                      approve it. Every further task of the same
*&                      request adds a commit to the same branch.
*& Request released  -> the approved pull request of review/<request> is
*&                      squashed and merged into the base branch. GitHub
*&                      refuses that for a pull request that is not
*&                      approved. Whatever the base branch does not have
*&                      after that is committed to it directly. Nothing
*&                      is left to push after a merge.
*& P_REVIEW          -> the objects of a request that is NOT released go
*&                      to its review branch. For objects that were put
*&                      into the request directly, without a task.
*& P_CHECK           -> nothing is pushed. Gives the result of one question to the
*&                      BAdI that runs before the release of a request:
*&                      is the current state of every object of the
*&                      request reviewed? That is the case when it is on
*&                      the review branch and the pull request of that
*&                      branch is approved, or, without a review branch,
*&                      when it is on the base branch. The result goes to
*&                      ABAP memory, see the end of this program.
*&
*& Base branch = P_BASE, default master: development runs on one branch,
*& a finished support package is kept as a tag and as release branches.
*& With P_BASE empty the default branch of the GitHub repository is taken.
*&
*& The SAP system is the source, Git is the mirror: a file of the transport that
*& differs from the branch is overwritten with the state of this system.
*&
*& Started by BAdI implementation ZTR_RELEASE_CHECK (CTS_REQUEST_CHECK) as a
*& background job of the developer who releases: release of a task, and
*& release of a request with an approved pull request. The job waits for
*& the release. Or by hand in SE38 to repeat a failed push. Nothing in
*& here may rely on the logon client.
*&
*& Everything on GitHub runs under the GitHub account of the SAP user who
*& runs this: the push through the abapGit user exit, the pull requests
*& through api.github.com. The token comes from an encrypted cluster table,
*& class ZCL_TR_AUTH, put there once by report ZTR_GITHUB_LOGIN.
*& A user without a token gets a clear error and the job is cancelled.
*& Besides the files of abapGit (src/), everything else a transport
*& carries goes to content/ as JSON: table rows, variants, profiles, OTR
*& texts, SAP Note entries (class ZCL_TR_CONTENT). Transports of
*& copies are never pushed.
*& The file of an object in Git is the complete object as it is active on
*& this system, also when the transport holds only a part of it, a method
*& for example. When such an object is also in a task of ANOTHER request
*& that is not released, the log and the pull request say so, with the
*& request and its owner: that work is in the file too.
*& P_BASELN         -> no transport: compares every object of the packages
*&                      with GitHub and writes the content above for all of
*&                      them, to review/CONTENT-BASELINE, and lists what
*&                      nothing can write (completeness).
*& Needs: abapGit developer version with ZCL_ABAPGIT_USER_EXIT.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_push_transport NO STANDARD PAGE HEADING LINE-SIZE 200.

" Texts of the selection screen, set in code so that no text elements
" have to be maintained after the paste. The COMMENT statements declare
" the variables.

SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_trkorr FOR FIELD p_trkorr.
PARAMETERS p_trkorr TYPE trkorr.                         " task or request
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_test   AS CHECKBOX DEFAULT ' '.             " list what would be pushed, push nothing
SELECTION-SCREEN COMMENT 3(70) t_test FOR FIELD p_test.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_review AS CHECKBOX DEFAULT ' '.             " request not released yet: push it for review
SELECTION-SCREEN COMMENT 3(70) t_review FOR FIELD p_review.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_baseln AS CHECKBOX DEFAULT ' '.             " content of the packages, no transport
SELECTION-SCREEN COMMENT 3(70) t_baseln FOR FIELD p_baseln.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_check  AS CHECKBOX DEFAULT ' '.             " only check that the request is reviewed
SELECTION-SCREEN COMMENT 3(70) t_check FOR FIELD p_check.
SELECTION-SCREEN END OF LINE.
" The pull request is opened by the developer's own GitHub account, so
" GitHub still stops the developer from approving their own change.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_autopr AS CHECKBOX DEFAULT 'X'.             " open the pull request from here
SELECTION-SCREEN COMMENT 3(70) t_autopr FOR FIELD p_autopr.
SELECTION-SCREEN END OF LINE.
" Base branch = the branch the development of this system lives on.
" Empty = default branch on GitHub.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_base FOR FIELD p_base.
PARAMETERS p_base   TYPE c LENGTH 60 LOWER CASE DEFAULT 'master'.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_pack FOR FIELD p_pack.
PARAMETERS p_pack   TYPE devclass.     " only repositories of these packages, default from STVARV ZTR_PACKAGES
SELECTION-SCREEN END OF LINE.

INITIALIZATION.
  t_trkorr = 'Task or request'.
  t_test   = 'Test run: list what would be pushed, push nothing'.
  t_review = 'Push the objects of an unreleased request to its review branch'.
  t_check  = 'Only check whether the request is reviewed (used by the BAdI)'.
  t_baseln = 'Baseline: everything of the packages that is not on GitHub yet'.
  t_autopr = 'Open the pull request of the review branch'.
  t_base   = 'Base branch (empty = default branch)'.
  t_pack   = 'Packages of the repositories'.
  p_pack   = zcl_tr_auth=>packages( ).

CLASS lcl_transport_push DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS constructor
      IMPORTING
        transport       TYPE trkorr
        is_test_run     TYPE abap_bool
        is_review_run   TYPE abap_bool
        is_check_run    TYPE abap_bool
        opens_pull_request TYPE abap_bool
        base_branch     TYPE csequence
        package_pattern TYPE devclass
        is_baseline     TYPE abap_bool DEFAULT abap_false.
    METHODS run
      RAISING
        zcx_abapgit_exception.
    METHODS release_lock.

    " Result of a check run.
    " Files that are neither on the review branch nor on the base branch.
    DATA differences      TYPE i READ-ONLY.
    DATA first_difference TYPE string READ-ONLY.
    " Review branches whose pull request is approved and can be merged.
    DATA approved         TYPE i READ-ONLY.
    " Review branches whose pull request is missing or not approved.
    DATA pending          TYPE i READ-ONLY.
    DATA pending_detail   TYPE string READ-ONLY.
    " Where the developer has to go: the pull request, or the page that
    " opens one. For the refusal message.
    DATA github_link      TYPE string READ-ONLY.
    " Set when the run gave up because another push holds the lock.
    DATA is_busy          TYPE abap_bool READ-ONLY.
    " Entries of the transport that nothing can write to Git.
    DATA not_in_git       TYPE i READ-ONLY.
    " Objects of the transport that are also in a request that is not released:
    " the Git file of such an object holds that work too, and the transport
    " does not. How many, and the first one for the refusal message.
    DATA open_elsewhere       TYPE i READ-ONLY.
    DATA first_open_elsewhere TYPE string READ-ONLY.
    DATA first_not_in_git TYPE string READ-ONLY.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_main_object,
        object     TYPE tadir-object,
        obj_name   TYPE tadir-obj_name,
        is_deleted TYPE abap_bool,
      END OF ty_main_object.
    TYPES ty_main_objects TYPE SORTED TABLE OF ty_main_object WITH UNIQUE KEY object obj_name.
    TYPES:
      BEGIN OF ty_pull_request,
        path   TYPE string,   " /repos/<owner>/<repository>/pulls/<number>
        number TYPE i,
        head   TYPE string,   " the commit GitHub judged
        state  TYPE string,   " what GitHub says about merging it
        link   TYPE string,
        title  TYPE string,
        body   TYPE string,   " the list of tasks, kept by this report
        author TYPE string,   " GitHub login that opened it
      END OF ty_pull_request.

    CONSTANTS:
      BEGIN OF transport_status,
        released           TYPE trstatus VALUE 'R',
        released_protected TYPE trstatus VALUE 'N',
      END OF transport_status.
    CONSTANTS:
      BEGIN OF program_id,
        complete_object TYPE pgmid VALUE 'R3TR',
        part_of_object  TYPE pgmid VALUE 'LIMU',
      END OF program_id.
    CONSTANTS review_prefix            TYPE string VALUE 'refs/heads/review/'.
    " api.github.com, for pull requests, with the token of the user.
    CONSTANTS api_url                  TYPE string VALUE 'https://api.github.com'.
    CONSTANTS api_ssl_client           TYPE ssfapplssl VALUE 'ANONYM'.
    " Not the name of this program: the ABAP editor locks a program by its
    " name while it is open in change mode, and that would block every push.
    CONSTANTS lock_name                TYPE trdir-name VALUE 'ZTR_PUSH_LOCK'.
    CONSTANTS lock_kept_by_owner       TYPE c LENGTH 1 VALUE '1'.
    " Responses of GitHub to "can this pull request be merged". With the
    " rule on the base branch, clean means: approved, all comments
    " resolved, no conflict. Blocked means that one of these is missing.
    CONSTANTS:
      BEGIN OF merge_state,
        unknown  TYPE string VALUE 'unknown',
        clean    TYPE string VALUE 'clean',
        unstable TYPE string VALUE 'unstable',
        hooks    TYPE string VALUE 'has_hooks',
        blocked  TYPE string VALUE 'blocked',
        behind   TYPE string VALUE 'behind',
      END OF merge_state.
    CONSTANTS seconds_between_attempts TYPE i VALUE 10.
    CONSTANTS attempts_by_hand         TYPE i VALUE 6.
    CONSTANTS attempts_before_release  TYPE i VALUE 60.
    CONSTANTS attempts_for_lock        TYPE i VALUE 180.
    CONSTANTS attempts_for_lock_in_check TYPE i VALUE 6.
    CONSTANTS attempts_for_merge_state TYPE i VALUE 5.
    CONSTANTS english                  TYPE spras VALUE 'E'.
    " SE09/SE10 documentation of requests and tasks: document class TA.
    CONSTANTS transport_documentation  TYPE dokhl-id VALUE 'TA'.
    CONSTANTS documentation_heading    TYPE string VALUE `## Documentation from SAP`.
    CONSTANTS not_in_git_heading       TYPE string VALUE `## Not in Git`.
    CONSTANTS other_requests_heading   TYPE string VALUE `## Also in requests that are not released`.
    CONSTANTS missing_texts_heading    TYPE string VALUE `## Missing translations`.
    " Lines of the section "Missing translations" at most; the rest is
    " counted, the report lists all.
    CONSTANTS missing_texts_shown      TYPE i VALUE 25.
    CONSTANTS baseline_name            TYPE trkorr VALUE 'CONTENT-BASELINE'.
    CONSTANTS transport_of_copies      TYPE trfunction VALUE 'T'.

    DATA transport       TYPE trkorr.
    DATA request         TYPE trkorr.
    DATA owner           TYPE e070-as4user.
    DATA is_task         TYPE abap_bool.
    DATA is_test_run     TYPE abap_bool.
    DATA is_review_run   TYPE abap_bool.
    DATA is_check_run    TYPE abap_bool.
    DATA is_review       TYPE abap_bool.
    DATA opens_pull_request TYPE abap_bool.
    DATA base_override   TYPE string.
    DATA package_pattern TYPE devclass.
    DATA is_baseline     TYPE abap_bool.
    " Objects of this push that are also in another request that is not
    " released, one line each, for the pull request.
    DATA other_requests_text TYPE string.
    " Set by is_only_restricted: the pull request is behind the base branch.
    DATA is_behind           TYPE abap_bool.

    METHODS read_header
      RAISING
        zcx_abapgit_exception.
    METHODS wait_until_released
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS is_released
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS wait_for_lock
      RAISING
        zcx_abapgit_exception.
    METHODS main_objects
      RETURNING
        VALUE(result) TYPE ty_main_objects.
    METHODS add_package_content
      IMPORTING
        package TYPE devclass
      CHANGING
        objects TYPE ty_main_objects.
    METHODS commit_comment
      RETURNING
        VALUE(result) TYPE zif_abapgit_git_definitions=>ty_comment.
    METHODS request_text
      RETURNING
        VALUE(result) TYPE string.
    METHODS git_user
      RETURNING
        VALUE(result) TYPE zif_abapgit_git_definitions=>ty_git_user.
    METHODS is_deleted
      IMPORTING
        object        TYPE tadir-object
        obj_name      TYPE tadir-obj_name
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS concerns
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
        objects       TYPE ty_main_objects
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        zcx_abapgit_exception.
    METHODS push_to_repository
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        objects    TYPE ty_main_objects
        comment    TYPE zif_abapgit_git_definitions=>ty_comment
      RAISING
        zcx_abapgit_exception.
    METHODS base_branch
      IMPORTING
        branches      TYPE REF TO zif_abapgit_git_branch_list
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS branch_exists
      IMPORTING
        branches      TYPE REF TO zif_abapgit_git_branch_list
        name          TYPE string
      RETURNING
        VALUE(result) TYPE abap_bool
      RAISING
        zcx_abapgit_exception.
    METHODS select_target
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        branches   TYPE REF TO zif_abapgit_git_branch_list
        base       TYPE string
        target     TYPE string
      RAISING
        zcx_abapgit_exception.
    TYPES:
      BEGIN OF ty_in_work,
        object      TYPE tadir-object,
        obj_name    TYPE tadir-obj_name,
        trkorr      TYPE trkorr,
        request     TYPE trkorr,
        owner       TYPE e070-as4user,
        is_copy     TYPE abap_bool,
      END OF ty_in_work.
    TYPES ty_in_work_list TYPE STANDARD TABLE OF ty_in_work WITH DEFAULT KEY.
    METHODS open_request_objects
      RETURNING
        VALUE(result) TYPE ty_in_work_list.
    METHODS warn_about_other_requests
      IMPORTING
        objects TYPE ty_main_objects.
    METHODS repository_packages
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
      RETURNING
        VALUE(result) TYPE zcl_tr_content=>ty_packages.
    METHODS content_of
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
        remote_files  TYPE zif_abapgit_git_definitions=>ty_files_tt OPTIONAL
      RETURNING
        VALUE(result) TYPE REF TO zcl_tr_content.
    METHODS stage_content
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        stage      TYPE REF TO zcl_abapgit_stage
      RAISING
        zcx_abapgit_exception.
    METHODS not_in_git_text
      RETURNING
        VALUE(result) TYPE string.
    "! The texts of the objects of the request that have no translation in
    "! a required language, as a Markdown table; empty when nothing is
    "! missing, when the translation check is not set up, when the request
    "! carries #NOTRANSL, or when the check fails (it never stops a push).
    "! In the pull request, so that a release from ADT, which shows no
    "! message of the check, still makes the missing texts visible.
    METHODS missing_texts_text
      RETURNING
        VALUE(result) TYPE string.
    METHODS stage_objects
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
        objects       TYPE ty_main_objects
      RETURNING
        VALUE(result) TYPE REF TO zcl_abapgit_stage
      RAISING
        zcx_abapgit_exception.
    METHODS ensure_pull_request
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        review     TYPE string
        base       TYPE string
        title      TYPE string.
    METHODS task_line
      RETURNING
        VALUE(result) TYPE string.
    METHODS pull_request_body
      IMPORTING
        old_body      TYPE string
        line          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS documentation
      RETURNING
        VALUE(result) TYPE string.
    METHODS documentation_of
      IMPORTING
        transport_number TYPE trkorr
      RETURNING
        VALUE(result)    TYPE string.
    METHODS renotify_reviewers
      IMPORTING
        pull_request TYPE ty_pull_request
      RAISING
        zcx_abapgit_exception.
    METHODS json_string
      IMPORTING
        value         TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS compare_link
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
        review        TYPE string
        base          TYPE string
      RETURNING
        VALUE(result) TYPE string.
    METHODS github_path
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
      RETURNING
        VALUE(result) TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS remind_of_pull_request
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        review     TYPE string
        base       TYPE string.
    METHODS open_pull_request
      IMPORTING
        repository       TYPE REF TO zif_abapgit_repo_online
        review           TYPE string
        with_merge_state TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(result) TYPE ty_pull_request
      RAISING
        zcx_abapgit_exception.
    METHODS is_only_restricted
      IMPORTING
        pull_request  TYPE ty_pull_request
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS can_be_merged
      IMPORTING
        pull_request  TYPE ty_pull_request
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS check_pull_request
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        review     TYPE string
        base       TYPE string.
    METHODS merge_pull_request
      IMPORTING
        repository TYPE REF TO zif_abapgit_repo_online
        review     TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS github_client
      RETURNING
        VALUE(result) TYPE REF TO if_http_client
      RAISING
        zcx_abapgit_exception.
    METHODS call_github
      IMPORTING
        method   TYPE string
        path     TYPE string
        body     TYPE string OPTIONAL
      EXPORTING
        status   TYPE i
        response TYPE string
      RAISING
        zcx_abapgit_exception.
    METHODS log
      IMPORTING
        text TYPE csequence.

ENDCLASS.


CLASS lcl_transport_push IMPLEMENTATION.

  METHOD constructor.
    me->transport       = transport.
    me->is_test_run     = is_test_run.
    me->is_review_run   = is_review_run.
    me->is_check_run    = is_check_run.
    me->opens_pull_request = opens_pull_request.
    me->base_override   = base_branch.
    me->package_pattern = package_pattern.
    me->is_baseline     = is_baseline.
  ENDMETHOD.


  METHOD run.
    DATA failed  TYPE abap_bool.
    DATA checked TYPE i.

    IF is_baseline = abap_true.
      " No transport: the content of the packages goes for review.
      transport = baseline_name.
      request   = baseline_name.
      owner     = sy-uname.
      is_review = abap_true.
      zcl_tr_auth=>git_authorization( ).
      log( |GitHub account: { zcl_tr_auth=>login( ) } ({ sy-uname })| ).
      wait_for_lock( ).
      DATA(baseline_comment) = commit_comment( ).
      LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(baseline_repository).
        IF baseline_repository->get_package( ) NP package_pattern.
          CONTINUE.
        ENDIF.
        " Every object of the package tree: whatever differs from GitHub or
        " is missing there goes along, next to the content under content/.
        DATA(baseline_objects) = VALUE ty_main_objects( ).
        add_package_content(
          EXPORTING
            package = baseline_repository->get_package( )
          CHANGING
            objects = baseline_objects ).
        " Work in progress is not published by the baseline: an object in an
        " open task or request reaches GitHub with the release of that task,
        " through its own review.
        LOOP AT open_request_objects( ) INTO DATA(in_work).
          DELETE TABLE baseline_objects WITH TABLE KEY object = in_work-object obj_name = in_work-obj_name.
          IF sy-subrc = 0.
            log( |{ baseline_repository->get_name( ) }: skipped { in_work-object } { in_work-obj_name }, | &&
                 |in open { in_work-trkorr }| ).
          ENDIF.
        ENDLOOP.
        TRY.
            push_to_repository(
              repository = CAST zif_abapgit_repo_online( baseline_repository )
              objects    = baseline_objects
              comment    = baseline_comment ).
          CATCH zcx_abapgit_exception INTO DATA(baseline_error).
            failed = abap_true.
            log( |{ baseline_repository->get_name( ) }: FAILED, { baseline_error->get_text( ) }| ).
        ENDTRY.
      ENDLOOP.
      IF failed = abap_true.
        zcx_abapgit_exception=>raise( |The baseline was not pushed completely, see the log above| ).
      ENDIF.
      RETURN.
    ENDIF.

    IF transport IS INITIAL.
      zcx_abapgit_exception=>raise( |Enter a task or request, or choose the baseline| ).
    ENDIF.

    read_header( ).

    SELECT SINGLE trfunction FROM e070 INTO @DATA(request_type) WHERE trkorr = @request.
    IF request_type = transport_of_copies.
      log( |{ transport }: transport of copies, never pushed| ).
      RETURN.
    ENDIF.

    IF is_check_run = abap_true AND is_task = abap_true.
      zcx_abapgit_exception=>raise( |The check is for requests, { transport } is a task| ).
    ENDIF.

    " To the review branch go: every task, and a request on demand.
    is_review = xsdbool( is_task = abap_true OR is_review_run = abap_true ).

    " A task must be released before it is pushed, and so must a request
    " for its final push. A check and a push for review by hand are meant
    " for a request that is still open.
    IF is_check_run = abap_false AND
       ( is_task = abap_true OR is_review_run = abap_false ).
      IF wait_until_released( ) = abap_false.
        IF is_task = abap_true OR sy-batch = abap_true.
          " The BAdI runs before the release. The developer cancelled it,
          " or a later check stopped it. Nothing to push or merge then.
          log( |{ transport }: was not released, nothing pushed| ).
          RETURN.
        ENDIF.
        zcx_abapgit_exception=>raise( |Transport { transport } is not released| ).
      ENDIF.
    ENDIF.

    " Everything on GitHub runs as the user of this job. Without a token
    " nothing can work, so say so before anything is touched.
    zcl_tr_auth=>git_authorization( ).
    log( |GitHub account: { zcl_tr_auth=>login( ) } ({ sy-uname })| ).

    wait_for_lock( ).

    DATA(objects) = main_objects( ).
    " Also in the check before a release: the BAdI refuses a request whose
    " objects are in a request that is not released (status C).
    warn_about_other_requests( objects ).

    " Entries that neither abapGit nor ZCL_TR_CONTENT can write.
    DATA(content_entries) = COND zcl_tr_content=>ty_entries(
      WHEN is_task = abap_true THEN zcl_tr_content=>classify( transport )
      ELSE zcl_tr_content=>classify_request( request ) ).
    LOOP AT content_entries INTO DATA(content_entry) WHERE kind = zcl_tr_content=>kind-uncovered.
      not_in_git = not_in_git + 1.
      IF first_not_in_git IS INITIAL.
        first_not_in_git = zcl_tr_content=>describe( content_entry ).
      ENDIF.
      log( |not in Git: { zcl_tr_content=>describe( content_entry ) }| ).
    ENDLOOP.

    IF objects IS INITIAL AND content_entries IS INITIAL.
      log( |{ transport }: nothing that belongs in Git, nothing to push| ).
      RETURN.
    ENDIF.

    DATA(comment) = commit_comment( ).
    DATA(repositories) = zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ).

    " Other repositories on this system, abapGit itself for one, are none
    " of our business: checking them costs minutes and sends our token.
    " A failure in one repository must not stop the push to the others.
    LOOP AT repositories INTO DATA(repository).
      IF repository->is_offline( ) = abap_true OR
         repository->get_package( ) NP package_pattern.
        CONTINUE.
      ENDIF.
      checked = checked + 1.
      TRY.
          push_to_repository(
            repository = CAST zif_abapgit_repo_online( repository )
            objects    = objects
            comment    = comment ).
        CATCH zcx_abapgit_exception INTO DATA(error).
          failed = abap_true.
          log( |{ repository->get_name( ) }: FAILED, { error->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.

    IF checked = 0.
      zcx_abapgit_exception=>raise( |No online abapGit repository for packages { package_pattern }| ).
    ENDIF.
    IF failed = abap_true.
      zcx_abapgit_exception=>raise( |Transport { transport } was not pushed completely, see the log above| ).
    ENDIF.
  ENDMETHOD.


  METHOD read_header.
    SELECT SINGLE strkorr, as4user FROM e070
      INTO @DATA(header)
      WHERE trkorr = @transport.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Transport { transport } does not exist| ).
    ENDIF.

    owner   = header-as4user.
    is_task = xsdbool( header-strkorr IS NOT INITIAL ).
    request = COND #( WHEN is_task = abap_true THEN header-strkorr ELSE transport ).
  ENDMETHOD.


  METHOD wait_until_released.
    " The job is started by a BAdI that runs BEFORE the release. The
    " developer may still sit in the documentation dialog, and the checks
    " of the release take their time. So be patient in a job.
    DATA(attempts) = COND i( WHEN is_task = abap_true OR sy-batch = abap_true
                             THEN attempts_before_release
                             ELSE attempts_by_hand ).

    DO attempts TIMES.
      IF is_released( ) = abap_true.
        result = abap_true.
        RETURN.
      ENDIF.
      WAIT UP TO seconds_between_attempts SECONDS.
    ENDDO.
  ENDMETHOD.


  METHOD is_released.
    SELECT SINGLE trstatus FROM e070
      INTO @DATA(status)
      WHERE trkorr = @transport.
    result = xsdbool( sy-subrc = 0 AND
                      ( status = transport_status-released OR
                        status = transport_status-released_protected ) ).
  ENDMETHOD.


  METHOD wait_for_lock.
    " One push at a time. abapGit keeps ONE selected branch per repository
    " and this report switches it, so two runs must never overlap.
    " The lock is released when the program ends.
    DATA is_announced TYPE abap_bool.

    " A check runs in the dialog of a developer who waits for a release.
    DATA(attempts) = COND i( WHEN is_check_run = abap_true
                             THEN attempts_for_lock_in_check
                             ELSE attempts_for_lock ).

    DO attempts TIMES.
      CALL FUNCTION 'ENQUEUE_ES_PROG'
        EXPORTING
          name           = lock_name
          _scope         = lock_kept_by_owner
        EXCEPTIONS
          foreign_lock   = 1
          system_failure = 2
          OTHERS         = 3.
      IF sy-subrc = 0.
        RETURN.
      ENDIF.

      " Say once why nothing happens, so that a wait does not look like a hang.
      IF is_announced = abap_false.
        is_announced = abap_true.
        DATA(waiting) = |Waiting: another push is running, started by { sy-msgv1 }|.
        IF sy-batch = abap_true.
          log( waiting ).
        ELSE.
          CALL FUNCTION 'SAPGUI_PROGRESS_INDICATOR'
            EXPORTING
              text = waiting.
        ENDIF.
      ENDIF.

      WAIT UP TO seconds_between_attempts SECONDS.
    ENDDO.
    is_busy = abap_true.
    zcx_abapgit_exception=>raise( |Another push is still running, { transport } was not pushed| ).
  ENDMETHOD.


  METHOD release_lock.
    " The lock belongs to the user session, not to this program. In a job
    " it goes away with the job. Called from the BAdI in a dialog, it
    " would stay until the developer leaves the transaction and block the
    " next push. So give it back explicitly.
    CALL FUNCTION 'DEQUEUE_ES_PROG'
      EXPORTING
        name   = lock_name
        _scope = lock_kept_by_owner.
  ENDMETHOD.


  METHOD main_objects.
    " The complete objects behind the entries of the transport. Read from
    " the transport itself, not from the object directory: a deleted
    " object has no directory entry any more, but must leave Git too.
    DATA directory_entry TYPE tadir.

    SELECT * FROM e071
      INTO TABLE @DATA(entries)
      WHERE trkorr = @transport.

    LOOP AT entries INTO DATA(entry).
      " Table contents and namespace entries are no repository objects:
      " they have no object directory entry and no file in Git, and must
      " not be mistaken for deleted objects.
      IF entry-object = 'TABU' OR entry-object = 'TDAT' OR entry-object = 'VDAT' OR
         entry-object = 'CDAT' OR entry-object = 'NSPC'.
        CONTINUE.
      ENDIF.
      CASE entry-pgmid.
        WHEN program_id-complete_object.
          INSERT VALUE #( object     = entry-object
                          obj_name   = entry-obj_name
                          is_deleted = is_deleted( object   = entry-object
                                                   obj_name = CONV #( entry-obj_name ) ) ) INTO TABLE result.
          " A package in the transport, for example after a move in the
          " package hierarchy: its content changes repository or folder,
          " so every object of the package tree goes with it.
          IF entry-object = 'DEVC'.
            add_package_content(
              EXPORTING
                package = CONV #( entry-obj_name )
              CHANGING
                objects = result ).
          ENDIF.
        WHEN program_id-part_of_object.
          " A method, a function module, a report text: find its object.
          CLEAR directory_entry.
          CALL FUNCTION 'TR_CHECK_TYPE'
            EXPORTING
              wi_e071  = entry
            IMPORTING
              we_tadir = directory_entry.
          IF directory_entry-object IS NOT INITIAL.
            INSERT VALUE #( object     = directory_entry-object
                            obj_name   = directory_entry-obj_name
                            is_deleted = is_deleted( object   = directory_entry-object
                                                     obj_name = directory_entry-obj_name ) ) INTO TABLE result.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_package_content.
    " Every object of the package and of its sub-packages.
    DATA packages TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
    DATA next     TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.

    packages = VALUE #( ( package ) ).
    next     = packages.
    WHILE next IS NOT INITIAL.
      SELECT devclass FROM tdevc
        INTO TABLE @DATA(children)
        FOR ALL ENTRIES IN @next
        WHERE parentcl = @next-table_line.
      CLEAR next.
      LOOP AT children INTO DATA(child).
        IF NOT line_exists( packages[ table_line = child ] ).
          APPEND child TO packages.
          APPEND child TO next.
        ENDIF.
      ENDLOOP.
    ENDWHILE.

    SELECT object, obj_name FROM tadir
      INTO TABLE @DATA(content)
      FOR ALL ENTRIES IN @packages
      WHERE pgmid    = @program_id-complete_object
        AND devclass = @packages-table_line
        AND delflag  = @abap_false.
    LOOP AT content INTO DATA(item).
      INSERT VALUE #( object = item-object obj_name = item-obj_name ) INTO TABLE objects.
    ENDLOOP.
    log( |package { package }: { lines( content ) } object(s) of { lines( packages ) } package(s) included| ).
  ENDMETHOD.


  METHOD is_deleted.
    SELECT SINGLE delflag FROM tadir
      INTO @DATA(deletion_flag)
      WHERE pgmid    = @program_id-complete_object
        AND object   = @object
        AND obj_name = @obj_name.
    result = xsdbool( sy-subrc <> 0 OR deletion_flag = abap_true ).
  ENDMETHOD.


  METHOD concerns.
    " Does the transport touch this repository at all? Each repository
    " holds one package tree, and most transports touch only one of them.
    " Asking this first saves the comparison of a whole repository.
    "
    " A deleted object is in no package any more, so it could have been in
    " any repository. Then compare, to find the files that must go.
    LOOP AT objects TRANSPORTING NO FIELDS WHERE is_deleted = abap_true.
      result = abap_true.
      RETURN.
    ENDLOOP.

    " Content of the transport that belongs to this repository.
    IF is_baseline = abap_true OR content_of( repository )->has_entries( ) = abap_true.
      result = abap_true.
      RETURN.
    ENDIF.

    DATA(repository_objects) = repository->zif_abapgit_repo~get_tadir_objects( ).
    LOOP AT objects INTO DATA(object).
      READ TABLE repository_objects TRANSPORTING NO FIELDS
        WITH KEY object = object-object obj_name = object-obj_name.
      IF sy-subrc = 0.
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD request_text.
    " English description first, any other language as fallback.
    SELECT langu, as4text FROM e07t
      INTO TABLE @DATA(descriptions)
      WHERE trkorr = @request.
    READ TABLE descriptions INTO DATA(description) WITH KEY langu = english.
    IF sy-subrc <> 0.
      READ TABLE descriptions INTO description INDEX 1.
    ENDIF.
    result = description-as4text.
  ENDMETHOD.


  METHOD commit_comment.
    " Always the text of the request, so that every commit of a review
    " branch and the pull request carry the same title.
    " The author is left empty: abapGit then uses the committer as author.
    result-committer = git_user( ).
    IF is_baseline = abap_true.
      result-comment = |{ baseline_name } Everything of the packages that is not on GitHub yet| &&
                       |\n\nObjects that differ from GitHub or are missing there, and the content abapGit | &&
                       |does not write (table rows, variants, ALV layouts, profiles, OTR texts) as JSON under content/|.
      RETURN.
    ENDIF.
    result-comment   = |{ request } { request_text( ) }|.
    IF is_task = abap_true.
      result-comment = |{ result-comment }\n\nTask { transport }|.
    ELSEIF is_review_run = abap_true.
      result-comment = |{ result-comment }\n\nObjects of the request, pushed for review by hand|.
    ENDIF.
  ENDMETHOD.


  METHOD git_user.
    " The developers exist in the client the request was created in, not
    " necessarily in the client this job runs in. Read across clients.
    SELECT SINGLE client FROM e070c
      INTO @DATA(client)
      WHERE trkorr = @request.

    SELECT SINGLE persnumber, addrnumber FROM usr21 CLIENT SPECIFIED
      INTO @DATA(address_keys)
      WHERE mandt = @client
        AND bname = @owner.
    IF sy-subrc = 0.
      SELECT SINGLE name_text FROM adrp CLIENT SPECIFIED
        INTO @result-name
        WHERE client     = @client
          AND persnumber = @address_keys-persnumber.
      SELECT SINGLE smtp_addr FROM adr6 CLIENT SPECIFIED
        INTO @result-email
        WHERE client     = @client
          AND addrnumber = @address_keys-addrnumber
          AND persnumber = @address_keys-persnumber.
    ENDIF.

    IF result-name IS INITIAL.
      result-name = owner.
    ENDIF.
    IF result-email IS INITIAL.
      result-email = |{ to_lower( owner ) }@localhost|.
    ENDIF.
  ENDMETHOD.


  METHOD push_to_repository.
    DATA error TYPE REF TO zcx_abapgit_exception.

    DATA(name)     = repository->zif_abapgit_repo~get_name( ).

    IF concerns( repository = repository objects = objects ) = abap_false.
      log( |{ name }: { transport } has no objects in this repository| ).
      RETURN.
    ENDIF.

    DATA(branches) = zcl_abapgit_git_factory=>get_git_transport( )->branches( repository->get_url( ) ).
    DATA(base)     = base_branch( branches ).
    DATA(review)   = |{ review_prefix }{ request }|.
    DATA(target)   = COND string( WHEN is_review = abap_true THEN review ELSE base ).
    DATA(has_review_branch) = branch_exists( branches = branches name = review ).

    " Before the release the reviewed state is looked for on the review
    " branch, if there is one. It reaches the base branch after the release.
    IF is_check_run = abap_true AND has_review_branch = abap_true.
      target = review.
    ENDIF.

    TRY.
        " The request is released: bring its approved pull request in.
        IF is_review = abap_false AND is_check_run = abap_false AND has_review_branch = abap_true.
          IF is_test_run = abap_true.
            log( |{ name }: test run, the pull request of { review } is NOT merged| ).
          ELSE.
            merge_pull_request(
              repository = repository
              review     = review ).
          ENDIF.
        ENDIF.

        select_target(
          repository = repository
          branches   = branches
          base       = base
          target     = target ).

        DATA(stage) = stage_objects(
          repository = repository
          objects    = objects ).
        stage_content(
          repository = repository
          stage      = stage ).

        IF stage->count( ) = 0.
          log( |{ name }: nothing to push, { target } already has the current state of the objects of { transport }| ).
          " On the review branch is not reviewed yet: ask for the approval.
          IF is_check_run = abap_true AND target = review.
            check_pull_request(
              repository = repository
              review     = review
              base       = base ).
          ENDIF.
        ELSE.
          LOOP AT stage->get_all( ) INTO DATA(staged).
            log( |{ name }: { staged-method } { staged-file-path }{ staged-file-filename }| ).
          ENDLOOP.

          IF is_check_run = abap_true.
            differences = differences + stage->count( ).
            IF first_difference IS INITIAL.
              first_difference = staged-file-filename.
              github_link      = compare_link( repository = repository review = review base = base ).
            ENDIF.
            log( |{ name }: { stage->count( ) } file(s) of { transport } are NOT on { target } yet| ).
          ELSEIF is_test_run = abap_true.
            log( |{ name }: test run, { stage->count( ) } file(s) NOT pushed to { target }| ).
          ELSE.
            IF is_review = abap_false.
              " The rule on the base branch refuses this, and the job is
              " cancelled. That is the alarm for a release without review.
              log( |{ name }: { base } does not have everything of { transport }, pushing to it directly| ).
            ELSEIF branch_exists( branches = branches name = review ) = abap_false.
              " Now there is something to push: create the review branch
              " from the base branch, which is what was compared with.
              repository->create_branch(
                iv_name = review
                iv_from = branches->find_by_name( base )-sha1 ).
            ENDIF.
            repository->push(
              is_comment = comment
              io_stage   = stage ).
            log( |{ name }: pushed { stage->count( ) } file(s) to { target }| ).
          ENDIF.
        ENDIF.

        " A review branch without a pull request is reviewed by nobody.
        " Without a review branch there is nothing to ask about.
        IF is_review = abap_true AND is_test_run = abap_false AND is_check_run = abap_false AND
           ( stage->count( ) > 0 OR branch_exists( branches = branches name = review ) = abap_true ).
          IF opens_pull_request = abap_true.
            ensure_pull_request(
              repository = repository
              review     = review
              base       = base
              title      = segment( val = comment-comment index = 1 sep = cl_abap_char_utilities=>newline ) ).
          ENDIF.
          " Still none open, because it was not asked for or it failed:
          " tell the developer.
          remind_of_pull_request(
            repository = repository
            review     = review
            base       = base ).
        ENDIF.
      CATCH zcx_abapgit_exception INTO error.
        " handled below, after the branch is switched back
    ENDTRY.

    " abapGit keeps one selected branch per repository, for everybody.
    " Leave it on the base branch, also after an error.
    IF repository->get_selected_branch( ) <> base.
      repository->select_branch( base ).
    ENDIF.

    IF error IS BOUND.
      RAISE EXCEPTION error.
    ENDIF.
  ENDMETHOD.


  METHOD base_branch.
    IF base_override IS INITIAL.
      result = branches->get_head_symref( ).
    ELSEIF base_override CP zif_abapgit_git_definitions=>c_git_branch-heads.
      result = base_override.
    ELSE.
      result = |{ zif_abapgit_git_definitions=>c_git_branch-heads_prefix }{ base_override }|.
    ENDIF.

    " Raises if the branch does not exist.
    branches->find_by_name( result ).
  ENDMETHOD.


  METHOD branch_exists.
    DATA(existing) = branches->get_branches_only( ).
    READ TABLE existing TRANSPORTING NO FIELDS
      WITH TABLE KEY name_key COMPONENTS name = name.
    result = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.


  METHOD select_target.
    " A review branch that does not exist yet would start from the base
    " branch, so the comparison is made with the base branch. The branch
    " is created only when there is something to push, see
    " push_to_repository: a transport that touches nothing in this
    " repository must not leave an empty branch behind.
    IF branch_exists( branches = branches name = target ) = abap_true.
      repository->select_branch( target ).
    ELSE.
      repository->select_branch( base ).
    ENDIF.
  ENDMETHOD.


  METHOD open_request_objects.
    " Objects in tasks and requests that are not released yet, as complete
    " objects: a method in an open task stands for its class.
    DATA directory_entry TYPE tadir.

    SELECT e071~trkorr, e070~strkorr, e070~as4user, e070~trfunction,
           e071~pgmid, e071~object, e071~obj_name FROM e071
      INNER JOIN e070 ON e070~trkorr = e071~trkorr
      INTO TABLE @DATA(entries)
      WHERE e070~trstatus IN ('D','L').

    LOOP AT entries INTO DATA(entry).
      DATA(entry_request) = COND trkorr( WHEN entry-strkorr IS INITIAL THEN entry-trkorr ELSE entry-strkorr ).
      DATA(is_copy) = xsdbool( entry-trfunction = transport_of_copies ).
      IF entry-pgmid = program_id-complete_object.
        APPEND VALUE #( object = entry-object obj_name = entry-obj_name trkorr = entry-trkorr
                        request = entry_request owner = entry-as4user is_copy = is_copy ) TO result.
      ELSE.
        CLEAR directory_entry.
        CALL FUNCTION 'TR_CHECK_TYPE'
          EXPORTING
            wi_e071  = VALUE e071( pgmid = entry-pgmid object = entry-object obj_name = entry-obj_name )
          IMPORTING
            we_tadir = directory_entry.
        IF directory_entry-object IS NOT INITIAL.
          APPEND VALUE #( object = directory_entry-object obj_name = directory_entry-obj_name
                          trkorr = entry-trkorr request = entry_request owner = entry-as4user
                          is_copy = is_copy ) TO result.
        ENDIF.
      ENDIF.
    ENDLOOP.
    " One row per object and request: the baseline needs the object only,
    " the warning also the request and its owner.
    SORT result BY object obj_name request trkorr.
    DELETE ADJACENT DUPLICATES FROM result COMPARING object obj_name request.
  ENDMETHOD.


  METHOD warn_about_other_requests.
    " The file of an object in Git is the complete object as it is active on
    " this system. A class changed by this request holds every method of it,
    " also the ones of a task that is not released. Say so in the log, and
    " in the pull request through other_requests_text.
    CLEAR: other_requests_text, open_elsewhere, first_open_elsewhere.

    LOOP AT open_request_objects( ) INTO DATA(in_work)
         WHERE request <> me->request AND is_copy = abap_false.
      IF NOT line_exists( objects[ object = in_work-object obj_name = in_work-obj_name ] ).
        CONTINUE.
      ENDIF.
      DATA(line) = |{ in_work-object } { in_work-obj_name }: request { in_work-request }, { in_work-owner }|.
      open_elsewhere = open_elsewhere + 1.
      IF first_open_elsewhere IS INITIAL.
        first_open_elsewhere = |{ in_work-obj_name } is also in { in_work-request } ({ in_work-owner })|.
      ENDIF.
      log( |Also in a request that is not released: { line }| ).
      other_requests_text = COND #( WHEN other_requests_text IS INITIAL THEN `` ELSE |{ other_requests_text }\n| ) &&
                            |- { line }|.
    ENDLOOP.

    IF other_requests_text IS NOT INITIAL.
      log( |The file in Git is the whole object as it is active here, with that work in it| ).
    ENDIF.
  ENDMETHOD.


  METHOD repository_packages.
    " The package of the repository and all its sub-packages.
    DATA next TYPE zcl_tr_content=>ty_packages.

    result = VALUE #( ( repository->zif_abapgit_repo~get_package( ) ) ).
    next   = result.
    WHILE next IS NOT INITIAL.
      SELECT devclass FROM tdevc
        INTO TABLE @DATA(children)
        FOR ALL ENTRIES IN @next
        WHERE parentcl = @next-table_line.
      CLEAR next.
      LOOP AT children INTO DATA(child).
        IF NOT line_exists( result[ table_line = child ] ).
          APPEND child TO result.
          APPEND child TO next.
        ENDIF.
      ENDLOOP.
    ENDWHILE.
  ENDMETHOD.


  METHOD content_of.
    " What a baseline or this transport puts under content/ in this
    " repository. For a request also the entries of its tasks.
    result = NEW zcl_tr_content(
      remote_files = remote_files
      packages     = repository_packages( repository ) ).
    IF is_baseline = abap_true.
      result->add_packages( ).
      RETURN.
    ENDIF.
    result->add_transport( transport ).
    IF is_task = abap_false.
      SELECT trkorr FROM e070
        INTO TABLE @DATA(tasks)
        WHERE strkorr = @request.
      LOOP AT tasks INTO DATA(task).
        result->add_transport( task-trkorr ).
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD stage_content.
    " The JSON files under content/ next to abapGit's files: new or
    " changed ones are added, ones that lost all their rows are removed.
    DATA(remote_files) = repository->zif_abapgit_repo~get_files_remote( ).
    DATA(content) = content_of( repository = repository remote_files = remote_files ).

    LOOP AT content->changed( ) INTO DATA(file).
      stage->add(
        iv_path     = file-path
        iv_filename = file-filename
        iv_data     = file-data ).
    ENDLOOP.
    LOOP AT content->removed( ) INTO file.
      IF line_exists( remote_files[ KEY file_path COMPONENTS path = file-path filename = file-filename ] ).
        stage->rm(
          iv_path     = file-path
          iv_filename = file-filename ).
      ENDIF.
    ENDLOOP.

    DATA(name) = repository->zif_abapgit_repo~get_name( ).
    LOOP AT content->uncovered( ) INTO DATA(entry).
      log( |{ name }: not in Git: { zcl_tr_content=>describe( entry ) }| ).
    ENDLOOP.
  ENDMETHOD.


  METHOD not_in_git_text.
    " Entries of the request and its tasks that nothing writes to Git:
    " the reviewer checks them on the system.
    IF is_baseline = abap_true.
      RETURN.
    ENDIF.
    LOOP AT zcl_tr_content=>classify_request( request ) INTO DATA(entry)
         WHERE kind = zcl_tr_content=>kind-uncovered.
      result = COND #( WHEN result IS INITIAL THEN `` ELSE |{ result }\n| ) &&
               |- { zcl_tr_content=>describe( entry ) }|.
    ENDLOOP.
  ENDMETHOD.


  METHOD stage_objects.
    " abapGit returns the local files that differ from the selected branch
    " or are missing there, and the files that exist only on the branch.
    " Of both, take what belongs to the objects of the transport.
    " Deliberately not by abapGit's "changed locally" state: that state
    " is kept per repository, not per branch, and is wrong after a push
    " to a review branch.
    result = NEW #( ).

    DATA(files) = zcl_abapgit_stage_logic=>get_stage_logic( )->get( repository ).

    LOOP AT files-local INTO DATA(local).
      READ TABLE objects TRANSPORTING NO FIELDS
        WITH TABLE KEY object = local-item-obj_type obj_name = local-item-obj_name.
      IF sy-subrc = 0.
        result->add(
          iv_path     = local-file-path
          iv_filename = local-file-filename
          iv_data     = local-file-data ).
      ENDIF.
    ENDLOOP.

    " A file abapGit lists on the remote side is either changed on the
    " branch (the object still has this file on the system) or left over
    " (the object or this file of it is gone). This system is the source:
    " a changed file gets the version of the system, only a left-over
    " file is removed. Never remove the file of an object that exists.
    DATA(all_local) = repository->zif_abapgit_repo~get_files_local( ).
    LOOP AT files-remote INTO DATA(remote).
      READ TABLE files-status INTO DATA(status)
        WITH TABLE KEY path = remote-path filename = remote-filename.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE objects INTO DATA(object)
        WITH TABLE KEY object = status-obj_type obj_name = status-obj_name.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE all_local INTO DATA(local_version)
        WITH KEY file-path = remote-path file-filename = remote-filename.
      IF sy-subrc = 0.
        IF local_version-file-data <> remote-data.
          result->add(
            iv_path     = local_version-file-path
            iv_filename = local_version-file-filename
            iv_data     = local_version-file-data ).
        ENDIF.
      ELSEIF object-is_deleted = abap_true OR
             is_deleted( object = status-obj_type obj_name = status-obj_name ) = abap_true.
        result->rm(
          iv_path     = remote-path
          iv_filename = remote-filename ).
      ELSEIF line_exists( all_local[ item-obj_type = status-obj_type
                                     item-obj_name = status-obj_name
                                     file-filename = remote-filename ] ).
        " The object exists and abapGit writes the same file for it, but
        " in another folder: the object moved to another package. The
        " file of the old folder is removed, the new one is staged above.
        result->rm(
          iv_path     = remote-path
          iv_filename = remote-filename ).
        log( |{ repository->zif_abapgit_repo~get_name( ) }: removed { remote-path }{ remote-filename }, | &&
             |{ status-obj_type } { status-obj_name } moved to another package| ).
      ELSE.
        " The object exists, but abapGit wrote no such file for it: an
        " abapGit limit, not a deletion. Keep the file and say so.
        log( |{ repository->zif_abapgit_repo~get_name( ) }: kept { remote-path }{ remote-filename }, | &&
             |abapGit writes no file for { status-obj_type } { status-obj_name } on this system| ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD ensure_pull_request.
    " Opens the pull request of the review branch unless one is open, and
    " keeps the list of tasks in its description: every task that was
    " pushed for this request, with its owner. The description becomes
    " the message of the squash commit, so the numbers stay in the
    " history of the base branch.
    " Never fails the push: without it the developer opens it by hand.
    DATA status   TYPE i.
    DATA response TYPE string.

    DATA(name) = repository->zif_abapgit_repo~get_name( ).
    DATA(head) = substring_after( val = review sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).
    DATA(into) = substring_after( val = base   sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).
    DATA(line) = task_line( ).

    TRY.
        DATA(pull_request) = open_pull_request(
          repository       = repository
          review           = review
          with_merge_state = abap_false ).

        IF pull_request-number IS NOT INITIAL.
          " Already open: add this task to its description and refresh the
          " documentation from SAP.
          DATA(is_new_task) = xsdbool( pull_request-body NS line ).
          DATA(new_body) = pull_request_body( old_body = pull_request-body
                                              line     = line ).
          IF new_body = pull_request-body.
            log( |{ name }: pull request { pull_request-number } is open, { pull_request-link }| ).
            RETURN.
          ENDIF.
          call_github(
            EXPORTING
              method   = 'PATCH'
              path     = pull_request-path
              body     = |\{"body":{ json_string( new_body ) }\}|
            IMPORTING
              status   = status
              response = response ).
          IF status <> 200.
            log( |{ name }: pull request { pull_request-number } is open, description NOT updated, HTTP { status }| ).
          ELSEIF is_new_task = abap_true.
            log( |{ name }: pull request { pull_request-number } is open, { transport } added to it, { pull_request-link }| ).
          ELSE.
            log( |{ name }: pull request { pull_request-number } is open, documentation updated, { pull_request-link }| ).
          ENDIF.
          IF is_new_task = abap_true.
            " A new commit cancels the approvals. Ask the reviewers again, so
            " that GitHub notifies them and nobody has to click re-request.
            renotify_reviewers( pull_request ).
          ENDIF.
          RETURN.
        ENDIF.

        DATA(description) = pull_request_body(
          old_body = |Request { request }: { substring_after( val = title sub = |{ request } | ) }\n\n| &&
                     |Tasks pushed from { sy-sysid }:|
          line     = line ).
        call_github(
          EXPORTING
            method   = 'POST'
            path     = |{ github_path( repository ) }/pulls|
            body     = |\{"title":{ json_string( title ) },| &&
                       |"head":{ json_string( head ) },"base":{ json_string( into ) },| &&
                       |"body":{ json_string( description ) }\}|
          IMPORTING
            status   = status
            response = response ).
        IF status = 201.
          log( |{ name }: pull request opened, { zcl_abapgit_ajson=>parse( response )->get_string( '/html_url' ) }| ).
        ELSE.
          log( |{ name }: pull request NOT opened, HTTP { status }. Open it on GitHub. | &&
               substring( val = response len = nmin( val1 = 90 val2 = strlen( response ) ) ) ).
        ENDIF.

      CATCH zcx_abapgit_exception INTO DATA(error).
        log( |{ name }: pull request NOT opened, { error->get_text( ) }. Open it on GitHub| ).
      CATCH zcx_abapgit_ajson_error.
        log( |{ name }: pull request opened| ).
    ENDTRY.
  ENDMETHOD.


  METHOD renotify_reviewers.
    " Everybody who was asked to review, or did review, except the author:
    " the pending requests from the pull request, the done ones from its
    " reviews. Re-requesting them sends the notification.
    DATA status    TYPE i.
    DATA response  TYPE string.
    DATA reviewers TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    TRY.
        call_github(
          EXPORTING
            method   = 'GET'
            path     = pull_request-path
          IMPORTING
            status   = status
            response = response ).
        IF status = 200.
          DATA(pending) = zcl_abapgit_ajson=>parse( response ).
          LOOP AT pending->members( '/requested_reviewers' ) INTO DATA(index).
            APPEND pending->get_string( |/requested_reviewers/{ index }/login| ) TO reviewers.
          ENDLOOP.
        ENDIF.

        call_github(
          EXPORTING
            method   = 'GET'
            path     = |{ pull_request-path }/reviews?per_page=100|
          IMPORTING
            status   = status
            response = response ).
        IF status = 200.
          DATA(reviews) = zcl_abapgit_ajson=>parse( response ).
          LOOP AT reviews->members( '/' ) INTO index.
            APPEND reviews->get_string( |/{ index }/user/login| ) TO reviewers.
          ENDLOOP.
        ENDIF.
      CATCH zcx_abapgit_ajson_error INTO DATA(not_understood).
        zcx_abapgit_exception=>raise( |response of GitHub not understood, { not_understood->get_text( ) }| ).
    ENDTRY.

    DELETE reviewers WHERE table_line IS INITIAL OR table_line = pull_request-author.
    SORT reviewers.
    DELETE ADJACENT DUPLICATES FROM reviewers.
    IF reviewers IS INITIAL.
      log( |pull request { pull_request-number }: nobody to notify yet| ).
      RETURN.
    ENDIF.

    DATA(names) = REDUCE string( INIT r = `` FOR login IN reviewers
                                 NEXT r = COND #( WHEN r IS INITIAL THEN json_string( login )
                                                  ELSE |{ r },{ json_string( login ) }| ) ).
    call_github(
      EXPORTING
        method   = 'POST'
        path     = |{ pull_request-path }/requested_reviewers|
        body     = |\{"reviewers":[{ names }]\}|
      IMPORTING
        status   = status
        response = response ).
    IF status = 201.
      log( |pull request { pull_request-number }: review requested again from { concat_lines_of( table = reviewers sep = `, ` ) }| ).
    ELSE.
      log( |pull request { pull_request-number }: reviewers NOT notified, HTTP { status }| ).
    ENDIF.
  ENDMETHOD.


  METHOD task_line.
    " One line per push in the description of the pull request.
    IF is_task = abap_true.
      result = |- Task { transport }, { owner }|.
    ELSE.
      result = |- Objects of { request }, pushed by { sy-uname }|.
    ENDIF.
  ENDMETHOD.


  METHOD pull_request_body.
    " Description of the pull request: the title line and the list of
    " tasks are kept as they are (LINE is added once), the documentation
    " section at the end is read anew from SAP every time. The description
    " is the message of the squash commit, so the documentation of the
    " request and its tasks ends up in the history of the base branch.
    DATA cut TYPE i.

    result = old_body.
    " Everything from the first generated section on is written anew.
    FIND |\n{ documentation_heading }| IN result MATCH OFFSET cut.
    IF sy-subrc <> 0.
      FIND |\n{ not_in_git_heading }| IN result MATCH OFFSET cut.
    ENDIF.
    IF sy-subrc <> 0.
      FIND |\n{ other_requests_heading }| IN result MATCH OFFSET cut.
    ENDIF.
    IF sy-subrc <> 0.
      FIND |\n{ missing_texts_heading }| IN result MATCH OFFSET cut.
    ENDIF.
    IF sy-subrc = 0.
      result = substring( val = result len = cut ).
    ENDIF.
    result = shift_right( val = result sub = |\n| ).
    IF line IS NOT INITIAL AND result NS line.
      result = |{ result }\n{ line }|.
    ENDIF.

    DATA(text) = documentation( ).
    IF text IS NOT INITIAL.
      result = |{ result }\n\n{ documentation_heading }\n\n{ text }|.
    ENDIF.

    text = not_in_git_text( ).
    IF text IS NOT INITIAL.
      result = |{ result }\n\n{ not_in_git_heading }\n\n{ text }|.
    ENDIF.

    IF other_requests_text IS NOT INITIAL.
      result = |{ result }\n\n{ other_requests_heading }\n\n| &&
               |The file of an object in Git is the complete object as it is active on SAP. | &&
               |These objects are also in a request that is not released, and that work is in the file:\n\n| &&
               |{ other_requests_text }|.
    ENDIF.

    text = missing_texts_text( ).
    IF text IS NOT INITIAL.
      result = |{ result }\n\n{ missing_texts_heading }\n\n{ text }|.
    ENDIF.
  ENDMETHOD.


  METHOD missing_texts_text.
    DATA rows TYPE string_table.

    IF zcl_tr_transl_check=>configured_languages( ) IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE as4text FROM e07t INTO @DATA(request_text) WHERE trkorr = @request.
    IF request_text CS zcl_tr_transl_check=>skip_marker.
      RETURN.
    ENDIF.

    TRY.
        DATA(findings) = NEW zcl_tr_transl_check( )->check_transport( request ).
      CATCH cx_root INTO DATA(error).
        log( |translation check not run for the pull request: { error->get_text( ) }| ).
        RETURN.
    ENDTRY.
    DELETE findings WHERE status <> zcl_tr_transl_check=>status-missing.
    IF findings IS INITIAL.
      RETURN.
    ENDIF.

    LOOP AT findings INTO DATA(finding) TO missing_texts_shown.
      " A | in a text would end the cell of the Markdown table.
      DATA(source) = replace( val = condense( CONV string( finding-source_text ) ) sub = `|` with = `\|` occ = 0 ).
      APPEND |\| { finding-object } { condense( finding-obj_name ) } \| { finding-text_kind } \| | &&
             |{ zcl_tr_transl_check=>language_code( finding-language ) } \| { source } \||
             TO rows.
    ENDLOOP.
    DATA(count) = lines( findings ).
    result = |{ count } text(s) of the objects of { request } have no translation. | &&
             |Translate them in a task of this request: report { zcl_tr_transl_check=>report_name } | &&
             |with the request, "Enter translations", Save; then release the task.\n\n| &&
             |\| Object \| Kind of text \| Missing in \| Source text \|\n| &&
             |\|---\|---\|---\|---\|\n| &&
             concat_lines_of( table = rows sep = |\n| ).
    IF count > missing_texts_shown.
      result = |{ result }\n\nand { count - missing_texts_shown } more: report { zcl_tr_transl_check=>report_name } | &&
               |lists them all.|.
    ENDIF.
  ENDMETHOD.


  METHOD documentation.
    " The SE09 documentation of the request and of each of its tasks, as
    " Markdown. Empty when nobody wrote any.
    DATA text TYPE string.

    SELECT trkorr, as4user FROM e070
      INTO TABLE @DATA(tasks)
      WHERE strkorr = @request
      ORDER BY trkorr.

    DATA(request_text) = documentation_of( request ).
    IF request_text IS NOT INITIAL.
      result = |### Request { request }\n\n{ request_text }|.
    ENDIF.
    LOOP AT tasks INTO DATA(task).
      " When a task is released, SAP copies its documentation into the
      " documentation of the request, under a line with the task number.
      " Such a task is shown there already.
      IF request_text CS |Task { task-trkorr }|.
        CONTINUE.
      ENDIF.
      text = documentation_of( task-trkorr ).
      IF text IS NOT INITIAL.
        result = COND #( WHEN result IS INITIAL THEN ``
                         ELSE |{ result }\n\n| ) &&
                 |### Task { task-trkorr }, { task-as4user }\n\n{ text }|.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD documentation_of.
    " SAPscript text of one request or task in plain lines: English first,
    " then the logon language, then whatever language exists. Paragraph
    " formats start a new line, '=' and ' ' continue the line, commands
    " and comments are left out, character formats like <ZK>..</> removed.
    DATA lines       TYPE STANDARD TABLE OF tline WITH DEFAULT KEY.
    DATA language    TYPE sy-langu.
    DATA docu_object TYPE dokhl-object.
    DATA task_number TYPE string.
    DATA task_owner TYPE string.
    DATA released_date TYPE string.
    DATA released_time TYPE string.

    docu_object = transport_number.
    SELECT DISTINCT langu FROM dokhl
      INTO TABLE @DATA(languages)
      WHERE id     = @transport_documentation
        AND object = @docu_object.
    IF languages IS INITIAL.
      RETURN.
    ENDIF.
    IF line_exists( languages[ langu = english ] ).
      language = english.
    ELSEIF line_exists( languages[ langu = sy-langu ] ).
      language = sy-langu.
    ELSE.
      language = languages[ 1 ]-langu.
    ENDIF.

    CALL FUNCTION 'DOCU_GET'
      EXPORTING
        id     = transport_documentation
        langu  = language
        object = docu_object
        typ    = 'T'
      TABLES
        line   = lines
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT lines INTO DATA(text_line).
      IF text_line-tdformat = '/:' OR text_line-tdformat = '/*'.
        CONTINUE.
      ENDIF.
      DATA(content) = text_line-tdline.
      REPLACE ALL OCCURRENCES OF REGEX '<(/|[A-Z][A-Z0-9]?)>' IN content WITH ``.
      " The block SAP writes for a released task: a frame of asterisks
      " around its number, its owner and the time of the release. As
      " Markdown the frame would become rules and bold text.
      DATA(trimmed) = condense( content ).
      IF strlen( trimmed ) > 3 AND trimmed CO '*'.
        CONTINUE.
      ENDIF.
      FIND REGEX '^\*\* Task (\S+)\s+User (\S+)' IN trimmed SUBMATCHES task_number task_owner.
      IF sy-subrc = 0.
        content = |#### Task { task_number }, { task_owner }|.
      ENDIF.
      FIND REGEX '^\*\* released on (\d{8}) (\d{6})' IN trimmed SUBMATCHES released_date released_time.
      IF sy-subrc = 0.
        content = |Released on { released_date } { released_time }\n|.
      ENDIF.
      IF text_line-tdformat = '='.
        result = |{ result }{ content }|.
      ELSEIF text_line-tdformat = space.
        result = |{ result } { content }|.
      ELSE.
        result = |{ result }\n{ content }|.
      ENDIF.
    ENDLOOP.
    result = shift_right( val = shift_left( val = result sub = |\n| ) sub = |\n| ).
  ENDMETHOD.


  METHOD json_string.
    result = |"{ escape( val = value format = cl_abap_format=>e_json_string ) }"|.
  ENDMETHOD.


  METHOD remind_of_pull_request.
    " The push runs in a job, after the release dialog is gone. So tell
    " the developer where the pull request is, or that none is open, as
    " an express document: SAP GUI announces it at once with a popup, and
    " the document in the inbox (SBWP) holds the link as text, to copy or
    " to click. A system message (TH_POPUP) cannot carry a usable link.
    " Never fails the push.
    DATA subject TYPE so_obj_des.
    DATA text    TYPE soli_tab.

    DATA(name) = repository->zif_abapgit_repo~get_name( ).
    DATA(head) = substring_after( val = review sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).
    " The request and its description, whether the request is released or not.
    DATA(what) = COND string( WHEN is_task = abap_true
                              THEN |Task { transport } of request { request } "{ request_text( ) }"|
                              ELSE |The objects of request { request } "{ request_text( ) }"| ).

    TRY.
        DATA(pull_request) = open_pull_request(
          repository       = repository
          review           = review
          with_merge_state = abap_false ).
        IF pull_request-number IS NOT INITIAL.
          log( |{ name }: pull request { pull_request-number } is open, { pull_request-link }| ).
          subject = |{ transport }: pull request { pull_request-number } waits for approval|.
          text = VALUE #(
            ( line = |{ what }| )
            ( line = |are on GitHub, branch { head }, repository { name }.| )
            ( line = |Pull request { pull_request-number } waits for the approval of a colleague:| )
            ( line = pull_request-link ) ).
        ELSE.
          DATA(link) = compare_link( repository = repository review = review base = base ).
          log( |{ name }: NO pull request is open for { head }. Open it:| ).
          log( link ).
          subject = |{ transport }: open the pull request on GitHub|.
          text = VALUE #(
            ( line = |{ what }| )
            ( line = |are on GitHub, branch { head }, repository { name }.| )
            ( line = 'No pull request is open for it. Open one, so that it is reviewed:' )
            ( line = link ) ).
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(error).
        log( |{ name }: GitHub was not asked for the pull request, { error->get_text( ) }| ).
        RETURN.
    ENDTRY.

    " To the person who released: the job runs under that user.
    TRY.
        DATA(mail) = cl_bcs=>create_persistent( ).
        mail->set_document( cl_document_bcs=>create_document(
          i_type    = 'RAW'
          i_subject = subject
          i_text    = text ) ).
        mail->add_recipient(
          i_recipient = cl_sapuser_bcs=>create( sy-uname )
          i_express   = abap_true ).
        mail->set_send_immediately( abap_true ).
        mail->send( ).
        COMMIT WORK AND WAIT.   " abapGit frees its locks in the update task; wait, or the switch back to the base branch meets our own lock
        log( |{ name }: express document sent to { sy-uname }| ).
      CATCH cx_bcs INTO DATA(mail_error).
        log( |{ name }: no express document for { sy-uname }, { mail_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD compare_link.
    " The page on GitHub that opens a pull request for the review branch.
    DATA(head) = substring_after( val = review sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).
    DATA(into) = substring_after( val = base   sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).
    TRY.
        " /repos/<owner>/<repository> -> https://github.com/<owner>/<repository>
        result = |https://github.com{ substring_after( val = github_path( repository ) sub = '/repos' ) }| &&
                 |/compare/{ into }...{ head }?expand=1|.
      CATCH zcx_abapgit_exception.
        CLEAR result.
    ENDTRY.
  ENDMETHOD.


  METHOD github_path.
    " https://github.com/<owner>/<repository>.git -> /repos/<owner>/<repository>
    DATA owner_name TYPE string.
    DATA repo_name  TYPE string.

    FIND REGEX 'github\.com/([^/]+)/([^/]+)$' IN repository->get_url( ) SUBMATCHES owner_name repo_name.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |{ repository->get_url( ) } is not a GitHub repository| ).
    ENDIF.
    REPLACE REGEX '\.git$' IN repo_name WITH ''.

    result = |/repos/{ owner_name }/{ repo_name }|.
  ENDMETHOD.


  METHOD open_pull_request.
    " The open pull request of the review branch, and what GitHub says
    " about merging it. Empty when none is open.
    DATA status   TYPE i.
    DATA response TYPE string.

    DATA(github)     = github_path( repository ).
    DATA(owner_name) = segment( val = github index = 3 sep = '/' ).
    DATA(head)       = substring_after( val = review sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).

    call_github(
      EXPORTING
        method   = 'GET'
        path     = |{ github }/pulls?state=open&head={ owner_name }:{ head }|
      IMPORTING
        status   = status
        response = response ).
    IF status <> 200.
      zcx_abapgit_exception=>raise( |GitHub responds with HTTP { status } for the pull request| ).
    ENDIF.

    TRY.
        DATA(found) = zcl_abapgit_ajson=>parse( response ).
        IF found->exists( '/1' ) = abap_false.
          RETURN.
        ENDIF.
        result-number = found->get_integer( '/1/number' ).
        result-head   = found->get_string( '/1/head/sha' ).
        result-link   = found->get_string( '/1/html_url' ).
        result-title  = found->get_string( '/1/title' ).
        result-body   = found->get_string( '/1/body' ).
        result-author = found->get_string( '/1/user/login' ).
        result-path   = |{ github }/pulls/{ result-number }|.
        IF with_merge_state = abap_false.
          RETURN.
        ENDIF.

        " GitHub works out in the background whether a pull request can be
        " merged. Ask again while it does not know yet.
        DO attempts_for_merge_state TIMES.
          call_github(
            EXPORTING
              method   = 'GET'
              path     = result-path
            IMPORTING
              status   = status
              response = response ).
          IF status <> 200.
            zcx_abapgit_exception=>raise( |GitHub responds with HTTP { status } for pull request { result-number }| ).
          ENDIF.
          result-state = zcl_abapgit_ajson=>parse( response )->get_string( '/mergeable_state' ).
          IF result-state <> merge_state-unknown.
            EXIT.
          ENDIF.
          WAIT UP TO 2 SECONDS.
        ENDDO.

      CATCH zcx_abapgit_ajson_error INTO DATA(not_understood).
        zcx_abapgit_exception=>raise( |Response of GitHub not understood, { not_understood->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD can_be_merged.
    result = xsdbool( pull_request-state = merge_state-clean OR
                      pull_request-state = merge_state-unstable OR
                      pull_request-state = merge_state-hooks ).
    IF result = abap_false AND pull_request-state = merge_state-blocked.
      result = is_only_restricted( pull_request ).
    ENDIF.
  ENDMETHOD.


  METHOD is_only_restricted.
    " "Blocked" also comes from the ruleset that lets only the release in
    " SAP or an admin merge into the base branch: then GitHub reports
    " every pull request as blocked, approved or not. So ask what really
    " counts: approved, no open review comment, no conflict, no failing or
    " running check. Then the block is only the merge restriction, which
    " the merge by this report is allowed to pass.
    DATA status   TYPE i.
    DATA response TYPE string.

    DATA(github) = substring_after( val = pull_request-path sub = '/repos/' ).
    DATA(owner_name) = segment( val = github index = 1 sep = '/' ).
    DATA(repository_name) = segment( val = github index = 2 sep = '/' ).
    DATA(query) = |query\{repository(owner:"{ owner_name }",name:"{ repository_name }")| &&
                  |\{pullRequest(number:{ pull_request-number })| &&
                  |\{reviewDecision mergeable mergeStateStatus reviewThreads(first:100)\{nodes\{isResolved\}\}| &&
                  | commits(last:1)\{nodes\{commit\{oid statusCheckRollup\{state\}\}\}\}\}\}\}|.

    TRY.
        call_github(
          EXPORTING
            method   = 'POST'
            path     = '/graphql'
            body     = |\{"query":{ json_string( query ) }\}|
          IMPORTING
            status   = status
            response = response ).
        IF status <> 200.
          RETURN.
        ENDIF.

        DATA(data_node) = zcl_abapgit_ajson=>parse( response ).
        DATA(found) = data_node->slice( '/data/repository/pullRequest' ).
        " The ruleset wants the branch up to date with the base branch: GitHub
        " refuses the merge of a pull request that is behind, also the merge
        " of this report. Do not release a request on the strength of it.
        IF found->get_string( '/mergeStateStatus' ) = 'BEHIND'.
          is_behind = abap_true.
          RETURN.
        ENDIF.
        IF found->get_string( '/reviewDecision' ) <> 'APPROVED' OR
           found->get_string( '/mergeable' ) <> 'MERGEABLE' OR
           found->get_string( '/commits/nodes/1/commit/oid' ) <> pull_request-head.
          RETURN.
        ENDIF.
        LOOP AT found->members( '/reviewThreads/nodes' ) INTO DATA(thread).
          IF found->get_boolean( |/reviewThreads/nodes/{ thread }/isResolved| ) = abap_false.
            RETURN.
          ENDIF.
        ENDLOOP.
        DATA(checks) = found->get_string( '/commits/nodes/1/commit/statusCheckRollup/state' ).
        IF checks IS NOT INITIAL AND checks <> 'SUCCESS'.
          RETURN.
        ENDIF.
        result = abap_true.
      CATCH zcx_abapgit_exception zcx_abapgit_ajson_error.
        result = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD check_pull_request.
    " The review branch has the current state of the objects. That counts
    " as reviewed only with an approved pull request. If GitHub cannot be
    " asked, it does not count: better one release too few than one
    " without review.
    DATA(name) = repository->zif_abapgit_repo~get_name( ).
    DATA(head) = substring_after( val = review sub = zif_abapgit_git_definitions=>c_git_branch-heads_prefix ).

    CLEAR is_behind.
    TRY.
        DATA(pull_request) = open_pull_request(
          repository = repository
          review     = review ).

        IF pull_request-number IS INITIAL.
          pending        = pending + 1.
          pending_detail = |no pull request is open for { head }|.
          IF github_link IS INITIAL.
            github_link = compare_link( repository = repository review = review base = base ).
          ENDIF.
        ELSEIF can_be_merged( pull_request ) = abap_true.
          approved = approved + 1.
          log( |{ name }: pull request { pull_request-number } is approved, it is merged after the release| ).
          RETURN.
        ELSEIF is_behind = abap_true OR pull_request-state = merge_state-behind.
          pending        = pending + 1.
          pending_detail = |pull request { pull_request-number } is behind { base }: press Update branch on it|.
        ELSEIF pull_request-state = merge_state-blocked.
          pending        = pending + 1.
          pending_detail = |pull request { pull_request-number } is not approved yet|.
        ELSE.
          pending        = pending + 1.
          pending_detail = |pull request { pull_request-number } cannot be merged ({ pull_request-state })|.
        ENDIF.
        IF github_link IS INITIAL.
          github_link = pull_request-link.
        ENDIF.

      CATCH zcx_abapgit_exception INTO DATA(error).
        pending        = pending + 1.
        pending_detail = error->get_text( ).
    ENDTRY.

    log( |{ name }: { pending_detail } { pull_request-link }| ).
  ENDMETHOD.


  METHOD merge_pull_request.
    " Squash and merge, the only merge method the repositories allow.
    " GitHub checks its rule again: a pull request that is not approved
    " is not merged, whoever asks.
    DATA status   TYPE i.
    DATA response TYPE string.
    DATA reason   TYPE string.

    DATA(name) = repository->zif_abapgit_repo~get_name( ).

    DATA(pull_request) = open_pull_request(
      repository = repository
      review     = review ).
    IF pull_request-number IS INITIAL.
      log( |{ name }: no pull request is open for { review }, nothing to merge| ).
      RETURN.
    ENDIF.
    IF can_be_merged( pull_request ) = abap_false.
      zcx_abapgit_exception=>raise( |Pull request { pull_request-number } is NOT merged, GitHub says | &&
                                    |{ pull_request-state }. Merge it on GitHub| ).
    ENDIF.

    " With the commit that was judged: a commit that arrived in between
    " is not approved and must not slip in. Title and message of the
    " squash commit as GitHub would make them by hand: the title of the
    " pull request with its number, and its description with the tasks.
    " The documentation part is read from SAP once more, so that what was
    " written in SE09 up to the release of the request is in the commit.
    DATA(message) = pull_request_body( old_body = pull_request-body
                                       line     = `` ).
    call_github(
      EXPORTING
        method   = 'PUT'
        path     = |{ pull_request-path }/merge|
        body     = |\{"merge_method":"squash","sha":"{ pull_request-head }",| &&
                   |"commit_title":{ json_string( |{ pull_request-title } (#{ pull_request-number })| ) },| &&
                   |"commit_message":{ json_string( message ) }\}|
      IMPORTING
        status   = status
        response = response ).
    IF status <> 200.
      FIND REGEX '"message"\s*:\s*"([^"]*)"' IN response SUBMATCHES reason.
      zcx_abapgit_exception=>raise( |Pull request { pull_request-number } is NOT merged, HTTP { status } { reason }| ).
    ENDIF.

    log( |{ name }: pull request { pull_request-number } squashed and merged, { pull_request-link }| ).
  ENDMETHOD.


  METHOD github_client.
    " The token of the current user, never a shared one.
    DATA(authorization) = zcl_tr_auth=>api_authorization( ).

    cl_http_client=>create_by_url(
      EXPORTING
        url    = api_url
        ssl_id = api_ssl_client
      IMPORTING
        client = result
      EXCEPTIONS
        OTHERS = 1 ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |no HTTP client for { api_url }| ).
    ENDIF.
    result->request->set_header_field( name = 'Authorization' value = authorization ).
  ENDMETHOD.


  METHOD call_github.
    DATA message TYPE string.

    DATA(client) = github_client( ).

    " No logon popup: this runs in a background job.
    client->propertytype_logon_popup = if_http_client=>co_disabled.
    client->request->set_method( method ).
    cl_http_utility=>set_request_uri( request = client->request uri = path ).
    client->request->set_header_field( name = 'Accept'     value = 'application/vnd.github+json' ).
    client->request->set_header_field( name = 'User-Agent' value = 'abap-transport-automation' ).
    IF body IS NOT INITIAL.
      client->request->set_header_field( name = 'Content-Type' value = 'application/json' ).
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


  METHOD log.
    " The list goes to the spool, the message to the job log.
    DATA line TYPE c LENGTH 200.
    line = text.
    WRITE / line.
    IF sy-batch = abap_true.
      MESSAGE line TYPE 'S'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  DATA error_text   TYPE string.
  DATA check_status TYPE c LENGTH 1.
  DATA check_detail TYPE string.

  DATA(push) = NEW lcl_transport_push(
    transport       = p_trkorr
    is_test_run     = p_test
    is_review_run   = p_review
    is_check_run    = p_check
    opens_pull_request = p_autopr
    base_branch     = p_base
    package_pattern = p_pack
    is_baseline     = p_baseln ).

  TRY.
      push->run( ).
    CATCH zcx_abapgit_exception INTO DATA(error).
      error_text = error->get_text( ).
  ENDTRY.
  push->release_lock( ).

  IF p_check = abap_true.
    " The result for the caller, BAdI CTS_REQUEST_CHECK before the release
    " of a request.
    "   O = the base branch is complete
    "   A = the review branch is complete and its pull request is approved
    "   C = an object of the request is also in another request that is not
    "       released (checked before D, P and A)
    "   D = files differ, they are not reviewed
    "   P = the pull request is missing or not approved
    "   B = another push is running
    "   E = the check itself failed
    "   U = entries that nothing can write to Git, and STVARV
    "       ZTR_REQUIRE_COMPLETE = X makes that a refusal
    SELECT SINGLE low FROM tvarvc INTO @DATA(require_complete)
      WHERE name = 'ZTR_REQUIRE_COMPLETE' AND type = 'P'.
    IF push->is_busy = abap_true.
      check_status = 'B'.
      check_detail = error_text.
    ELSEIF error_text IS INITIAL AND push->not_in_git > 0 AND require_complete = abap_true.
      check_status = 'U'.
      check_detail = |{ push->not_in_git } entr{ COND #( WHEN push->not_in_git = 1 THEN `y` ELSE `ies` ) }, | &&
                     |first { push->first_not_in_git }|.
    ELSEIF error_text IS NOT INITIAL.
      check_status = 'E'.
      check_detail = error_text.
    ELSEIF push->open_elsewhere > 0 AND
           ( push->differences > 0 OR push->pending > 0 OR push->approved > 0 ).
      " Not when everything is on the base branch already: nothing is
      " pushed or merged then, so no foreign work travels with it.
      check_status = 'C'.
      check_detail = push->first_open_elsewhere.
      IF push->open_elsewhere > 1.
        check_detail = |{ check_detail } (+{ push->open_elsewhere - 1 })|.
      ENDIF.
    ELSEIF push->differences > 0.
      check_status = 'D'.
      check_detail = push->first_difference.
    ELSEIF push->pending > 0.
      check_status = 'P'.
      check_detail = push->pending_detail.
    ELSEIF push->approved > 0.
      check_status = 'A'.
    ELSE.
      check_status = 'O'.
    ENDIF.
    EXPORT status      = check_status
           differences = push->differences
           detail      = check_detail
           link        = push->github_link
           TO MEMORY ID 'ZTR_CHECK'.
  ENDIF.

  IF error_text IS NOT INITIAL.
    IF p_check = abap_true.
      " The caller decides. With release in the background this runs
      " inside the release job, and an error message would cancel it.
      WRITE / error_text.
    ELSEIF sy-batch = abap_true.
      " Type E ends a background job as cancelled, so a failed push is
      " visible in SM37 and can be repeated by running this report again.
      MESSAGE error_text TYPE 'E'.
    ELSE.
      WRITE / error_text.
      MESSAGE error_text TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDIF.
