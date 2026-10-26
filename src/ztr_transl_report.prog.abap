*&---------------------------------------------------------------------*
*& Report ZTR_TRANSL_REPORT
*&---------------------------------------------------------------------*
*& Lists the texts of repository objects that have no translation in the
*& languages the project works in, and lets them be translated right in
*& the list or in an Excel file.
*&
*& What it checks, the first of these that is entered:
*&   - a task or request: its objects and those of its tasks, as the
*&     release check (BAdI implementation ZTR_TRANSL_CHECK) sees them;
*&   - namespaces ("run all", the default): every object whose name
*&     starts with one of them, in any package that is not local. By
*&     default the namespaces of the packages under Git (STVARV
*&     ZTR_PACKAGES): /MYNS/ and /MYNS2/, /MYNS/;
*&   - packages: every object of the packages that match the pattern.
*& The languages come from STVARV ZTR_TRANSL_LANGUAGES unless others are
*& entered; object names in STVARV ZTR_TRANSL_EXCLUDE are skipped. Both
*& are written by report ZTR_SETUP.
*&
*& Status of a line:
*&   missing         the text has no translation: blocks the release
*&                   when STVARV ZTR_TRANSL_MODE = BLOCK
*&   same as source  the translation equals the source text: only shown,
*&                   because some product terms stay English on purpose
*&   not readable    SE63 could not read the object in this language
*&   hardcoded       a literal in the source code that the user sees: it
*&                   cannot be translated until the code uses a message
*&                   or a text symbol (column Where: include and line)
*&   table entry     an entry of a table with a language key that exists
*&                   in one language and not in the other (column Where:
*&                   the key of the entry); translated in SM30 or SE63
*& followed by the target language, e.g. "missing EN": the text exists
*& in the source language (column Source) and lacks the EN translation.
*&
*& Only the texts the user sees when the product runs are checked by
*& default (messages, text elements, GUI status, screen texts, field
*& labels, fixed values, transactions, OTR, F1 help). The descriptions of
*& classes, methods, function modules, tables and so on only with "Also
*& descriptions": development may be in English only.
*&
*& With "Enter translations" the column Translation can be typed in.
*& Length and Length check show at once (when the cell is left) whether
*& the text fits its maximum length. Save writes each translation as SE63
*& does and records it in the request (field "Record in"), so that it is
*& transported; a text that is too long is not written. Without "Enter
*& translations" the report changes nothing; a double click opens SE63,
*& or the source code at the line of a hardcoded text.
*&
*& Excel file: "Download" writes the missing texts as an .xlsx file in
*& which only the column Translation can be typed in; Length, Length
*& check and a red mark show a text that is too long. "Upload" reads such
*& a file: the report checks the objects of the file again, puts the
*& typed translations into the editable list, and Save writes them.
*& Nothing is written by the upload itself. Lines whose source text was
*& changed in the system since the download are left out. The editable
*& list has these functions in its toolbar: "Download Excel" writes
*& the lines of the list (with what is typed so far), "Upload file" puts
*& the translations of a file into the lines of the list.
*& CSV files: with "As CSV files" (or "Download CSV" in the toolbar) the
*& same texts are written as CSV, UTF-8, values in quotes, separated by
*& semicolons, for a translation tool or a text editor: nothing reformats
*& a value there, but there is no length check, colour or protection
*& either. The hardcoded texts go into a second CSV file next to it,
*& <name>_hardcoded.csv. The upload reads an Excel file or a CSV file.
*& With "Hardcoded texts" the downloaded file has a second sheet with the
*& hardcoded texts and two columns for proposals in English and German:
*& a developer moves them into messages or text symbols; the upload never
*& reads that sheet.
*& The column Proposed source text lets a translator propose a better
*& wording of the source text itself (both cells turn orange). An upload
*& shows these proposals in a popup list; they are never written, a
*& developer changes the objects.
*&
*& The release check calls this report with "Enter translations" when the
*& developer chooses "Translate now": the editable list opens at once.
*& ABAP 7.40 syntax.
*&---------------------------------------------------------------------*
REPORT ztr_transl_report.

DATA g_language  TYPE spras.
DATA g_namespace TYPE namespace.

" Texts of the selection screen, set in code so that no text elements
" have to be maintained. The COMMENT statements declare the variables.
SELECTION-SCREEN BEGIN OF BLOCK what WITH FRAME TITLE t_what.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_trkorr FOR FIELD p_trkorr.
PARAMETERS p_trkorr TYPE trkorr.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_nspc FOR FIELD s_nspc.
SELECT-OPTIONS s_nspc FOR g_namespace NO INTERVALS.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_pack FOR FIELD p_pack.
PARAMETERS p_pack TYPE devclass.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_lang FOR FIELD s_lang.
SELECT-OPTIONS s_lang FOR g_language NO INTERVALS.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK what.

SELECTION-SCREEN BEGIN OF BLOCK edit WITH FRAME TITLE t_editb.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_edit AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_edit FOR FIELD p_edit.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_target FOR FIELD p_target.
PARAMETERS p_target TYPE trkorr.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK edit.

SELECTION-SCREEN BEGIN OF BLOCK file WITH FRAME TITLE t_fileb.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_list RADIOBUTTON GROUP file DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(70) t_list FOR FIELD r_list.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_down RADIOBUTTON GROUP file.
SELECTION-SCREEN COMMENT 3(70) t_down FOR FIELD r_down.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN POSITION 3.
PARAMETERS p_csv AS CHECKBOX.
SELECTION-SCREEN COMMENT 5(70) t_csv FOR FIELD p_csv.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS r_up RADIOBUTTON GROUP file.
SELECTION-SCREEN COMMENT 3(70) t_up FOR FIELD r_up.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
SELECTION-SCREEN COMMENT 1(40) t_file FOR FIELD p_file.
PARAMETERS p_file TYPE rlgrap-filename LOWER CASE.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK file.

