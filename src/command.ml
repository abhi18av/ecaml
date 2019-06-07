open! Core_kernel
open! Import0

module Q = struct
  include Q

  let call_interactively = "call-interactively" |> Symbol.intern
  and current_prefix_arg = "current-prefix-arg" |> Symbol.intern
  and prefix_numeric_value = "prefix-numeric-value" |> Symbol.intern
end

module Current_buffer = Current_buffer0

include Value.Make_subtype (struct
    let name = "command"
    let here = [%here]
    let is_in_subtype = Value.is_command
  end)

let history_var =
  Var.create ("command-history" |> Symbol.intern) (Value.Type.list Form.type_)
;;

let history () = Current_buffer0.value_exn history_var

module Raw_prefix_argument = struct
  type t =
    | Absent
    | Int of int
    | Minus
    | Nested of int
  [@@deriving sexp_of]

  let minus = "-" |> Value.intern

  let to_value = function
    | Absent -> Value.nil
    | Int i -> i |> Value.of_int_exn
    | Minus -> minus
    | Nested i -> Value.cons (i |> Value.of_int_exn) Value.nil
  ;;

  let of_value_exn value =
    if Value.is_nil value
    then Absent
    else if Value.is_integer value
    then Int (Value.to_int_exn value)
    else if Value.is_cons value
    then Nested (Value.car_exn value |> Value.to_int_exn)
    else if Value.eq value minus
    then Minus
    else
      raise_s
        [%message
          "[Raw_prefix_argument.of_value] got unexpected value" (value : Value.t)]
  ;;

  let type_ =
    Value.Type.create [%message "raw_prefix_arg"] [%sexp_of: t] of_value_exn to_value
  ;;

  let for_current_command = Var.create Q.current_prefix_arg type_

  let numeric_value t =
    Symbol.funcall1 Q.prefix_numeric_value (t |> to_value) |> Value.to_int_exn
  ;;
end

let call_interactively
      ?(raw_prefix_argument = Raw_prefix_argument.Absent)
      ?(record = false)
      command
  =
  Current_buffer.set_value Raw_prefix_argument.for_current_command raw_prefix_argument;
  Symbol.funcall2_i Q.call_interactively command (record |> Value.of_bool)
;;

let inhibit_quit = Var.create ("inhibit-quit" |> Symbol.intern) Value.Type.bool
let quit_flag = Var.create ("quit-flag" |> Symbol.intern) Value.Type.bool
let request_quit () = Current_buffer.set_value quit_flag true

let quit_requested () =
  (* We use [try-with] because calling into Elisp can itself check [quit-flag]
     and raise.  And in fact does, at least in Emacs 25.2. *)
  try Current_buffer.value_exn quit_flag with
  | _ -> true
;;
