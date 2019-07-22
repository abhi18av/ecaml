open! Core_kernel
open! Import

let advice_add =
  Funcall.("advice-add" <: Symbol.t @-> Symbol.t @-> Symbol.t @-> return nil)
;;

let add_predefined_function advice_name ~for_function =
  advice_add for_function Q.K.around advice_name
;;

let add_internal advice_name here ~for_function ?docstring ?interactive ?should_profile f
  =
  Defun.defun
    advice_name
    here
    ?docstring
    ?interactive
    ?should_profile
    (Returns Value.Type.value)
    (let open Defun.Let_syntax in
     let%map_open () = return ()
     and inner = required "inner" value
     and rest = rest "rest" value in
     f inner rest);
  add_predefined_function advice_name ~for_function
;;

let around_values
      advice_name
      here
      ?docstring
      ~for_function
      ?interactive
      ?should_profile
      f
  =
  add_internal
    advice_name
    here
    ?docstring
    ~for_function
    ?interactive
    ?should_profile
    (fun inner rest -> f (Value.funcallN ?should_profile inner) rest)
;;

module On_parse_error = struct
  type t =
    | Allow_raise
    | Call_inner_function
  [@@deriving sexp_of]
end

let around_funcall
      advice_name
      here
      ?docstring
      ~for_function
      ?interactive
      ?(on_parse_error = On_parse_error.Allow_raise)
      ?should_profile
      funcall
      f
  =
  add_internal
    advice_name
    here
    ~for_function
    ?docstring
    ?interactive
    ?should_profile
    (fun inner rest ->
       Funcall.Private.apply
         funcall
         (f (Funcall.Private.wrap_unrolled funcall inner))
         rest
         ~on_parse_error:
           (match (on_parse_error : On_parse_error.t) with
            | Allow_raise -> raise
            | Call_inner_function ->
              fun exn ->
                Echo_area.inhibit_messages Sync (fun () ->
                  message_s
                    [%message
                      "Ignoring advice that failed to parse its arguments."
                        ~_:(here : Source_code_position.t)
                        ~_:(exn : exn)]);
                Value.funcallN inner rest))
;;

let advice_remove = Funcall.("advice-remove" <: Symbol.t @-> Symbol.t @-> return nil)
let remove advice_name ~for_function = advice_remove for_function advice_name
