open Import
module Lexer = Ocaml_preprocess.Lexer_raw
module Parser = Ocaml_preprocess.Parser_raw

type t =
  { match_start : int
  ; case_start : int option
  }

type token =
  { kind : Parser.token
  ; start : int
  ; end_ : int
  }

let lexer code =
  let lexbuf = Lexing.from_string code in
  let lexer = Lexer.make (Lexer.keywords []) in
  let rec finish = function
    | Lexer.Return token -> Some token
    | Refill refill -> finish (refill ())
    | Fail _ -> None
  in
  fun () ->
    match finish (Lexer.token_without_comments lexer lexbuf) with
    | None | Some Parser.EOF -> None
    | Some kind ->
      Some { kind; start = Lexing.lexeme_start lexbuf; end_ = Lexing.lexeme_end lexbuf }
;;

let find_case next =
  let rec loop nested_branches braces =
    match next () with
    | None -> None
    | Some { kind = Parser.MATCH | Parser.TRY; _ } -> loop (nested_branches + 1) braces
    | Some { kind = Parser.LBRACE; _ } -> loop nested_branches (braces + 1)
    | Some { kind = Parser.RBRACE; _ } -> loop nested_branches (max 0 (braces - 1))
    | Some { kind = Parser.WITH; _ } when nested_branches > 0 ->
      loop (nested_branches - 1) braces
    | Some { kind = Parser.WITH; _ } when braces > 0 -> loop nested_branches braces
    | Some { kind = Parser.WITH; _ } ->
      (match next () with
       | Some { kind = Parser.BAR; start; _ } -> Some start
       | None | Some _ -> None)
    | Some _ -> loop nested_branches braces
  in
  loop 0 0
;;

let find code ~position =
  let line_end =
    Option.value (String.substr_index code ~pattern:"\n") ~default:(String.length code)
  in
  let next = lexer code in
  match next () with
  | None -> None
  | Some first ->
    let rec loop token =
      if token.start >= line_end
      then None
      else (
        match token.kind with
        | Parser.MATCH
          when token.start = first.start
               || (token.start <= position && position <= token.end_) ->
          Some { match_start = token.start; case_start = find_case next }
        | Parser.MATCH | _ ->
          (match next () with
           | None -> None
           | Some token -> loop token))
    in
    loop first
;;