SELECTION-SCREEN BEGIN OF BLOCK show WITH FRAME TITLE t_show.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_same AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_same FOR FIELD p_same.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_unread AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_unread FOR FIELD p_unread.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_desc AS CHECKBOX.
SELECTION-SCREEN COMMENT 3(70) t_desc FOR FIELD p_desc.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_hard AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(70) t_hard FOR FIELD p_hard.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN BEGIN OF LINE.
PARAMETERS p_table AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN COMMENT 3(70) t_table FOR FIELD p_table.
SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK show.

CLASS lcl_report DEFINITION FINAL.

  PUBLIC SECTION.
    TYPES BEGIN OF ty_line.
    INCLUDE TYPE zcl_tr_transl_check=>ty_finding.
    TYPES status_text   TYPE c LENGTH 30.
    TYPES text_length   TYPE i.
    TYPES length_icon   TYPE icon_d.
    TYPES length_status TYPE c LENGTH 20.
    TYPES location      TYPE c LENGTH 80.
    TYPES include       TYPE progname.
    TYPES source_line   TYPE i.
    TYPES hardcoded_kind TYPE zcl_tr_transl_hardcoded=>ty_kind.
    TYPES END OF ty_line.
    TYPES ty_lines TYPE STANDARD TABLE OF ty_line WITH DEFAULT KEY.

    " Statuses of the lines that are not texts of SE63.
    CONSTANTS:
      BEGIN OF status,
        hardcoded   TYPE c LENGTH 1 VALUE 'H',
        table_entry TYPE c LENGTH 1 VALUE 'T',
      END OF status.

    " The lines of the list; global for the editable ALV and its callbacks.
    CLASS-DATA list     TYPE ty_lines.
    CLASS-DATA original TYPE ty_lines.
    CLASS-DATA check    TYPE REF TO zcl_tr_transl_check.
    CLASS-DATA target   TYPE trkorr.
    " What the list shows, e.g. the request; part of the file name.
    CLASS-DATA scope    TYPE string.
    " Proposed changes of source texts of the last upload, for the popup.
    CLASS-DATA source_changes TYPE zcl_tr_transl_file=>ty_source_changes.

    " GUI status of the editable list: SAP's STANDARD_FULLSCREEN of
    " SAPLSLVC_FULLSCREEN with the functions of the Excel file added.
    CONSTANTS editable_list_status TYPE sypfkey VALUE 'TRANSLATION_LIST'.
    CONSTANTS:
      BEGIN OF function,
        download_excel TYPE sy-ucomm VALUE 'DOWNLOAD_EXCEL',
        download_csv   TYPE sy-ucomm VALUE 'DOWNLOAD_CSV',
        upload_file    TYPE sy-ucomm VALUE 'UPLOAD_FILE',
      END OF function.
    CONSTANTS:
      BEGIN OF file_format,
        excel TYPE string VALUE `xlsx`,
        csv   TYPE string VALUE `csv`,
      END OF file_format.

    "! The namespaces of the packages under Git, e.g. /MYNS/ for
    "! the pattern /MYNS/*.
    CLASS-METHODS default_namespaces
      RETURNING
        VALUE(result) TYPE string_table.
    "! Save of the editable list: writes the typed translations.
    CLASS-METHODS save.
    "! A cell of the editable list was changed: Length and Length check of
    "! its line are calculated again.
    CLASS-METHODS on_data_changed
      IMPORTING
        changed TYPE REF TO cl_alv_changed_data_protocol.
    "! File name for the upload, from the dialog of the front end.
    CLASS-METHODS choose_file
      RETURNING
        VALUE(result) TYPE string.
    "! The lines of the list that need a translation, as an Excel file or
    "! as CSV files (FORMAT: a value of FILE_FORMAT).
    CLASS-METHODS download
      IMPORTING
        format TYPE string.
    "! Toolbar of the editable list: the translations of an Excel or CSV
    "! file go into the lines of the list. Nothing is written until Save.
    CLASS-METHODS upload_into_list.
    "! The proposed changes of source texts of an uploaded file, in a
    "! popup: they are never written, a developer changes the objects.
    CLASS-METHODS show_source_changes
      IMPORTING
        changes TYPE zcl_tr_transl_file=>ty_source_changes.
    METHODS run.

  PRIVATE SECTION.
    CONSTANTS excel_filter TYPE string VALUE `Excel (*.xlsx)|*.xlsx`.
    CONSTANTS csv_filter TYPE string VALUE `CSV UTF-8 (*.csv)|*.csv`.
    CONSTANTS upload_filter TYPE string
      VALUE `Excel or CSV (*.xlsx;*.csv)|*.xlsx;*.csv|Excel (*.xlsx)|*.xlsx|CSV (*.csv)|*.csv`.

    CLASS-METHODS set_length
      CHANGING
        line TYPE ty_line.
    "! The request dialog of the transport organizer: the task (or the
    "! request) chosen or created; empty when cancelled.
    CLASS-METHODS choose_request
      RETURNING
        VALUE(result) TYPE trkorr.
    METHODS selected_languages
      RETURNING
        VALUE(result) TYPE zcl_tr_transl_check=>ty_languages.
    METHODS add_findings
      IMPORTING
        findings TYPE zcl_tr_transl_check=>ty_findings.
    METHODS add_hardcoded
      IMPORTING
        objects TYPE zcl_tr_transl_check=>ty_objects.
    METHODS add_table_entries
      IMPORTING
        objects   TYPE zcl_tr_transl_check=>ty_objects
        languages TYPE zcl_tr_transl_check=>ty_languages.
    METHODS count_status
      IMPORTING
        status        TYPE c
      RETURNING
        VALUE(result) TYPE i.
    METHODS upload.
    CLASS-METHODS read_file
      IMPORTING
        file_name     TYPE string
      RETURNING
        VALUE(result) TYPE xstring.
    "! Writes the file on the front end; false, with a message, when it
    "! could not be written.
    CLASS-METHODS write_file
      IMPORTING
        file_name     TYPE string
        content       TYPE xstring
      RETURNING
        VALUE(result) TYPE abap_bool.
    METHODS take_over
      IMPORTING
        findings TYPE zcl_tr_transl_check=>ty_findings
        uploaded TYPE zcl_tr_transl_check=>ty_findings
      EXPORTING
        taken    TYPE i
        changed  TYPE i.
    METHODS show
      IMPORTING
        title TYPE csequence.
    METHODS show_editable
      IMPORTING
        title TYPE csequence.
    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING
        row.
ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD default_namespaces.
    " Namespaces (TRNSPACE) whose name matches the package pattern.
    DATA(pattern) = CONV string( zcl_tr_auth=>packages( ) ).
    REPLACE ALL OCCURRENCES OF '*' IN pattern WITH '%'.
    SELECT namespace FROM trnspace
      INTO TABLE @DATA(namespaces)
      WHERE namespace LIKE @pattern.
    LOOP AT namespaces INTO DATA(namespace).
      APPEND CONV string( namespace ) TO result.
    ENDLOOP.
  ENDMETHOD.


  METHOD run.
    DATA findings TYPE zcl_tr_transl_check=>ty_findings.
    DATA objects  TYPE zcl_tr_transl_check=>ty_objects.

    IF r_up = abap_true.
      upload( ).
      RETURN.
    ENDIF.

    DATA(languages) = selected_languages( ).
    IF languages IS INITIAL.
      MESSAGE 'No language to check: enter languages, or set them with report ZTR_SETUP' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    DATA(pattern) = COND devclass( WHEN p_pack IS INITIAL THEN zcl_tr_auth=>packages( ) ELSE p_pack ).
    check = NEW zcl_tr_transl_check( languages = languages package_pattern = pattern all_texts = p_desc ).
    target = COND #( WHEN p_target IS NOT INITIAL THEN p_target ELSE p_trkorr ).
    CLEAR scope.
    IF p_trkorr IS NOT INITIAL.
      objects = check->objects_in_scope( check->transport_objects( p_trkorr ) ).
      scope = |{ p_trkorr }|.
    ELSEIF s_nspc[] IS NOT INITIAL.
      LOOP AT s_nspc INTO DATA(namespace) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
        DATA(namespace_objects) = check->objects_in_scope( objects     = check->namespace_objects( namespace-low )
                                                           any_package = abap_true ).
        INSERT LINES OF namespace_objects INTO TABLE objects.
        scope = COND #( WHEN scope IS INITIAL THEN |namespace { namespace-low }| ELSE |{ scope }, { namespace-low }| ).
      ENDLOOP.
    ELSE.
      objects = check->objects_in_scope( check->package_objects( pattern ) ).
      scope = |packages { pattern }|.
    ENDIF.
    " The objects are in scope already: any package is accepted here.
    findings = check->check_objects( objects = objects any_package = abap_true ).

    add_findings( findings ).
    " Hardcoded texts and table entries cannot be typed in the list or
    " the file: they are only listed. The hardcoded texts also go into a
    " sheet of their own in the downloaded file, for proposals.
    DATA(only_listed) = xsdbool( p_edit = abap_false AND r_down = abap_false ).
    IF p_hard = abap_true AND ( only_listed = abap_true OR r_down = abap_true ).
      add_hardcoded( objects ).
    ENDIF.
    IF p_table = abap_true AND only_listed = abap_true.
      add_table_entries( objects = objects languages = languages ).
    ENDIF.
    SORT list BY object obj_name language text_key source_line.
    original = list.

    DATA(missing) = zcl_tr_transl_check=>count( findings = findings status = zcl_tr_transl_check=>status-missing ).
    DATA(same) = zcl_tr_transl_check=>count( findings = findings status = zcl_tr_transl_check=>status-same_as_source ).
    DATA(codes) = VALUE string_table( FOR language IN languages ( zcl_tr_transl_check=>language_code( language ) ) ).
    DATA(title) = |{ scope }, languages { concat_lines_of( table = codes sep = `, ` ) }: | &&
                  |{ missing } missing, { same } same as source|.
    IF only_listed = abap_true.
      title = |{ title }, { count_status( status-hardcoded ) } hardcoded, | &&
              |{ count_status( status-table_entry ) } table entries|.
    ELSEIF r_down = abap_true AND p_hard = abap_true.
      title = |{ title }, { count_status( status-hardcoded ) } hardcoded|.
    ENDIF.
    IF list IS INITIAL.
      MESSAGE |{ title }. Nothing to show| TYPE 'S'.
      RETURN.
    ENDIF.
    IF r_down = abap_true.
      download( COND #( WHEN p_csv = abap_true THEN file_format-csv ELSE file_format-excel ) ).
    ELSEIF p_edit = abap_true.
      show_editable( title ).
    ELSE.
      show( title ).
    ENDIF.
  ENDMETHOD.


  METHOD selected_languages.
    LOOP AT s_lang INTO DATA(selected) WHERE sign = 'I' AND option = 'EQ' AND low IS NOT INITIAL.
      APPEND selected-low TO result.
    ENDLOOP.
    IF result IS INITIAL.
      result = zcl_tr_transl_check=>configured_languages( ).
    ENDIF.
  ENDMETHOD.


  METHOD add_findings.
    LOOP AT findings INTO DATA(finding).
      IF ( finding-status = zcl_tr_transl_check=>status-same_as_source AND p_same = abap_false ) OR
         ( finding-status = zcl_tr_transl_check=>status-not_readable AND
           ( p_unread = abap_false OR p_edit = abap_true OR r_down = abap_true ) ).
        CONTINUE.
      ENDIF.
      DATA(line) = CORRESPONDING ty_line( finding ).
      line-status_text = |{ zcl_tr_transl_check=>status_text( finding-status ) } | &&
                         |{ zcl_tr_transl_check=>language_code( finding-language ) }|.
      set_length( CHANGING line = line ).
      APPEND line TO list.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_hardcoded.
    DATA(findings) = NEW zcl_tr_transl_hardcoded( )->check_objects( objects ).
    LOOP AT findings INTO DATA(finding).
      APPEND VALUE #( object = finding-object obj_name = finding-obj_name devclass = finding-devclass
                      status = status-hardcoded status_text = |hardcoded: { finding-kind }|
                      text_kind = 'Hardcoded text in the source code'
                      source_text = finding-text include = finding-include source_line = finding-line
                      location = |{ finding-include } line { finding-line }| hardcoded_kind = finding-kind ) TO list.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_table_entries.
    DATA(findings) = NEW zcl_tr_transl_table_texts( languages )->check_objects( objects ).
    LOOP AT findings INTO DATA(finding).
      APPEND VALUE #( object = 'TABL' obj_name = finding-tabname devclass = finding-devclass
                      status = status-table_entry text_kind = 'Entry of a text table (SM30)'
                      status_text = |table entry missing { zcl_tr_transl_check=>language_code( finding-language ) }|
                      language = finding-language source_language = finding-source_language
                      source_text = finding-source_text location = finding-entry_key ) TO list.
    ENDLOOP.
  ENDMETHOD.


  METHOD count_status.
    LOOP AT list TRANSPORTING NO FIELDS WHERE status = status.
      result = result + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD set_length.
    line-text_length   = strlen( line-target_text ).
    line-length_status = zcl_tr_transl_check=>length_status( text = line-target_text max_length = line-max_length ).
    line-length_icon   = COND #(
      WHEN line-target_text IS INITIAL THEN space
      WHEN zcl_tr_transl_check=>exceeded_by( text = line-target_text max_length = line-max_length ) > 0
        THEN icon_led_red
      ELSE icon_led_green ).
  ENDMETHOD.


  METHOD choose_request.
    DATA order TYPE trkorr.
    DATA task  TYPE trkorr.

    CALL FUNCTION 'TRINT_ORDER_CHOICE'
      EXPORTING
        wi_order_type          = 'K'
        wi_task_type           = 'S'
        wi_category            = 'SYST'
      IMPORTING
        we_order               = order
        we_task                = task
      EXCEPTIONS
        no_correction_selected = 1
        display_mode           = 2
        object_append_error    = 3
        recursive_call         = 4
        wrong_order_type       = 5
        OTHERS                 = 6.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    result = COND #( WHEN task IS NOT INITIAL THEN task ELSE order ).
  ENDMETHOD.


  METHOD on_data_changed.
    LOOP AT changed->mt_good_cells INTO DATA(cell) WHERE fieldname = 'TARGET_TEXT'.
      READ TABLE list ASSIGNING FIELD-SYMBOL(<line>) INDEX cell-row_id.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      " The value of the protocol is cut at 128 characters; the cell holds
      " the whole translation.
      changed->get_cell_value(
        EXPORTING
          i_row_id    = cell-row_id
          i_fieldname = 'TARGET_TEXT'
        IMPORTING
          e_value     = <line>-target_text ).
      set_length( CHANGING line = <line> ).
      changed->modify_cell( i_row_id = cell-row_id i_fieldname = 'TEXT_LENGTH'   i_value = <line>-text_length ).
      changed->modify_cell( i_row_id = cell-row_id i_fieldname = 'LENGTH_STATUS' i_value = <line>-length_status ).
      changed->modify_cell( i_row_id = cell-row_id i_fieldname = 'LENGTH_ICON'   i_value = <line>-length_icon ).
    ENDLOOP.
  ENDMETHOD.


  METHOD download.
    DATA file_name TYPE string.
    DATA path      TYPE string.
    DATA full_path TYPE string.
    DATA action    TYPE i.
    DATA lines     TYPE zcl_tr_transl_check=>ty_findings.
    DATA hardcoded TYPE zcl_tr_transl_hardcoded=>ty_findings.

    LOOP AT list INTO DATA(line).
      CASE line-status.
        WHEN zcl_tr_transl_check=>status-missing OR zcl_tr_transl_check=>status-same_as_source.
          APPEND CORRESPONDING #( line ) TO lines.
        WHEN status-hardcoded.
          APPEND VALUE #( object = line-object obj_name = line-obj_name devclass = line-devclass
                          include = line-include line = line-source_line kind = line-hardcoded_kind
                          text = line-source_text ) TO hardcoded.
      ENDCASE.
    ENDLOOP.
    IF lines IS INITIAL AND hardcoded IS INITIAL.
      MESSAGE 'No text to translate: nothing written' TYPE 'S'.
      RETURN.
    ENDIF.
    IF sy-batch = abap_true.
      MESSAGE 'The file can only be written in the dialog' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " Namespaces and requests as a file name: /MYNS/ -> _MYNS_.
    DATA(name_part) = scope.
    TRANSLATE name_part USING '/_ _,_:_'.
    DATA(default_name) = |translations_{ name_part }.{ format }|.
    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        default_extension = format
        default_file_name = default_name
        file_filter       = COND #( WHEN format = file_format-csv THEN csv_filter ELSE excel_filter )
      CHANGING
        filename          = file_name
        path              = path
        fullpath          = full_path
        user_action       = action
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0 OR action <> cl_gui_frontend_services=>action_ok.
      RETURN.
    ENDIF.

    DATA(file) = NEW zcl_tr_transl_file( ).
    IF format = file_format-excel.
      IF write_file( file_name = full_path content = file->to_xlsx( lines = lines hardcoded = hardcoded ) ) = abap_false.
        RETURN.
      ENDIF.
      MESSAGE |{ lines( lines ) } text(s) to translate| &&
              COND string( WHEN hardcoded IS NOT INITIAL THEN | and { lines( hardcoded ) } hardcoded text(s)| ) &&
              | written to { full_path }| TYPE 'S'.
      RETURN.
    ENDIF.

    " CSV has one table per file: the hardcoded texts go into a second
    " file next to the first, <name>_hardcoded.csv.
    DATA(written) = VALUE string_table( ).
    IF lines IS NOT INITIAL.
      IF write_file( file_name = full_path content = file->to_csv( lines ) ) = abap_false.
        RETURN.
      ENDIF.
      APPEND |{ lines( lines ) } text(s) to translate written to { full_path }| TO written.
    ENDIF.
    IF hardcoded IS NOT INITIAL.
      DATA(hardcoded_path) = full_path.
      DATA(extension_at) = find( val = hardcoded_path sub = `.csv` case = abap_false occ = -1 ).
      IF extension_at > 0.
        hardcoded_path = substring( val = hardcoded_path len = extension_at ).
      ENDIF.
      hardcoded_path = |{ hardcoded_path }_hardcoded.csv|.
      IF write_file( file_name = hardcoded_path content = file->hardcoded_to_csv( hardcoded ) ) = abap_false.
        RETURN.
      ENDIF.
      APPEND |{ lines( hardcoded ) } hardcoded text(s) to { hardcoded_path }| TO written.
    ENDIF.
    MESSAGE concat_lines_of( table = written sep = `, ` ) TYPE 'S'.
  ENDMETHOD.


  METHOD upload.
    DATA objects   TYPE zcl_tr_transl_check=>ty_objects.
    DATA languages TYPE zcl_tr_transl_check=>ty_languages.

    IF p_file IS INITIAL.
      MESSAGE 'Upload: enter the file' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    DATA(content) = read_file( CONV string( p_file ) ).
    IF content IS INITIAL.
      MESSAGE |The file { p_file } could not be read| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    DATA(file) = NEW zcl_tr_transl_file( )->from_file( content ).
    IF file-error IS NOT INITIAL.
      MESSAGE file-error TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " The objects and languages of the file are checked again, so that
    " a translation is only taken for a text that is still missing.
    LOOP AT file-lines INTO DATA(uploaded).
      INSERT VALUE #( object = uploaded-object obj_name = uploaded-obj_name ) INTO TABLE objects.
      IF NOT line_exists( languages[ table_line = uploaded-language ] ).
        APPEND uploaded-language TO languages.
      ENDIF.
    ENDLOOP.
    check = NEW zcl_tr_transl_check( languages = languages all_texts = abap_true ).
    DATA(findings) = check->check_objects( objects = objects any_package = abap_true ).
    take_over(
      EXPORTING
        findings = findings
        uploaded = file-lines
      IMPORTING
        taken    = DATA(taken)
        changed  = DATA(changed) ).
    target = COND #( WHEN p_target IS NOT INITIAL THEN p_target ELSE p_trkorr ).
    scope = COND #( WHEN target IS NOT INITIAL THEN |{ target }| ELSE `upload` ).

    DATA(not_found) = lines( file-lines ) - lines( list ) - changed.
    DATA(title) = |{ p_file }: { taken } translation(s) to save| &&
                  COND string( WHEN changed > 0 THEN |, { changed } left out (source text changed)| ) &&
                  COND string( WHEN not_found > 0 THEN |, { not_found } not missing any more| ).
    show_source_changes( file-source_changes ).
    IF list IS INITIAL.
      MESSAGE |{ title }. Nothing to save| TYPE 'S'.
      RETURN.
    ENDIF.
    show_editable( title ).
  ENDMETHOD.


  METHOD read_file.
    DATA binary TYPE solix_tab.
    DATA length TYPE i.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = file_name
        filetype   = 'BIN'
      IMPORTING
        filelength = length
      CHANGING
        data_tab   = binary
      EXCEPTIONS
        OTHERS     = 1 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    result = cl_bcs_convert=>solix_to_xstring( it_solix = binary iv_size = length ).
  ENDMETHOD.


  METHOD write_file.
    DATA(binary) = cl_bcs_convert=>xstring_to_solix( content ).
    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = xstrlen( content )
        filename     = file_name
        filetype     = 'BIN'
      CHANGING
        data_tab     = binary
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc <> 0.
      MESSAGE |The file { file_name } could not be written| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    result = abap_true.
  ENDMETHOD.


  METHOD take_over.
    " One line per text that is still missing (or the same as its
    " source) and is in the file with the same source text. ORIGINAL
    " keeps the state of the system, so that Save writes what came from
    " the file.
    CLEAR: list, original, taken, changed.
    LOOP AT findings INTO DATA(finding) WHERE status = zcl_tr_transl_check=>status-missing
                                           OR status = zcl_tr_transl_check=>status-same_as_source.
      READ TABLE uploaded INTO DATA(row) WITH KEY custmnr  = finding-custmnr
                                                  lxe_type = finding-lxe_type
                                                  lxe_name = finding-lxe_name
                                                  text_key = finding-text_key
                                                  language = finding-language.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF row-source_text <> finding-source_text.
        changed = changed + 1.
        CONTINUE.
      ENDIF.
      DATA(line) = CORRESPONDING ty_line( finding ).
      line-status_text = |{ zcl_tr_transl_check=>status_text( finding-status ) } | &&
                         |{ zcl_tr_transl_check=>language_code( finding-language ) }|.
      set_length( CHANGING line = line ).
      APPEND line TO original.
      IF row-target_text IS NOT INITIAL AND row-target_text <> finding-target_text.
        line-target_text = row-target_text.
        set_length( CHANGING line = line ).
        taken = taken + 1.
      ENDIF.
      APPEND line TO list.
    ENDLOOP.
  ENDMETHOD.


  METHOD upload_into_list.
    DATA taken     TYPE i.
    DATA changed   TYPE i.
    DATA not_found TYPE i.

    DATA(file_name) = choose_file( ).
    IF file_name IS INITIAL.
      RETURN.
    ENDIF.
    DATA(content) = read_file( file_name ).
    IF content IS INITIAL.
      MESSAGE |The file { file_name } could not be read| TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    DATA(file) = NEW zcl_tr_transl_file( )->from_file( content ).
    IF file-error IS NOT INITIAL.
      MESSAGE file-error TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " A translation of the file goes into the line of the same text, if
    " the source text is still the same. Lines of the file that are not in
    " the list (translated meanwhile, or another scope) are left out.
    LOOP AT file-lines INTO DATA(uploaded) WHERE target_text IS NOT INITIAL.
      READ TABLE list ASSIGNING FIELD-SYMBOL(<line>) WITH KEY custmnr  = uploaded-custmnr
                                                              lxe_type = uploaded-lxe_type
                                                              lxe_name = uploaded-lxe_name
                                                              text_key = uploaded-text_key
                                                              language = uploaded-language.
      IF sy-subrc <> 0.
        not_found = not_found + 1.
        CONTINUE.
      ENDIF.
      IF uploaded-source_text <> <line>-source_text.
        changed = changed + 1.
        CONTINUE.
      ENDIF.
      IF uploaded-target_text <> <line>-target_text.
        <line>-target_text = uploaded-target_text.
        set_length( CHANGING line = <line> ).
        taken = taken + 1.
      ENDIF.
    ENDLOOP.

    show_source_changes( file-source_changes ).
    MESSAGE |{ taken } translation(s) taken from the file, Save writes them| &&
            COND string( WHEN changed > 0 THEN |; { changed } left out (source text changed)| ) &&
            COND string( WHEN not_found > 0 THEN |; { not_found } not in the list| ) TYPE 'S'.
  ENDMETHOD.


  METHOD show_source_changes.
    DATA table TYPE REF TO cl_salv_table.

    IF changes IS INITIAL OR sy-batch = abap_true.
      RETURN.
    ENDIF.
    source_changes = changes.
    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = table
          CHANGING
            t_table      = source_changes ).
      CATCH cx_salv_msg INTO DATA(error).
        MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    table->get_functions( )->set_all( abap_true ).
    table->get_display_settings( )->set_list_header(
      CONV lvc_title( |{ lines( changes ) } proposed change(s) of source texts: not written, | &&
                      |for a developer (export the list)| ) ).
    DATA(columns) = table->get_columns( ).
    columns->set_optimize( abap_true ).
    TRY.
        columns->get_column( 'TEXT_KIND' )->set_long_text( 'Kind of text' ).
        columns->get_column( 'TEXT_KIND' )->set_medium_text( 'Kind of text' ).
        columns->get_column( 'TEXT_KIND' )->set_short_text( 'Kind' ).
        columns->get_column( 'SOURCE_TEXT' )->set_long_text( 'Source text now' ).
        columns->get_column( 'SOURCE_TEXT' )->set_medium_text( 'Source text now' ).
        columns->get_column( 'SOURCE_TEXT' )->set_short_text( 'Source' ).
        columns->get_column( 'PROPOSED' )->set_long_text( 'Proposed source text' ).
        columns->get_column( 'PROPOSED' )->set_medium_text( 'Proposed' ).
        columns->get_column( 'PROPOSED' )->set_short_text( 'Proposed' ).
        columns->get_column( 'LXE_TYPE' )->set_long_text( 'SE63 object type' ).
        columns->get_column( 'LXE_TYPE' )->set_medium_text( 'SE63 type' ).
        columns->get_column( 'LXE_TYPE' )->set_short_text( 'SE63 type' ).
        columns->get_column( 'LXE_NAME' )->set_long_text( 'SE63 object name' ).
        columns->get_column( 'LXE_NAME' )->set_medium_text( 'SE63 name' ).
        columns->get_column( 'LXE_NAME' )->set_short_text( 'SE63 name' ).
      CATCH cx_salv_not_found ##NO_HANDLER.
    ENDTRY.
    table->set_screen_popup( start_column = 5 end_column = 160 start_line = 3 end_line = 25 ).
    table->display( ).
  ENDMETHOD.


  METHOD choose_file.
    DATA files  TYPE filetable.
    DATA rc     TYPE i.
    DATA action TYPE i.

    cl_gui_frontend_services=>file_open_dialog(
      EXPORTING
        file_filter       = upload_filter
      CHANGING
        file_table        = files
        rc                = rc
        user_action       = action
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc = 0 AND action = cl_gui_frontend_services=>action_ok AND files IS NOT INITIAL.
      result = files[ 1 ]-filename.
    ENDIF.
  ENDMETHOD.


  METHOD show.
    DATA table TYPE REF TO cl_salv_table.

    TRY.
        cl_salv_table=>factory(
          IMPORTING
            r_salv_table = table
          CHANGING
            t_table      = list ).
      CATCH cx_salv_msg INTO DATA(error).
        MESSAGE error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    table->get_functions( )->set_all( abap_true ).
    table->get_display_settings( )->set_list_header( CONV lvc_title( title ) ).
    table->get_display_settings( )->set_striped_pattern( abap_true ).
    DATA(columns) = table->get_columns( ).
    columns->set_optimize( abap_true ).
    TRY.
        columns->get_column( 'STATUS_TEXT' )->set_long_text( 'Status' ).
        columns->get_column( 'STATUS_TEXT' )->set_medium_text( 'Status' ).
        columns->get_column( 'STATUS_TEXT' )->set_short_text( 'Status' ).
        columns->get_column( 'LANGUAGE' )->set_long_text( 'Target language' ).
        columns->get_column( 'LANGUAGE' )->set_medium_text( 'Target lang.' ).
        columns->get_column( 'LANGUAGE' )->set_short_text( 'Target' ).
        columns->get_column( 'SOURCE_LANGUAGE' )->set_long_text( 'Source language' ).
        columns->get_column( 'SOURCE_LANGUAGE' )->set_medium_text( 'Source lang.' ).
        columns->get_column( 'SOURCE_LANGUAGE' )->set_short_text( 'Source' ).
        columns->get_column( 'SOURCE_TEXT' )->set_long_text( 'Source text' ).
        columns->get_column( 'SOURCE_TEXT' )->set_medium_text( 'Source text' ).
        columns->get_column( 'SOURCE_TEXT' )->set_short_text( 'Source' ).
        columns->get_column( 'TARGET_TEXT' )->set_long_text( 'Translation' ).
        columns->get_column( 'TARGET_TEXT' )->set_medium_text( 'Translation' ).
        columns->get_column( 'TARGET_TEXT' )->set_short_text( 'Transl.' ).
        columns->get_column( 'LXE_TYPE' )->set_long_text( 'SE63 object type' ).
        columns->get_column( 'LXE_TYPE' )->set_medium_text( 'SE63 type' ).
        columns->get_column( 'LXE_TYPE' )->set_short_text( 'SE63 type' ).
        columns->get_column( 'LXE_NAME' )->set_long_text( 'SE63 object name' ).
        columns->get_column( 'LXE_NAME' )->set_medium_text( 'SE63 name' ).
        columns->get_column( 'LXE_NAME' )->set_short_text( 'SE63 name' ).
        columns->get_column( 'TEXT_KIND' )->set_long_text( 'Kind of text' ).
        columns->get_column( 'TEXT_KIND' )->set_medium_text( 'Kind of text' ).
        columns->get_column( 'TEXT_KIND' )->set_short_text( 'Kind' ).
        columns->get_column( 'LOCATION' )->set_long_text( 'Where (include and line, or entry)' ).
        columns->get_column( 'LOCATION' )->set_medium_text( 'Where' ).
        columns->get_column( 'LOCATION' )->set_short_text( 'Where' ).
        columns->get_column( 'STATUS' )->set_technical( abap_true ).
        columns->get_column( 'CUSTMNR' )->set_technical( abap_true ).
        columns->get_column( 'SOURCE_ISO' )->set_technical( abap_true ).
        columns->get_column( 'MAX_LENGTH' )->set_technical( abap_true ).
        columns->get_column( 'TEXT_LENGTH' )->set_technical( abap_true ).
        columns->get_column( 'LENGTH_ICON' )->set_technical( abap_true ).
        columns->get_column( 'LENGTH_STATUS' )->set_technical( abap_true ).
        columns->get_column( 'INCLUDE' )->set_technical( abap_true ).
        columns->get_column( 'SOURCE_LINE' )->set_technical( abap_true ).
        columns->get_column( 'HARDCODED_KIND' )->set_technical( abap_true ).
      CATCH cx_salv_not_found ##NO_HANDLER.
    ENDTRY.

    SET HANDLER on_double_click FOR table->get_event( ).
    table->display( ).
  ENDMETHOD.


  METHOD show_editable.
    " Classic ALV grid: only it lets a column be typed in without a
    " screen of its own. Form SET_STATUS sets the GUI status with the Excel
    " functions; Save and these functions call form USER_COMMAND; leaving
    " a changed cell calls form DATA_CHANGED.
    DATA catalog TYPE lvc_t_fcat.
    DATA layout  TYPE lvc_s_layo.

    catalog = VALUE #(
      ( fieldname = 'STATUS_TEXT'     coltext = 'Status'          outputlen = 18 )
      ( fieldname = 'LANGUAGE'        coltext = 'Language'        outputlen = 8 )
      ( fieldname = 'OBJECT'          coltext = 'Type'            outputlen = 5 )
      ( fieldname = 'OBJ_NAME'        coltext = 'Object'          outputlen = 30 )
      ( fieldname = 'TEXT_KIND'       coltext = 'Kind of text'    outputlen = 30 )
      ( fieldname = 'SOURCE_TEXT'     coltext = 'Source text'     outputlen = 45 )
      ( fieldname = 'TARGET_TEXT'     coltext = 'Translation'     outputlen = 45 edit = abap_true lowercase = abap_true )
      ( fieldname = 'MAX_LENGTH'      coltext = 'Max. length'     outputlen = 6 )
      ( fieldname = 'TEXT_LENGTH'     coltext = 'Length'          outputlen = 6 )
      ( fieldname = 'LENGTH_ICON'     coltext = 'Fits'            outputlen = 4 icon = abap_true )
      ( fieldname = 'LENGTH_STATUS'   coltext = 'Length check'    outputlen = 14 )
      ( fieldname = 'SOURCE_LANGUAGE' coltext = 'Source language' outputlen = 6 )
      ( fieldname = 'LXE_TYPE'        coltext = 'SE63 type'       outputlen = 6 )
      ( fieldname = 'LXE_NAME'        coltext = 'SE63 name'       outputlen = 40 )
      ( fieldname = 'TEXT_KEY'        coltext = 'Text key'        outputlen = 20 ) ).
    layout-grid_title = CONV lvc_title( |{ title }. Type the translations, then Save| ).
    layout-zebra      = abap_true.

    IF target IS INITIAL.
      MESSAGE 'No request in "Record in": Save asks for one' TYPE 'S'.
    ENDIF.

    CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
      EXPORTING
        i_callback_program       = sy-repid
        i_callback_pf_status_set = 'SET_STATUS'
        i_callback_user_command  = 'USER_COMMAND'
        is_layout_lvc            = layout
        it_fieldcat_lvc          = catalog
        it_events                = VALUE slis_t_event( ( name = 'DATA_CHANGED' form = 'DATA_CHANGED' ) )
        i_grid_settings          = VALUE lvc_s_glay( edt_cll_cb = abap_true )
      TABLES
        t_outtab                 = list
      EXCEPTIONS
        OTHERS                   = 1.
    IF sy-subrc <> 0.
      MESSAGE 'The list could not be shown' TYPE 'S' DISPLAY LIKE 'E'.
    ENDIF.
  ENDMETHOD.


  METHOD save.
    DATA typed TYPE zcl_tr_transl_check=>ty_findings.

    LOOP AT list INTO DATA(line).
      DATA(index) = sy-tabix.
      READ TABLE original INTO DATA(before) INDEX index.
      IF line-target_text IS INITIAL OR ( sy-subrc = 0 AND line-target_text = before-target_text ).
        CONTINUE.
      ENDIF.
      APPEND CORRESPONDING #( line ) TO typed.
    ENDLOOP.
    IF typed IS INITIAL.
      MESSAGE 'No translation was typed' TYPE 'S'.
      RETURN.
    ENDIF.
    " A translation is never saved without a request that carries it.
    IF target IS INITIAL.
      target = choose_request( ).
      IF target IS INITIAL.
        MESSAGE 'No request chosen: nothing was written' TYPE 'S'.
        RETURN.
      ENDIF.
    ENDIF.

    DATA(result) = check->write_translations( translations = typed target = target ).

    " Mark what was saved, so that the list shows the new state. A text
    " that is too long was not written and keeps its red light.
    LOOP AT list ASSIGNING FIELD-SYMBOL(<line>).
      DATA(position) = sy-tabix.
      READ TABLE original ASSIGNING FIELD-SYMBOL(<before>) INDEX position.
      IF sy-subrc = 0 AND <line>-target_text IS NOT INITIAL AND <line>-target_text <> <before>-target_text AND
         zcl_tr_transl_check=>exceeded_by( text = <line>-target_text max_length = <line>-max_length ) = 0.
        <line>-status_text = 'saved'.
        <before>-target_text = <line>-target_text.
      ENDIF.
    ENDLOOP.

    IF result-messages IS INITIAL.
      MESSAGE |{ result-written } translation(s) written| &&
              COND string( WHEN target IS NOT INITIAL THEN | and recorded in { target }| ELSE `` ) TYPE 'S'.
      RETURN.
    ENDIF.
    " Something went wrong for some lines: say which.
    DATA(first) = result-messages[ 1 ].
    DATA(length) = strlen( first ).
    IF length > 70.
      length = 70.
    ENDIF.
    DATA(text_1) = |{ result-written } translation(s) written, { result-failed } not|.
    DATA(text_2) = first(length).
    DATA(text_3) = ``.
    IF lines( result-messages ) > 1.
      text_3 = |and { lines( result-messages ) - 1 } more message(s)|.
    ENDIF.
    DATA(text_4) = COND string( WHEN target IS NOT INITIAL THEN |Recorded in { target }| ELSE `Not recorded in a request` ).
    CALL FUNCTION 'POPUP_TO_INFORM'
      EXPORTING
        titel = 'Translations'
        txt1  = text_1
        txt2  = text_2
        txt3  = text_3
        txt4  = text_4.
  ENDMETHOD.


  METHOD on_double_click.
    " A hardcoded text: the source code at its line. A text of SE63: SE63
    " for the object of the line; the translation itself is done there,
    " run the report again afterwards.
    READ TABLE list INTO DATA(line) INDEX row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    CASE line-status.
      WHEN status-hardcoded.
        CALL FUNCTION 'RS_TOOL_ACCESS'
          EXPORTING
            operation   = 'SHOW'
            object_name = line-include
            object_type = 'REPS'
            position    = line-source_line
          EXCEPTIONS
            OTHERS      = 1.
        IF sy-subrc <> 0.
          MESSAGE |{ line-location }: the source code cannot be shown| TYPE 'S' DISPLAY LIKE 'E'.
        ENDIF.
      WHEN status-table_entry.
        MESSAGE |Table { line-obj_name }, entry { line-location }: translate it in its maintenance view (SM30) | &&
                |or in SE63| TYPE 'S'.
      WHEN OTHERS.
        MESSAGE |SE63: object type { line-lxe_type }, object { line-lxe_name }, | &&
                |{ zcl_tr_transl_check=>language_code( line-source_language ) } to | &&
                |{ zcl_tr_transl_check=>language_code( line-language ) }| TYPE 'S'.
        CALL TRANSACTION 'SE63' WITH AUTHORITY-CHECK.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.


