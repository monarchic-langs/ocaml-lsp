type t =
  { exn : exn
  ; backtrace : Printexc.raw_backtrace
  }

let capture exn = { exn; backtrace = Printexc.get_raw_backtrace () }

let try_with f =
  match f () with
  | result -> Ok result
  | exception exn -> Error (capture exn)
;;

let reraise { exn; backtrace } = Printexc.raise_with_backtrace exn backtrace

let pp_uncaught formatter { exn; backtrace } =
  let message =
    Printf.sprintf
      "%s\n%s"
      (Printexc.to_string exn)
      (Printexc.raw_backtrace_to_string backtrace)
    |> String.split_on_char '\n'
    |> List.map (Printf.sprintf "| %s")
    |> String.concat "\n"
  in
  let line = String.make 71 '-' in
  Format.fprintf
    formatter
    "/%s\n| @{<error>Internal error@}: Uncaught exception.\n%s\n\\%s@."
    line
    message
    line
;;
