# abapGit and documentation objects with a namespace (DOCV)

Seen with abapGit 1.132 on a 7.40 system, not checked with other versions: abapGit writes no file for documentation objects whose name has a namespace, for example `/NAMESPACE/DTEXT_SOMETHING`. In the constructor of `ZCL_ABAPGIT_OBJECT_DOCV` it takes the document class from the first two characters of the name, `/N`, finds no document and treats the object as missing, although the texts exist (table `DOKHL`).

Only systems with namespaced documentation objects are affected. `ZTR_SETUP` checks whether the fix below is in and shows a yellow line when it is not.

## The fix

SE24, `ZCL_ABAPGIT_OBJECT_DOCV`, method `CONSTRUCTOR`: a name with a namespace should always go through the namespace branch, which splits it correctly.

```abap
    IF ms_item-obj_name(2) <> 'DT'. " IN, MO, UO, UP
```

becomes

```abap
    " Names with a namespace (/NAMESPACE/DT...) go through the split below.
    IF ms_item-obj_name(2) <> 'DT' AND ms_item-obj_name(1) <> '/'. " IN, MO, UO, UP
```

The branch below takes the class (`DT`, `IN`, ...) from the name without namespace and puts the namespace back in front of the object. It is a change to abapGit (a local modification), so it is lost when abapGit is updated: check again after an update. `ZTR_SETUP` finds the fix by the text `obj_name(1) <> '/'` in that constructor.

Until the fix is in, `ZTR_PUSH_TRANSPORT` keeps these files on GitHub and logs "abapGit writes no file for ... on this system" instead of removing them.