" Callback of the editable ALV (REUSE_ALV_GRID_DISPLAY_LVC): its GUI
" status, the standard one with the functions of the Excel file.
FORM set_status USING excluded TYPE slis_t_extab.
  SET PF-STATUS lcl_report=>editable_list_status EXCLUDING excluded.
ENDFORM.


" Callback of the editable ALV: Save, Download Excel, Download CSV,
" Upload file.
FORM user_command USING command TYPE sy-ucomm
                        field   TYPE slis_selfield.
  DATA grid TYPE REF TO cl_gui_alv_grid.

  IF command <> '&DATA_SAVE' AND
     command <> lcl_report=>function-download_excel AND
     command <> lcl_report=>function-download_csv AND
     command <> lcl_report=>function-upload_file.
    RETURN.
  ENDIF.
  " Take over what was typed into the grid.
  CALL FUNCTION 'GET_GLOBALS_FROM_SLVC_FULLSCR'
    IMPORTING
      e_grid = grid.
  IF grid IS BOUND.
    grid->check_changed_data( ).
  ENDIF.
  CASE command.
    WHEN lcl_report=>function-download_excel.
      lcl_report=>download( lcl_report=>file_format-excel ).
      RETURN.
    WHEN lcl_report=>function-download_csv.
      lcl_report=>download( lcl_report=>file_format-csv ).
      RETURN.
    WHEN lcl_report=>function-upload_file.
      lcl_report=>upload_into_list( ).
    WHEN OTHERS.
      lcl_report=>save( ).
  ENDCASE.
  field-refresh    = abap_true.
  field-row_stable = abap_true.
  field-col_stable = abap_true.
