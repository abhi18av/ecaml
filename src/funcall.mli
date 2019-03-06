(** A typeful interface for calling Elisp, as [external] does for C. E.g., {[

      module F = struct

        let not : bool -> bool = Q.not <: bool @-> return bool

        let about_emacs : unit -> unit = Q.about_emacs <: nullary @-> return nil

      end

      let non f = Fn.compose F.not f

      let about_emacs = F.about_emacs

    ]} The [F] convention is borrowed from the Emacs C source. *)

open! Core_kernel
open! Import

type 'a t

val return : 'a Value.Type.t -> 'a t
val nil : unit Value.Type.t
val nullary : unit Value.Type.t

(** [Q.foo <: ...] types an Elisp function, like how [foo :> t] types an OCaml value. *)
val ( <: ) : Symbol.t -> 'a t -> 'a

val ( @-> ) : 'a Value.Type.t -> 'b t -> ('a -> 'b) t

include Value.Type.S

module On_parse_error : sig
  type t =
    | Allow_raise
    | Call_inner_function
  [@@deriving sexp_of]
end

module Private : sig
  (** Exposed for the implementation of [Advice.around_funcall] *)
  val advice
    :  'a t
    -> ('a -> 'a)
    -> On_parse_error.t
    -> Source_code_position.t
    -> Value.t
    -> Value.t list
    -> Value.t
end
