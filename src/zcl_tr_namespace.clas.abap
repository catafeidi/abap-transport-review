*----------------------------------------------------------------------*
* Class ZCL_TR_NAMESPACE: the namespace of an object or package name.
*
* A namespace usually is one product line (for example /MYNS/ for the
* core and /MYNSREP/ for the reports), delivered on its own, so a
* transport request belongs to one line only. The release check uses
* this class to refuse a task or request whose objects come from more
* than one namespace. Objects without a namespace (Z, Y, $TMP) do not
* count.
* ABAP 7.40.
*----------------------------------------------------------------------*
CLASS zcl_tr_namespace DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_namespaces TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    " /MYNS/CORE -> /MYNS/; ZCL_TOOL, $TMP -> empty (no namespace).
    CLASS-METHODS of_name
      IMPORTING
        name          TYPE csequence
      RETURNING
        VALUE(result) TYPE string.
    " The namespaces in a readable list, for a message: /MYNS/, /MYNSREP/
    CLASS-METHODS as_text
      IMPORTING
        namespaces    TYPE ty_namespaces
      RETURNING
        VALUE(result) TYPE string.
ENDCLASS.



CLASS zcl_tr_namespace IMPLEMENTATION.

  METHOD of_name.
    DATA closing TYPE i.

    DATA(upper) = to_upper( condense( name ) ).
    IF strlen( upper ) < 3 OR upper(1) <> '/'.
      RETURN.
    ENDIF.
    FIND '/' IN SECTION OFFSET 1 OF upper MATCH OFFSET closing.
    IF sy-subrc <> 0 OR closing < 2.
      RETURN.
    ENDIF.
    result = substring( val = upper len = closing + 1 ).
  ENDMETHOD.


  METHOD as_text.
    result = concat_lines_of( table = namespaces sep = `, ` ).
  ENDMETHOD.

ENDCLASS.
