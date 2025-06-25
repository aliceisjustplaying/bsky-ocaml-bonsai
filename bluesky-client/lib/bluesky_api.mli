open! Core

module Auth : sig
  type session = {
    access_jwt: string;
    refresh_jwt: string;
    handle: string;
    did: string;
  } [@@deriving sexp, equal]

  val create_session : 
    handle:string -> 
    app_password:string -> 
    on_result:((session, string) Result.t -> unit) ->
    unit
end

module Post : sig
  val create_post : 
    session:Auth.session -> 
    text:string -> 
    on_result:((string, string) Result.t -> unit) ->
    unit
end