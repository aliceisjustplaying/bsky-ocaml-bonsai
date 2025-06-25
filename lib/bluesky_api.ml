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
    
    let xhr = XmlHttpRequest.create () in
    xhr##_open (Js.string "POST") (Js.string url) Js._true;
    xhr##setRequestHeader (Js.string "Content-Type") (Js.string "application/json");
    
    xhr##.onreadystatechange := Js.wrap_callback (fun _ ->
      if phys_equal xhr##.readyState XmlHttpRequest.DONE then
        let status = xhr##.status in
        let response_text = Js.Opt.get xhr##.responseText (fun () -> Js.string "") |> Js.to_string in
        if status >= 200 && status < 300 then
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
        else
          on_result (Error (sprintf "Authentication failed: %s" response_text))
    );
    
    xhr##send (Js.some (Js.string body))
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
    
    let xhr = XmlHttpRequest.create () in
    xhr##_open (Js.string "POST") (Js.string url) Js._true;
    xhr##setRequestHeader (Js.string "Content-Type") (Js.string "application/json");
    xhr##setRequestHeader (Js.string "Authorization") (Js.string (sprintf "Bearer %s" session.Auth.access_jwt));
    
    xhr##.onreadystatechange := Js.wrap_callback (fun _ ->
      if phys_equal xhr##.readyState XmlHttpRequest.DONE then
        let status = xhr##.status in
        let response_text = Js.Opt.get xhr##.responseText (fun () -> Js.string "") |> Js.to_string in
        if status >= 200 && status < 300 then
          on_result (Ok response_text)
        else
          on_result (Error (sprintf "Post creation failed: %s" response_text))
    );
    
    xhr##send (Js.some (Js.string body))
end