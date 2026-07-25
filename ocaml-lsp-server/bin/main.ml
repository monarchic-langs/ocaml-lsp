module Cli = Lsp.Cli

let pp_uncaught formatter (exn, backtrace) =
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

let () =
  Printexc.record_backtrace true;
  let version = ref false in
  let prefer_dot_merlin = ref false in
  let arg = Lsp.Cli.Arg.create () in
  let spec =
    [ "--version", Arg.Set version, "print version"
    ; ( "--fallback-read-dot-merlin"
      , Arg.Set prefer_dot_merlin
      , "deprecated, same as --prefer-dot-merlin" )
    ; ( "--prefer-dot-merlin"
      , Arg.Set prefer_dot_merlin
      , "always read Merlin config from existing .merlin files. The `dot-merlin-reader` \
         package must be installed" )
    ]
    @ Cli.Arg.spec arg
  in
  let usage =
    "ocamllsp [ --stdio | --socket PORT | --port PORT | --pipe PIPE ] [ \
     --clientProcessId pid ] [ --prefer-dot-merlin ]"
  in
  Arg.parse spec (fun _ -> raise @@ Arg.Bad "anonymous arguments aren't allowed") usage;
  let channel =
    match Cli.Arg.channel arg with
    | Ok c -> c
    | Error s ->
      Format.eprintf "%s@.%!" s;
      Arg.usage spec usage;
      exit 1
  in
  let version = !version in
  if version
  then (
    let version = Ocaml_lsp_server.Version.get () in
    print_endline version)
  else (
    match (Ocaml_lsp_server.run channel ~prefer_dot_merlin:!prefer_dot_merlin) () with
    | () -> ()
    | exception exn ->
      let backtrace = Printexc.get_raw_backtrace () in
      Format.eprintf "%a@." pp_uncaught (exn, backtrace);
      exit 1)
;;
