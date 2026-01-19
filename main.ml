[@@@warning "-27"]

let ( let@ ) finally fn = Fun.protect ~finally fn

type entry =
  { key : Rowex.key
  ; value : int }

let entry =
  let open Jsont in
  let key =
    let enc (x : Rowex.key) = (x :> string) in
    let dec str =
      try Rowex.key str
      with _exn -> Fmt.invalid_arg "Invalid ROWEX key: %S" str in
    map ~dec ~enc string in
  let key = Object.mem "key" ~enc:(fun t -> t.key) key in
  let value = Object.mem "value" ~enc:(fun t -> t.value) int_as_string in
  let fn key value = { key; value } in
  Object.map fn
  |> key |> value |> Object.finish

let _entries = Jsont.list entry

let vget rowex req (key : Rowex.key) _server _ =
  let open Vifu.Response.Syntax in
  Mpart.reader rowex @@ fun reader ->
  try let value = Mpart.lookup reader key in
      let* () = Vifu.Response.with_json req Jsont.int_as_string value in
      Vifu.Response.respond `OK
  with Not_found ->
      let* () = Vifu.Response.with_text req (Fmt.str "%s not found\n" (key :> string)) in
      Vifu.Response.respond `Not_found

let vadd rowex req _server _ =
  let open Vifu.Response.Syntax in
  match Vifu.Request.of_json req with
  | Ok entry ->
      Mpart.writer rowex @@ fun writer ->
      let fn { key; value } =
        try Mpart.insert writer key value
        with Rowex.Duplicate ->
          Logs.warn (fun m -> m "An user tries to insert a duplicate into our tree") in
      List.iter fn [ entry ];
      let* () = Vifu.Response.empty in
      Vifu.Response.respond `OK
  | Error _ ->
      let* () = Vifu.Response.with_text req "Invalid JSON request\n" in
      Vifu.Response.respond `Bad_request

let vrem rowex req (key : Rowex.key) _server _ =
  let open Vifu.Response.Syntax in
  Mpart.writer rowex @@ fun writer ->
  let () =
    try Mpart.remove writer key
    with exn -> Logs.warn (fun m -> m "Unexpected error: %S" (Printexc.to_string exn)) in
  let* () = Vifu.Response.empty in
  Vifu.Response.respond `OK

module RNG = Mirage_crypto_rng.Fortuna

let kv ~name =
  let fn blk () = Mpart.make blk in
  Mkernel.(map fn [ block name ])

let key = Tyre.map Rowex.key (Vifu.Uri.string `Path)

let run _ cidr gateway port =
  Mkernel.run [ Mnet.stackv4 ~name:"service" ?gateway cidr; kv ~name:"rowex" ]
  @@ fun (daemon, tcpv4, _udpv4) rowex () ->
  let rng = Mirage_crypto_rng_mkernel.initialize (module RNG) in
  let@ () = fun () -> Mnet.kill daemon in
  let@ () = fun () -> Mirage_crypto_rng_mkernel.kill rng in
  let routes =
    let open Vifu.Route in
    let open Vifu.Uri in
    [ get (rel / "get" /% key /?? any) --> vget rowex
    ; post (Vifu.Type.json_encoding entry) (rel / "add" /?? any) --> vadd rowex
    ; delete (rel / "rem" /% key /?? any) --> vrem rowex ] in
  let cfg = Vifu.Config.v port in
  Vifu.run ~cfg tcpv4 routes ()

open Cmdliner

let output_options = "OUTPUT OPTIONS"
let verbosity = Logs_cli.level ~docs:output_options ()
let renderer = Fmt_cli.style_renderer ~docs:output_options ()

let utf_8 =
  let doc = "Allow binaries to emit UTF-8 characters." in
  Arg.(value & opt bool true & info [ "with-utf-8" ] ~doc)

