*&---------------------------------------------------------------------*
*& Report ZTR_APPLY_CONTENT
*&---------------------------------------------------------------------*
*& Brings the content/ folder of a repository into this system: table
*& rows, report variants and SAP Note entries that abapGit does not pull
*& (class ZCL_TR_CONTENT_APPLY). Used after an abapGit pull, so that
*& a change coming through Git is complete: objects through abapGit, rows
*& and variants through this report, both in the same request.
*&
*& Without "Write" nothing is changed: it lists, per file, how many rows
*& or variants are new, different, the same and only on this system.
*&
*& With "Write" the keys of every table and variant that is written are
*& recorded in the request P_TRKORR first (a request or task that is not
*& released) or, with P_TRKORR empty, in a new request with the text
*& P_TEXT. Rows only this system has are removed only with "Delete".
*& Credential fields are never taken from Git, see the class.
*&
*& The files are read from the branch P_BASE of the abapGit repository
*& linked to the package P_PACK, freshly fetched from GitHub.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_apply_content NO STANDARD PAGE HEADING LINE-SIZE 200.

SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_pack FOR FIELD p_pack.
PARAMETERS p_pack   TYPE devclass.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_base FOR FIELD p_base.
PARAMETERS p_base   TYPE c LENGTH 60 LOWER CASE DEFAULT 'master'.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_trkorr FOR FIELD p_trkorr.
PARAMETERS p_trkorr TYPE trkorr.                          " request or task, not released
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_text FOR FIELD p_text.
PARAMETERS p_text   TYPE c LENGTH 60 LOWER CASE.          " text of a new request, Jira key first
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_write  AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 3(70) t_write FOR FIELD p_write.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_del    AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN COMMENT 3(70) t_del FOR FIELD p_del.
SELECTION-SCREEN END OF LINE.

INITIALIZATION.
  t_pack   = 'Package of the abapGit repository'.
  t_base   = 'Branch to read content/ from'.
  t_trkorr = 'Request or task (not released)'.
  t_text   = 'Text of a new request (Jira key first)'.
  t_write  = 'Write: change this system and record it in the request'.
  t_del    = 'Delete: remove rows that only this system has'.

CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS run.

  PRIVATE SECTION.
    CLASS-METHODS repository_of
      IMPORTING
        package       TYPE devclass
      RETURNING
        VALUE(result) TYPE REF TO zif_abapgit_repo_online
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS files_of
      IMPORTING
        repository    TYPE REF TO zif_abapgit_repo_online
        branch        TYPE string
      RETURNING
        VALUE(result) TYPE zif_abapgit_git_definitions=>ty_files_tt
      RAISING
        zcx_abapgit_exception.
    CLASS-METHODS show
      IMPORTING
        items TYPE zcl_tr_content_apply=>ty_items
        task  TYPE trkorr.
ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    TRY.
        IF p_write = abap_true AND p_trkorr IS INITIAL AND p_text IS INITIAL.
          zcx_abapgit_exception=>raise( |Writing needs a request (P_TRKORR) or the text of a new one (P_TEXT)| ).
        ENDIF.
        IF p_del = abap_true AND p_write = abap_false.
          zcx_abapgit_exception=>raise( |Delete only works together with Write| ).
        ENDIF.

        zcl_tr_auth=>git_authorization( ).
        DATA(repository) = repository_of( p_pack ).
        DATA(files) = files_of(
          repository = repository
          branch     = |{ zif_abapgit_git_definitions=>c_git_branch-heads_prefix }{ p_base }| ).

        DATA(task) = p_trkorr.
        IF p_write = abap_true AND task IS INITIAL.
          task = zcl_tr_content_apply=>create_request( p_text ).
        ENDIF.

        DATA(items) = NEW zcl_tr_content_apply( files )->run(
          task           = task
          write_changes  = p_write
          delete_missing = p_del ).
        show( items = items task = task ).
      CATCH zcx_abapgit_exception INTO DATA(error).
        WRITE: / 'FAILED:', error->get_text( ).
        MESSAGE error->get_text( ) TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD repository_of.
    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( iv_offline = abap_false ) INTO DATA(repository).
      IF repository->is_offline( ) = abap_true OR repository->get_package( ) <> package.
        CONTINUE.
      ENDIF.
      result = CAST zif_abapgit_repo_online( repository ).
      RETURN.
    ENDLOOP.
    zcx_abapgit_exception=>raise( |No online abapGit repository for package { package }| ).
  ENDMETHOD.


  METHOD files_of.
    " abapGit keeps one selected branch per repository, for everybody:
    " switch to the one asked for, fetch it again, and put it back, also
    " after an error.
    DATA error TYPE REF TO zcx_abapgit_exception.

    " The push report holds this lock while it works with the selected branch of the repository.
    CALL FUNCTION 'ENQUEUE_ES_PROG'
      EXPORTING
        name         = 'ZTR_PUSH_LOCK'
        _scope       = '1'
      EXCEPTIONS
        foreign_lock = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |A push to GitHub is running (lock ZTR_PUSH_LOCK): try again in a minute| ).
    ENDIF.

    DATA(previous) = repository->get_selected_branch( ).
    " CLEANUP gives the lock back when an exception leaves this block.
    TRY.
        IF previous <> branch.
          repository->select_branch( branch ).
        ENDIF.
        TRY.
            repository->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
            result = repository->zif_abapgit_repo~get_files_remote( ).
          CATCH zcx_abapgit_exception INTO error.
            " handled below, after the branch is switched back
        ENDTRY.
        IF previous <> branch.
          repository->select_branch( previous ).
        ENDIF.
      CLEANUP.
        CALL FUNCTION 'DEQUEUE_ES_PROG'
          EXPORTING
            name   = 'ZTR_PUSH_LOCK'
            _scope = '1'.
    ENDTRY.
    CALL FUNCTION 'DEQUEUE_ES_PROG'
      EXPORTING
        name   = 'ZTR_PUSH_LOCK'
        _scope = '1'.
    IF error IS BOUND.
      RAISE EXCEPTION error.
    ENDIF.
  ENDMETHOD.


  METHOD show.
    DATA total_failed TYPE i.

    IF p_write = abap_true.
      WRITE: / 'WRITE run, changes recorded in', task.
    ELSE.
      WRITE: / 'Test run: nothing was changed.'.
    ENDIF.
    SKIP.
    WRITE: / 'Kind  Name                                       new  different     same  only here  result'.
    ULINE.
    LOOP AT items INTO DATA(item).
      DATA(result_text) = COND string(
        WHEN item-failed  = abap_true THEN |FAILED: { item-message }|
        WHEN item-written = abap_true THEN |written|
        ELSE item-message ).
      IF item-failed = abap_true.
        total_failed = total_failed + 1.
        FORMAT COLOR COL_NEGATIVE.
      ELSEIF item-inserted + item-changed + item-missing > 0.
        FORMAT COLOR COL_TOTAL.
      ELSE.
        FORMAT COLOR OFF.
      ENDIF.
      WRITE: / item-kind, item-name(40), item-inserted, item-changed, item-unchanged, item-missing, result_text.
      FORMAT COLOR OFF.
    ENDLOOP.
    ULINE.
    IF items IS INITIAL.
      WRITE: / 'The branch has no files under content/.'.
    ENDIF.
    IF total_failed > 0.
      WRITE: / total_failed, 'file(s) failed, see the lines above.'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.

START-OF-SELECTION.
  lcl_report=>run( ).
