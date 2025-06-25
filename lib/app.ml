open! Core
open! Bonsai_web
open Bonsai.Let_syntax
module Form = Bonsai_web_ui_form

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
  } [@@deriving sexp, equal]

  let default = {
    auth_state = Not_logged_in;
    post_status = None;
  }
end

module Action = struct
  type t =
    | Login of { handle: string; app_password: string }
    | Post of string
    | Auth_response of (Bluesky_api.Auth.session, string) Result.t
    | Post_response of (string, string) Result.t
  [@@deriving sexp]
end

let apply_action ~inject ~schedule_event model = function
  | Action.Login { handle; app_password } ->
    (* Instead of polling, we directly inject the response when it arrives *)
    Bluesky_api.Auth.create_session ~handle ~app_password
      ~on_result:(fun result -> 
        schedule_event (inject (Action.Auth_response result)));
    { model with Model.auth_state = Model.Logging_in }
  
  | Action.Post text ->
    (match model.Model.auth_state with
    | Model.Logged_in session ->
      Bluesky_api.Post.create_post ~session ~text
        ~on_result:(fun result -> 
          schedule_event (inject (Action.Post_response result)));
      model
    | _ -> model)
    
  | Action.Auth_response (Ok session) ->
    { model with Model.auth_state = Model.Logged_in session }
    
  | Action.Auth_response (Error msg) ->
    { model with Model.auth_state = Model.Error msg }
    
  | Action.Post_response (Ok _) ->
    { model with Model.post_status = Some "Post created successfully!" }
    
  | Action.Post_response (Error msg) ->
    { model with Model.post_status = Some (sprintf "Error: %s" msg) }

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