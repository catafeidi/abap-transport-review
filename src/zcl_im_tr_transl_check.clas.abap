class ZCL_IM_TR_TRANSL_CHECK definition
  public
  final
  create public .

public section.

  interfaces IF_EX_CTS_REQUEST_CHECK .
protected section.
private section.
ENDCLASS.



CLASS ZCL_IM_TR_TRANSL_CHECK IMPLEMENTATION.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_ADD_OBJECTS.
  endmethod.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_CHANGING_OWNER.
  endmethod.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_CREATION.
  endmethod.


METHOD if_ex_cts_request_check~check_before_release.
*----------------------------------------------------------------------*
* BAdI implementation for CTS_REQUEST_CHECK (classic BAdI, multiple use).
*
* Translation check at the release of a task or request: every text of
* the objects in it must exist in the languages the project works in
* (STVARV ZTR_TRANSL_LANGUAGES). Only objects of the packages under Git
* are checked (STVARV ZTR_PACKAGES).
*
*   STVARV ZTR_TRANSL_MODE = OFF    -> nothing happens (the default)
*                          = INFORM -> the missing texts are shown, the
*                                      release goes on
*                          = BLOCK  -> the release is refused while a
*                                      text is missing
*
* On the screen the developer can choose "Translate now": the selection
* screen of report ZTR_TRANSL_REPORT opens, filled with the task or
* request being released, "Enter translations" and "Record in". F8 shows
* the missing texts in an editable list; or the texts are downloaded as
* an Excel file, and at the next release a translated file is uploaded.
* Save writes the translations as SE63 does and records them in the task
* or request being released. Then the check runs again, and when nothing
* is missing any more the release goes on by itself.
*
* A translation that is the same as the source text is never a reason
* to refuse: some product terms stay English on purpose. Only the texts
* the user sees when the product runs are checked; descriptions that
* only developers see are not (method IS_RUNTIME_TYPE of the check).
*
* Recording (STVARV ZTR_TRANSL_RECORD = X, also with mode OFF): at the
* release of a task, before the check, the translations of the text
* elements of the programs and classes that the task holds only as code
* are recorded in it (LANG entries), so that the transport carries them;
* see method RECORD_TRANSLATIONS. Not at the release of a request: its
* tasks have done it. A failure or a skip is only a message; the release
* is never refused for it.
*
* Delivery to customers: a request whose short text contains #DELIVERY
* (its tasks follow it) is refused while a text is missing, whatever the
* mode, with an error message and no "Translate now": translations are
* made in the development requests, never in a delivery. Nothing is
* recorded in it. A transport of copies with #DELIVERY is checked too.
*
* Way out for an emergency: a request whose short text contains
* #NOTRANSL is released without the check, together with its tasks. It
* also wins over #DELIVERY.
*
* If the check itself fails, the release is NOT refused; the developer
* gets an information message.
*
* Implementation ZTR_TRANSL_CHECK, class ZCL_IM_TR_TRANSL_CHECK. It runs
* next to ZTR_RELEASE_CHECK; each of the two can refuse the release. Off
* with the switch ZTR_DISABLED of the tools.
* The list of the missing texts: report ZTR_TRANSL_REPORT with the task
* or request.
* ABAP 7.40 syntax.
*----------------------------------------------------------------------*
  CONSTANTS development_task    TYPE trfunction VALUE 'S'.
  CONSTANTS repair_task         TYPE trfunction VALUE 'R'.
  CONSTANTS workbench_request   TYPE trfunction VALUE 'K'.
  CONSTANTS customizing_task    TYPE trfunction VALUE 'Q'.
  CONSTANTS customizing_request TYPE trfunction VALUE 'W'.
  CONSTANTS transport_of_copies TYPE trfunction VALUE 'T'.
  CONSTANTS examples            TYPE i VALUE 3.

  DATA findings   TYPE zcl_tr_transl_check=>ty_findings.
  DATA names      TYPE string_table.
  DATA returncode TYPE c LENGTH 1.
  " Message 001 of class 00 shows its four variables one after the other.
  DATA part_1     TYPE sy-msgv1.
  DATA part_2     TYPE sy-msgv2.
  DATA part_3     TYPE sy-msgv3.
  DATA part_4     TYPE sy-msgv4.

  " Nothing happens when the tools are switched off (STVARV ZTR_DISABLED),
  " as for the release check ZTR_RELEASE_CHECK.
  SELECT SINGLE low FROM tvarvc
    INTO @DATA(switch_off)
    WHERE name = 'ZTR_DISABLED' AND type = 'P' AND numb = '0000'.
  IF switch_off = abap_true.
    RETURN.
  ENDIF.

  " The markers are written in the request; a task follows its request.
  DATA(parent_text) = VALUE as4text( ).
  SELECT SINGLE strkorr FROM e070 INTO @DATA(parent) WHERE trkorr = @request.
  IF sy-subrc = 0 AND parent IS NOT INITIAL.
    SELECT SINGLE as4text FROM e07t INTO @parent_text WHERE trkorr = @parent.
  ENDIF.
  DATA(delivery) = xsdbool( text CS zcl_tr_transl_check=>delivery_marker OR
                            parent_text CS zcl_tr_transl_check=>delivery_marker ).

  DATA(mode) = zcl_tr_transl_check=>configured_mode( ).
  DATA(record) = zcl_tr_transl_check=>configured_record( ).
  IF mode = zcl_tr_transl_check=>mode-off AND record = abap_false AND delivery = abap_false.
    RETURN.
  ENDIF.
  DATA(languages) = zcl_tr_transl_check=>configured_languages( ).
  IF languages IS INITIAL.
    RETURN.
  ENDIF.

  " Workbench and customizing, tasks and requests; a transport of copies
  " only as a delivery. Never relocations or other types.
  IF type <> development_task AND type <> repair_task AND type <> workbench_request AND
     type <> customizing_task AND type <> customizing_request AND
     NOT ( type = transport_of_copies AND delivery = abap_true ).
    RETURN.
  ENDIF.

  " The way out for an emergency.
  IF text CS zcl_tr_transl_check=>skip_marker OR parent_text CS zcl_tr_transl_check=>skip_marker.
    RETURN.
  ENDIF.

  " Recording first: the translations of the objects go into the task
  " or request being released, whatever happens with the check.
  IF record = abap_true AND delivery = abap_false AND
     ( type = development_task OR type = repair_task OR type = customizing_task ).
    TRY.
        DATA(recorded) = NEW zcl_tr_transl_check( )->record_translations( objects = objects transport = request ).
        IF recorded-messages IS NOT INITIAL.
          MESSAGE |{ request }: { recorded-written } translation(s) recorded, { recorded-failed } not: | &&
                  |{ recorded-messages[ 1 ] }| TYPE 'S'.
        ENDIF.
      CATCH cx_root INTO DATA(record_error).
        MESSAGE |Translations of { request } not recorded: { record_error->get_text( ) }| TYPE 'S'.
    ENDTRY.
  ENDIF.
  IF mode = zcl_tr_transl_check=>mode-off AND delivery = abap_false.
    RETURN.
  ENDIF.

  TRY.
      findings = NEW zcl_tr_transl_check( )->check_transport_objects( objects ).
    CATCH cx_root INTO DATA(error).
      MESSAGE |Translation check of { request } did not run: { error->get_text( ) }| TYPE 'I'.
      RETURN.
  ENDTRY.

  DATA(missing) = zcl_tr_transl_check=>count( findings = findings
                                               status   = zcl_tr_transl_check=>status-missing ).
  IF missing = 0.
    RETURN.
  ENDIF.

  " The first objects, so that the developer knows where to start.
  LOOP AT findings INTO DATA(finding) WHERE status = zcl_tr_transl_check=>status-missing.
    DATA(name) = |{ finding-object } { condense( finding-obj_name ) } | &&
                 |(missing { zcl_tr_transl_check=>language_code( finding-language ) })|.
    IF NOT line_exists( names[ table_line = name ] ).
      APPEND name TO names.
    ENDIF.
  ENDLOOP.
  DATA(objects_text) = ``.
  LOOP AT names INTO DATA(listed) TO examples.
    objects_text = COND #( WHEN objects_text IS INITIAL THEN listed ELSE |{ objects_text }, { listed }| ).
  ENDLOOP.
  IF lines( names ) > examples.
    objects_text = |{ objects_text } and { lines( names ) - examples } more|.
  ENDIF.

  part_1 = |{ request }: { missing } text(s) without translation|.
  DATA(codes) = VALUE string_table( FOR language IN languages ( zcl_tr_transl_check=>language_code( language ) ) ).
  part_2 = | in { concat_lines_of( table = codes sep = `, ` ) }:|.
  part_3 = | { objects_text }.|.
  part_4 = | List: report { zcl_tr_transl_check=>report_name }.|.

