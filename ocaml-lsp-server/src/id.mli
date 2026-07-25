module Make () : sig
  type t

  val gen : unit -> t
  val to_int : t -> int
  val compare : t -> t -> Ordering.t
end
