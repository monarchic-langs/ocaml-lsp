module Make () = struct
  type t = int

  let next = ref 0

  let gen () =
    let id = !next in
    incr next;
    id
  ;;

  let to_int t = t
  let compare x y = Ordering.of_int (Stdlib.Int.compare x y)
end
