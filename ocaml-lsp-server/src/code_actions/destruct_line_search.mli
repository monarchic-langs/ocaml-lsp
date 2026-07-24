type t =
  { match_start : int
  ; case_start : int option
  }

(** Locate a [match] on the first line and its first case, if any. The [match]
    must either be the first token or contain [position]. *)
val find : string -> position:int -> t option