ENDFORM.


" Callback of the editable ALV: a changed cell was left.
FORM data_changed USING changed TYPE REF TO cl_alv_changed_data_protocol.
  lcl_report=>on_data_changed( changed ).
ENDFORM.


INITIALIZATION.
  t_what   = 'What to check'.
  t_trkorr = 'Task or request (empty: namespaces)'.
  t_nspc   = 'Namespaces (run all)'.
  t_pack   = 'Packages (if no namespace)'.
  t_lang   = 'Languages (empty: from STVARV)'.
  t_editb  = 'Translate in the list'.
  t_edit   = 'Enter translations: Save writes them as SE63 does'.
  t_target = 'Record in (empty: task or request above)'.
  t_fileb  = 'Excel or CSV file'.
  t_list   = 'No file: show the list'.
  t_down   = 'Download the texts to translate as an Excel file'.
  t_csv    = 'As CSV files instead (UTF-8, separated by semicolons)'.
  t_up     = 'Upload a translated Excel or CSV file into the editable list'.
  t_file   = 'File to upload'.
  t_show   = 'Show also'.
  t_same   = 'Translations that are the same as the source text'.
  t_unread = 'Objects that SE63 could not read'.
  t_desc   = 'Also descriptions that only developers see'.
  t_hard   = 'Hardcoded texts in the source code (list, own sheet or CSV file)'.
  t_table  = 'Entries of text tables without translation (only in the list)'.

  LOOP AT lcl_report=>default_namespaces( ) INTO DATA(g_default).
    APPEND VALUE #( sign = 'I' option = 'EQ' low = g_default ) TO s_nspc.
  ENDLOOP.
  LOOP AT zcl_tr_transl_check=>configured_languages( ) INTO DATA(g_configured).
    APPEND VALUE #( sign = 'I' option = 'EQ' low = g_configured ) TO s_lang.
  ENDLOOP.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  DATA(g_file) = lcl_report=>choose_file( ).
  IF g_file IS NOT INITIAL.
    p_file = g_file.
  ENDIF.

START-OF-SELECTION.
  NEW lcl_report( )->run( ).
