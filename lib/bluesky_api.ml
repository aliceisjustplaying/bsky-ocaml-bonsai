open! Core
open! Js_of_ocaml

module Auth = struct
  type session = {
    access_jwt: string;
    refresh_jwt: string;
    handle: string;
    did: string;
  } [@@deriving sexp, equal]

  let create_session ~handle ~app_password ~on_result =
    let url = "https://bsky.social/xrpc/com.atproto.server.createSession" in
    let body = 
      `Assoc [
        ("identifier", `String handle);
        ("password", `String app_password);
      ]
      |> Yojson.Safe.to_string
    in
    
    let headers = Js.Unsafe.obj [|
      ("Content-Type", Js.Unsafe.inject (Js.string "application/json"))
    |] in
    
    let init = Js.Unsafe.obj [|
      ("method", Js.Unsafe.inject (Js.string "POST"));
      ("headers", Js.Unsafe.inject headers);
      ("body", Js.Unsafe.inject (Js.string body))
    |] in
    
    let promise = Js.Unsafe.global##fetch (Js.string url) init in
    
    let handle_response response =
      let status = Js.Unsafe.get response "status" in
      let text_promise = Js.Unsafe.meth_call response "text" [||] in
      
      let handle_text text =
        let response_text = Js.to_string text in
        if status >= 200 && status < 300 then
          try
            match Yojson.Safe.from_string response_text with
            | `Assoc fields ->
              let get_string key =
                match List.Assoc.find fields ~equal:String.equal key with
                | Some (`String s) -> s
                | _ -> failwith (sprintf "Expected string for %s" key)
              in
              on_result (Ok {
                access_jwt = get_string "accessJwt";
                refresh_jwt = get_string "refreshJwt";
                handle = get_string "handle";
                did = get_string "did";
              })
            | _ -> on_result (Error "Invalid response format")
          with
          | exn -> on_result (Error (sprintf "Parse error: %s" (Exn.to_string exn)))
        else
          on_result (Error (sprintf "Authentication failed: %s" response_text))
      in
      
      ignore (Js.Unsafe.meth_call text_promise "then" [|
        Js.Unsafe.inject (Js.wrap_callback handle_text)
      |])
    in
    
    let handle_error _ =
      on_result (Error "Network error")
    in
    
    ignore (
      Js.Unsafe.meth_call promise "then" [|
        Js.Unsafe.inject (Js.wrap_callback handle_response)
      |] |> fun promise ->
      Js.Unsafe.meth_call promise "catch" [|
        Js.Unsafe.inject (Js.wrap_callback handle_error)
      |]
    )
end

module Post = struct
  let create_post ~session ~text ~on_result =
    let url = "https://bsky.social/xrpc/com.atproto.repo.createRecord" in
    let created_at = 
      let date = new%js Js.date_now in
      Js.to_string date##toISOString
    in
    let body = 
      `Assoc [
        ("repo", `String session.Auth.did);
        ("collection", `String "app.bsky.feed.post");
        ("record", `Assoc [
          ("text", `String text);
          ("createdAt", `String created_at);
        ]);
      ]
      |> Yojson.Safe.to_string
    in
    
    let headers = Js.Unsafe.obj [|
      ("Content-Type", Js.Unsafe.inject (Js.string "application/json"));
      ("Authorization", Js.Unsafe.inject (Js.string (sprintf "Bearer %s" session.Auth.access_jwt)))
    |] in
    
    let init = Js.Unsafe.obj [|
      ("method", Js.Unsafe.inject (Js.string "POST"));
      ("headers", Js.Unsafe.inject headers);
      ("body", Js.Unsafe.inject (Js.string body))
    |] in
    
    let promise = Js.Unsafe.global##fetch (Js.string url) init in
    
    let handle_response response =
      let status = Js.Unsafe.get response "status" in
      let text_promise = Js.Unsafe.meth_call response "text" [||] in
      
      let handle_text text =
        let response_text = Js.to_string text in
        if status >= 200 && status < 300 then
          on_result (Ok response_text)
        else
          on_result (Error (sprintf "Post creation failed: %s" response_text))
      in
      
      ignore (Js.Unsafe.meth_call text_promise "then" [|
        Js.Unsafe.inject (Js.wrap_callback handle_text)
      |])
    in
    
    let handle_error _ =
      on_result (Error "Network error")
    in
    
    ignore (
      Js.Unsafe.meth_call promise "then" [|
        Js.Unsafe.inject (Js.wrap_callback handle_response)
      |] |> fun promise ->
      Js.Unsafe.meth_call promise "catch" [|
        Js.Unsafe.inject (Js.wrap_callback handle_error)
      |]
    )
end