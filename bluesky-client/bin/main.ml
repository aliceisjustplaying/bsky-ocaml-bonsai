open! Core
open! Bonsai_web

let () =
  Start.start
    ~bind_to_element_with_id:"app"
    Bluesky_client_lib.App.component