* ---- a delivery: refused, nothing is translated into it ---------------
  IF delivery = abap_true.
    part_4 = | Delivery: translate in the development requests.|.
    IF sy-batch = abap_true.
      MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4.
    ENDIF.
    MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4 RAISING cancel.
  ENDIF.

  DATA(on_screen) = xsdbool( dialog = abap_true AND adt = abap_false AND sy-batch = abap_false ).

* ---- on the screen: translate right now, in a list --------------------
  IF on_screen = abap_true.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Translations are missing'
        text_question         = |{ part_1 }{ part_2 }{ part_3 } Translate them now: in the list (F8), | &&
                                |or download them as an Excel file and upload it at the next release. | &&
                                |Save writes them and records them in { request }.|
        text_button_1         = 'Translate now'
        icon_button_1         = 'ICON_CHANGE_TEXT'
        text_button_2         = COND string( WHEN mode = zcl_tr_transl_check=>mode-inform THEN `Release anyway`
                                             ELSE `Cancel release` )
        default_button        = '1'
        display_cancel_button = abap_false
      IMPORTING
        answer                = returncode
      EXCEPTIONS
        OTHERS                = 1.
    IF sy-subrc = 0 AND returncode = '1'.
      " The selection screen, filled with exactly what is released here:
      " F8 opens the editable list, or the developer chooses the download
      " or the upload of the Excel file. Save writes the translations and
      " records them in the task or request itself, so they are released
      " and pushed with it.
      SUBMIT (zcl_tr_transl_check=>report_name)
        VIA SELECTION-SCREEN
        WITH p_trkorr = request
        WITH p_edit   = abap_true
        WITH p_target = request
        AND RETURN.
      TRY.
          findings = NEW zcl_tr_transl_check( )->check_transport_objects( objects ).
        CATCH cx_root INTO error.
          MESSAGE |Translation check of { request } did not run: { error->get_text( ) }| TYPE 'I'.
          RETURN.
      ENDTRY.
      missing = zcl_tr_transl_check=>count( findings = findings status = zcl_tr_transl_check=>status-missing ).
      IF missing = 0.
        MESSAGE |{ request }: all texts are translated now| TYPE 'S'.
        RETURN.
      ENDIF.
      part_1 = |{ request }: still { missing } text(s) without translation|.
    ENDIF.
  ENDIF.

  IF mode = zcl_tr_transl_check=>mode-inform.
    " The release goes on.
    IF on_screen = abap_false.
      MESSAGE ID '00' TYPE 'S' NUMBER '001' WITH part_1 part_2 part_3 part_4.
    ENDIF.
    RETURN.
  ENDIF.

* ---- BLOCK: the refusal, visible wherever the release runs ------------
  IF sy-batch = abap_true.
    " Release in the background: this cancels the job RELEASE OF
    " <request>, and the reason stays in its job log (SM37).
    MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4.
  ENDIF.
  MESSAGE ID '00' TYPE 'E' NUMBER '001' WITH part_1 part_2 part_3 part_4 RAISING cancel.
ENDMETHOD.


  method IF_EX_CTS_REQUEST_CHECK~CHECK_BEFORE_RELEASE_SLIN.
  endmethod.
ENDCLASS.
