(** An exception together with the backtrace that raised it. *)

type t =
  { exn : exn
  ; backtrace : Printexc.raw_backtrace
  }

val try_with : (unit -> 'a) -> ('a, t) result

(** This function must be called before any other function in an exception
    handler so that it captures the correct backtrace. *)
val capture : exn -> t

val reraise : t -> 'a
val pp_uncaught : Format.formatter -> t -> unit