let t0 = Mkernel.clock_monotonic ()
let error_msgf fmt = Fmt.kstr (fun msg -> Error (`Msg msg)) fmt
let neg fn = fun x -> not (fn x)
let pp_mpart_tag ppf tags =
  let tags = Option.value ~default:Logs.Tag.empty tags in
  match Logs.Tag.get Mpart.tag tags with
  | uid -> Fmt.pf ppf "[%a]" Fmt.(styled `Yellow int) uid
  | exception _exn -> ()

let reporter sources ppf =
  let re = Option.map Re.compile sources in
  let print src =
    let some re = (neg List.is_empty) (Re.matches re (Logs.Src.name src)) in
    Option.fold ~none:true ~some re
  in
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let pp header tags k ppf fmt =
      let t1 = Mkernel.clock_monotonic () in
      let delta = Float.of_int (t1 - t0) in
      let delta = delta /. 1_000_000_000. in
      Fmt.kpf k ppf
        ("[+%a][%a]%a[%a]%a: " ^^ fmt ^^ "\n%!")
        Fmt.(styled `Blue (fmt "%04.04f"))
        delta
        Fmt.(styled `Cyan int)
        (Stdlib.Domain.self () :> int)
        Logs_fmt.pp_header (level, header)
        Fmt.(styled `Magenta string)
        (Logs.Src.name src)
        pp_mpart_tag tags
    in
    match (level, print src) with
    | Logs.Debug, false -> k ()
    | _, true | _ -> msgf @@ fun ?header ?tags fmt -> pp header tags k ppf fmt
  in
  { Logs.report }

let regexp =
  let parser str =
    match Re.Pcre.re str with
    | re -> Ok (str, `Re re)
    | exception _ -> error_msgf "Invalid PCRegexp: %S" str
  in
  let pp ppf (str, _) = Fmt.string ppf str in
  Arg.conv (parser, pp)

let sources =
  let doc = "A regexp (PCRE syntax) to identify which log we print." in
  let open Arg in
  value & opt_all regexp [ ("", `None) ] & info [ "l" ] ~doc ~docv:"REGEXP"

let setup_sources = function
  | [ (_, `None) ] -> None
  | res ->
      let res = List.map snd res in
      let res =
        List.fold_left
          (fun acc -> function `Re re -> re :: acc | _ -> acc)
          [] res
      in
      Some (Re.alt res)

let setup_sources = Term.(const setup_sources $ sources)

let setup_logs utf_8 style_renderer sources level =
  Option.iter (Fmt.set_style_renderer Fmt.stdout) style_renderer;
  Fmt.set_utf_8 Fmt.stdout utf_8;
  Logs.set_level level;
  Logs.set_reporter (reporter sources Fmt.stdout);
  Option.is_none level

let setup_logs =
  Term.(const setup_logs $ utf_8 $ renderer $ setup_sources $ verbosity)

let ipv4 =
  let doc = "The IP address of the unikernel." in
  let ipaddr = Arg.conv (Ipaddr.V4.Prefix.of_string, Ipaddr.V4.Prefix.pp) in
  let open Arg in
  required & opt (some ipaddr) None & info [ "ipv4" ] ~doc ~docv:"IPv4"

let ipv4_gateway =
  let doc = "The IP gateway." in
  let ipaddr = Arg.conv (Ipaddr.V4.of_string, Ipaddr.V4.pp) in
  let open Arg in
  value & opt (some ipaddr) None & info [ "ipv4-gateway" ] ~doc ~docv:"IPv4"

let port =
  let doc = "The HTTP port" in
  let open Arg in
  value & opt int 80 & info [ "p"; "port" ] ~doc ~docv:"PORT"

let _cachesize =
  let doc = "The size of the cache (must be a power of two)." in
  let open Arg in
  value & opt int 0x100 & info [ "cachesize" ] ~doc ~docv:"SIZE"

let term =
  let open Term in
  const run $ setup_logs $ ipv4 $ ipv4_gateway $ port

let cmd =
  let info = Cmd.info "kevin" in
  Cmd.v info term

let () = Cmd.(exit @@ eval cmd)
