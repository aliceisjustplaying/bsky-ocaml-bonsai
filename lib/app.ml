open! Core
open! Bonsai_web
open Bonsai.Let_syntax
open! Js_of_ocaml
module Form = Bonsai_web_ui_form

(* Global mutable state for passing results from callbacks to Bonsai *)
let pending_auth_result : (Bluesky_api.Auth.session, string) Result.t option ref = ref None
let pending_post_result : (string, string) Result.t option ref = ref None

module Model = struct
  type auth_state = 
    | Not_logged_in
    | Logging_in
    | Logged_in of Bluesky_api.Auth.session
    | Error of string
  [@@deriving sexp, equal]

  type t = {
    auth_state: auth_state;
    post_status: string option;
    checking_auth: bool;
    checking_post: bool;
  } [@@deriving sexp, equal]

  let default = {
    auth_state = Not_logged_in;
    post_status = None;
    checking_auth = false;
    checking_post = false;
  }
end

module Action = struct
  type t =
    | Login of { handle: string; app_password: string }
    | Post of string
    | Update_auth_state of Model.auth_state
    | Update_post_status of string option
    | Check_pending_results
  [@@deriving sexp]
end

let apply_action ~inject:_ ~schedule_event:_ model = function
  | Action.Login { handle; app_password } ->
    Firebug.console##log (Js.string "Login action triggered");
    pending_auth_result := None;
    Bluesky_api.Auth.create_session ~handle ~app_password
      ~on_result:(fun result ->
        Firebug.console##log (Js.string "Got login result, storing in pending_auth_result");
        pending_auth_result := Some result
      );
    { model with Model.auth_state = Model.Logging_in; checking_auth = true }
  
  | Action.Post text ->
    (match model.Model.auth_state with
    | Model.Logged_in session ->
      pending_post_result := None;
      Bluesky_api.Post.create_post ~session ~text
        ~on_result:(fun result ->
          Firebug.console##log (Js.string "Got post result");
          pending_post_result := Some result
        );
      { model with checking_post = true }
    | _ -> model)
    
  | Action.Check_pending_results ->
    Firebug.console##log (Js.string "Checking pending results...");
    let model = 
      if model.checking_auth then
        match !pending_auth_result with
        | Some (Ok session) ->
          Firebug.console##log (Js.string "Found successful auth result!");
          pending_auth_result := None;
          { model with Model.auth_state = Model.Logged_in session; checking_auth = false }
        | Some (Error msg) ->
          Firebug.console##log (Js.string (sprintf "Found auth error: %s" msg));
          pending_auth_result := None;
          { model with Model.auth_state = Model.Error msg; checking_auth = false }
        | None -> model
      else model
    in
    let model = 
      if model.checking_post then
        match !pending_post_result with
        | Some (Ok _) ->
          Firebug.console##log (Js.string "Found successful post result!");
          pending_post_result := None;
          { model with Model.post_status = Some "Post created successfully!"; checking_post = false }
        | Some (Error msg) ->
          Firebug.console##log (Js.string (sprintf "Found post error: %s" msg));
          pending_post_result := None;
          { model with Model.post_status = Some (sprintf "Error: %s" msg); checking_post = false }
        | None -> model
      else model
    in
    model
    
  | Action.Update_auth_state auth_state ->
    Firebug.console##log (Js.string (sprintf "Updating auth state: %s" 
      (Sexp.to_string (Model.sexp_of_auth_state auth_state))));
    { model with Model.auth_state }
    
  | Action.Update_post_status post_status ->
    { model with Model.post_status }

let login_form inject =
  let%sub handle_form = Form.Elements.Textbox.string () in
  let%sub password_form = Form.Elements.Password.string () in
  let%arr handle_form = handle_form
  and password_form = password_form
  and inject = inject in
  let handle_value = Form.value handle_form in
  let password_value = Form.value password_form in
  let on_submit = 
    match handle_value, password_value with
    | Ok handle, Ok app_password when String.length handle > 0 && String.length app_password > 0 ->
      Some (inject (Action.Login { handle; app_password }))
    | _ -> None
  in
  Vdom.Node.div
    [ Vdom.Node.h2 ~attrs:[] [ Vdom.Node.text "Login to Bluesky" ]
    ; Vdom.Node.div
        [ Vdom.Node.label ~attrs:[] [ Vdom.Node.text "Handle: " ]
        ; Form.view_as_vdom handle_form
        ]
    ; Vdom.Node.div
        [ Vdom.Node.label ~attrs:[] [ Vdom.Node.text "App Password: " ]
        ; Form.view_as_vdom password_form
        ]
    ; Vdom.Node.button
        ~attrs:(match on_submit with
         | Some event -> [ Vdom.Attr.on_click (fun _ -> event) ]
         | None -> [ Vdom.Attr.disabled ])
        [ Vdom.Node.text "Login" ]
    ]

let post_form inject =
  let%sub text_form = Form.Elements.Textarea.string () in
  let%arr text_form = text_form
  and inject = inject in
  let text_value = Form.value text_form in
  let on_submit = 
    match text_value with
    | Ok text when String.length text > 0 ->
      Some (inject (Action.Post text))
    | _ -> None
  in
  Vdom.Node.div
    [ Vdom.Node.h2 ~attrs:[] [ Vdom.Node.text "Create Post" ]
    ; Vdom.Node.div
        [ Form.view_as_vdom text_form ]
    ; Vdom.Node.button
        ~attrs:(match on_submit with
         | Some event -> [ Vdom.Attr.on_click (fun _ -> event) ]
         | None -> [ Vdom.Attr.disabled ])
        [ Vdom.Node.text "Post" ]
    ]

let component =
  let%sub state, inject = 
    Bonsai.state_machine0 
      (module Model)
      (module Action)
      ~default_model:Model.default
      ~apply_action
  in
  (* Set up periodic checking using Bonsai.Clock.every *)
  let%sub () =
    let%sub should_check = 
      let%arr state = state in
      state.checking_auth || state.checking_post
    in
    match%sub should_check with
    | true ->
      Bonsai.Clock.every
        ~when_to_start_next_effect:`Every_multiple_of_period_non_blocking
        (Time_ns.Span.of_ms 100.0)
        (let%map inject = inject in inject Action.Check_pending_results)
    | false -> Bonsai.const ()
  in
  let%sub login_form = login_form inject in
  let%sub post_form = post_form inject in
  let%arr state = state
  and login_form = login_form
  and post_form = post_form in
  let content = 
    match state.Model.auth_state with
    | Not_logged_in -> login_form
    | Logging_in ->
      Vdom.Node.div
        [ Vdom.Node.p ~attrs:[] [ Vdom.Node.text "Logging in..." ]
        ]
    | Error msg -> 
      Vdom.Node.div
        [ Vdom.Node.p 
            ~attrs:[ Vdom.Attr.style (Css_gen.color (`Name "red")) ]
            [ Vdom.Node.text (sprintf "Error: %s" msg) ]
        ; login_form
        ]
    | Logged_in session ->
      Vdom.Node.div
        [ Vdom.Node.p ~attrs:[] [ Vdom.Node.text (sprintf "Logged in as: %s" session.handle) ]
        ; post_form
        ; (match state.post_status with
           | Some status -> 
             Vdom.Node.p 
               ~attrs:[ Vdom.Attr.style (Css_gen.color (`Name "green")) ]
               [ Vdom.Node.text status ]
           | None -> Vdom.Node.none)
        ]
  in
  Vdom.Node.div
    [ Vdom.Node.h1 ~attrs:[] [ Vdom.Node.text "Bluesky Client" ]
    ; content
    ]