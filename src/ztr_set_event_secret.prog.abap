*&---------------------------------------------------------------------*
*& Report ZTR_SET_EVENT_SECRET
*&---------------------------------------------------------------------*
*& Stores the secret that signs the event "sap-request-released", which
*& asks GitHub to merge the pull request of a released request. The same
*& secret is set once in GitHub, as SAP_EVENT_SECRET of the environment
*& sap-merge of each repository. It is kept encrypted on this system
*& (ZCL_TR_AUTH) and is never shown again, not even to this report.
*&
*& After storing, the report prints the signature of a fixed sample
*& event. Compare it with the same sample made with the secret on the
*& other side (docs/GITHUB-REPOSITORY-SETUP.md, "The merge by workflow"): equal means that SAP and
*& GitHub use the same secret and build the same text.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_set_event_secret NO STANDARD PAGE HEADING.

SELECTION-SCREEN BEGIN OF BLOCK secret WITH FRAME TITLE t_frame.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(25) t_secret FOR FIELD p_secret.
PARAMETERS p_secret TYPE c LENGTH 128 LOWER CASE.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK secret.

INITIALIZATION.
  t_frame  = 'Secret of the merge event'.
  t_secret = 'New secret (32+ characters)'.

AT SELECTION-SCREEN OUTPUT.
  " The secret is not shown while it is typed.
  LOOP AT SCREEN.
    IF screen-name = 'P_SECRET'.
      screen-invisible = 1.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

START-OF-SELECTION.
  DATA answer TYPE c LENGTH 1.

  TRY.
      IF p_secret IS INITIAL.
        IF zcl_tr_auth=>has_event_secret( ) = abap_true.
          WRITE / 'A secret is stored on this system. Enter a new one to replace it.'.
        ELSE.
          WRITE / 'No secret is stored on this system yet. Enter one.'.
        ENDIF.
        RETURN.
      ENDIF.

      IF zcl_tr_auth=>has_event_secret( ) = abap_true.
        CALL FUNCTION 'POPUP_TO_CONFIRM'
          EXPORTING
            titlebar              = 'Replace the secret'
            text_question         = 'A secret is stored already. Replace it? The secret in GitHub must be changed to the same value.'
            text_button_1         = 'Replace'
            text_button_2         = 'Cancel'
            default_button        = '2'
            display_cancel_button = abap_false
          IMPORTING
            answer                = answer
          EXCEPTIONS
            OTHERS                = 1.
        IF sy-subrc <> 0 OR answer <> '1'.
          WRITE / 'Not changed.'.
          RETURN.
        ENDIF.
      ENDIF.

      zcl_tr_auth=>store_event_secret( |{ p_secret }| ).
      CLEAR p_secret.
      WRITE / 'The secret is stored, encrypted. It cannot be read again.'.

      " Sample event for the comparison with the other side.
      DATA(sample) = zcl_tr_auth=>sign_release_event(
        request      = `DEVK900001`
        pull_request = 1
        sha          = `bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb`
        timestamp    = `1700000000`
        title        = `T (#1)`
        message      = `M` ).
      SKIP.
      WRITE / 'Signature of the sample event (DEVK900001, 1, 40 times b, 1700000000, T (#1), M):'.
      WRITE / sample.
    CATCH zcx_abapgit_exception INTO DATA(error).
      WRITE / error->get_text( ).
  ENDTRY.
