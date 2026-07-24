open Base
open Base_quickcheck
module Destruct_line = Ocaml_lsp_server.Testing.Destruct_line

let bounded value bound = Int.rem (value land Stdlib.max_int) bound

let whitespace ~allow_empty selector =
  let length = bounded selector 5 + if allow_empty then 0 else 1 in
  let char = if selector land 1 = 0 then ' ' else '\t' in
  Stdlib.String.make length char
;;

let identifier selector = Stdlib.String.make (bounded selector 8 + 1) 'x'

let check_equal label expected actual =
  if not (Option.equal Int.equal expected actual)
  then
    failwith
      (Printf.sprintf
         "%s: expected %s"
         label
         (Option.value_map expected ~default:"none" ~f:Int.to_string))
;;

let find_match source ~position =
  Option.map (Destruct_line.find source ~position) ~f:(fun result -> result.match_start)
;;

let find_case source ~position =
  Option.bind (Destruct_line.find source ~position) ~f:(fun result -> result.case_start)
;;

type context =
  | Line_start
  | Inline
[@@deriving quickcheck, sexp_of]

module Match_case = struct
  type t =
    { context : context
    ; indentation : int
    ; identifier_length : int
    ; cursor : int
    ; suffix : int
    }
  [@@deriving quickcheck, sexp_of]
end

let check_match { Match_case.context; indentation; identifier_length; cursor; suffix } =
  let indentation = whitespace ~allow_empty:true indentation in
  let prefix =
    match context with
    | Line_start -> indentation
    | Inline -> indentation ^ "let " ^ identifier identifier_length ^ " = "
  in
  let match_start = String.length prefix in
  let source = prefix ^ "match" ^ whitespace ~allow_empty:false suffix ^ "value" in
  let position =
    match context with
    | Line_start -> 0
    | Inline -> match_start + bounded cursor (String.length "match" + 1)
  in
  check_equal "match location" (Some match_start) (find_match source ~position);
  match context with
  | Line_start -> ()
  | Inline ->
    check_equal "position outside inline match" None (find_match source ~position:0)
;;

let%test_unit "find_match preserves offsets in line-leading and inline matches" =
  Base_quickcheck.Test.run_exn (module Match_case) ~f:check_match
;;

type expression =
  | Simple
  | Record_update
  | Nested_match
  | Nested_try
  | String_literal
  | Comment
[@@deriving quickcheck, sexp_of]

module Existing_case = struct
  type t =
    { indentation : int
    ; identifier_length : int
    ; before_with : int
    ; after_with : int
    ; expression : expression
    }
  [@@deriving quickcheck, sexp_of]
end

let check_existing_case
      { Existing_case.indentation
      ; identifier_length
      ; before_with
      ; after_with
      ; expression
      }
  =
  let prefix =
    whitespace ~allow_empty:true indentation
    ^ "let "
    ^ identifier identifier_length
    ^ " = "
  in
  let expression =
    match expression with
    | Simple -> "A"
    | Record_update -> "{ r with value = A }.value"
    | Nested_match -> "(match A with | A -> B)"
    | Nested_try -> "(try A with | _ -> A)"
    | String_literal -> "f \"with |\""
    | Comment -> "f (* with | *)"
  in
  let before_with = whitespace ~allow_empty:false before_with in
  let after_with = whitespace ~allow_empty:true after_with in
  let before_case = prefix ^ "match " ^ expression ^ before_with ^ "with" ^ after_with in
  let source = before_case ^ "| A -> _" in
  let match_start = String.length prefix in
  check_equal
    "case location"
    (Some (String.length before_case))
    (find_case source ~position:match_start)
;;

let%test_unit "find_case handles prefixes, whitespace, and nested syntax" =
  Base_quickcheck.Test.run_exn (module Existing_case) ~f:check_existing_case
;;

let%test_unit "keywords embedded in identifiers are ignored" =
  check_equal "match identifier" None (find_match "let matcher = 0" ~position:4);
  check_equal
    "match identifier with apostrophe"
    None
    (find_match "let match' = 0" ~position:4);
  check_equal
    "with identifier"
    None
    (find_case "match value somewith | A -> _" ~position:0)
;;

let%test_unit "find_case crosses comments and line breaks" =
  let before_case = "match A with\n(* existing case *)\n  " in
  check_equal
    "case after comment"
    (Some (String.length before_case))
    (find_case (before_case ^ "| A -> _") ~position:0)
;;

let%test_unit "matches without cases do not consume a later match" =
  check_equal
    "later match"
    None
    (find_case "match A with\nlet y = match B with | B -> _" ~position:0)
;;

let%test_unit "record updates without a case are ignored" =
  check_equal
    "record update"
    None
    (find_case "match { r with value = A } with" ~position:0)
;;
