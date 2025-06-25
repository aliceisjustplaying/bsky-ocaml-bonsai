open! Core
open! Async
open Cohttp_async

let handler ~body:_ _sock req =
  let uri = Cohttp.Request.uri req in
  let path = Uri.path uri in
  let headers = Cohttp.Header.init () 
    |> fun h -> Cohttp.Header.add h "content-type" "text/html"
    |> fun h -> Cohttp.Header.add h "access-control-allow-origin" "*"
    |> fun h -> Cohttp.Header.add h "access-control-allow-methods" "GET, POST, OPTIONS"
    |> fun h -> Cohttp.Header.add h "access-control-allow-headers" "Content-Type, Authorization"
  in
  match path with
  | "/" | "/index.html" ->
    let%bind content = Reader.file_contents "index.html" in
    Server.respond_string ~headers content
  | "/main.bc.js" | "/_build/default/bin/main.bc.js" ->
    let headers = Cohttp.Header.init ()
      |> fun h -> Cohttp.Header.add h "content-type" "application/javascript"
      |> fun h -> Cohttp.Header.add h "access-control-allow-origin" "*"
    in
    let%bind content = Reader.file_contents "_build/default/bin/main.bc.js" in
    Server.respond_string ~headers content
  | _ ->
    Server.respond_string ~status:`Not_found "Not found"

let () =
  let port = try int_of_string (Sys.get_argv ()).(1) with _ -> 8000 in
  don't_wait_for (
    let%bind _server = 
      Server.create ~on_handler_error:`Raise
        (Async.Tcp.Where_to_listen.of_port port) handler 
    in
    Core.printf "Server running at http://localhost:%d/\n%!" port;
    Deferred.never ()
  );
  never_returns (Scheduler.go ())