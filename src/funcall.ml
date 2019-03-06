open! Core_kernel
open! Import

type _ t =
  | Cons : 'a Value.Type.t * 'b t -> ('a -> 'b) t
  | Nullary : 'b Value.Type.t -> (unit -> 'b) t
  | Return : 'a Value.Type.t -> 'a t

let return type_ = Return type_

let nullary =
  Value.Type.create
    [%sexp "funcall-nullary-placeholder-value"]
    [%sexp_of: unit]
    ignore
    (const Value.nil)
;;

let nil = Value.Type.ignored

let ( @-> ) (type a b) (type_ : a Value.Type.t) (t : b t) =
  match t with
  | Cons _ ->
    (match Type_equal.Id.same type_.id nullary.id with
     | true -> raise_s [%message "Function already has arguments, cannot be nullary."]
     | false -> Cons (type_, t))
  | Nullary _ -> raise_s [%message "Cannot add arguments to nullary function."]
  | Return return_type ->
    (match Type_equal.Id.same_witness type_.id nullary.id with
     | Some Type_equal.T -> Nullary return_type
     | None -> Cons (type_, t))
;;

let return_type_of_value symbol (type_ : 'a Value.Type.t) value =
  match type_.of_value_exn value with
  | x -> x
  | exception exn ->
    raise_s
      [%message
        "funcall failed to convert return value."
          (symbol : Value.t)
          (type_ : _ Value.Type.t)
          (exn : Exn.t)]
;;

let arity t =
  let rec arity : type a. a t -> int -> int =
    fun t i ->
      match t with
      | Return _ -> i
      | Nullary _ -> i
      | Cons (_, t) -> arity t (i + 1)
  in
  arity t 0
;;

let wrap : type a. a t -> Value.t -> a =
  fun t symbol ->
    let rec curry : type a. a t -> Value.t -> Value.t array -> int -> a =
      fun t symbol args i ->
        match t with
        | Cons (type_, t) ->
          fun arg ->
            args.(i) <- type_.to_value arg;
            curry t symbol args (i + 1)
        | Nullary return_type ->
          assert (Int.( = ) i 0);
          fun _ -> Value.funcall0 symbol |> return_type_of_value symbol return_type
        | Return type_ ->
          Value.funcallN_array symbol args |> return_type_of_value symbol type_
    in
    let args = Array.create ~len:(arity t) Value.nil in
    curry t symbol args 0
;;

(* It's unclear how much this sort of unrolling matters, but the C bindings do it, so we
   might as well do it here. *)
let wrap_unrolled : type a. a t -> Value.t -> a =
  fun t symbol ->
    let ret type_ value = return_type_of_value symbol type_ value in
    match t with
    | Return type_ -> Value.funcall0 symbol |> ret type_
    | Nullary return_type -> fun _ -> Value.funcall0 symbol |> ret return_type
    | Cons (type1, Return type_) ->
      fun a1 -> Value.funcall1 symbol (a1 |> type1.to_value) |> ret type_
    | Cons (type1, Cons (type2, Return type_)) ->
      fun a1 a2 ->
        Value.funcall2 symbol (a1 |> type1.to_value) (a2 |> type2.to_value) |> ret type_
    | Cons (type1, Cons (type2, Cons (type3, Return type_))) ->
      fun a1 a2 a3 ->
        Value.funcall3
          symbol
          (a1 |> type1.to_value)
          (a2 |> type2.to_value)
          (a3 |> type3.to_value)
        |> ret type_
    | Cons (type1, Cons (type2, Cons (type3, Cons (type4, Return type_)))) ->
      fun a1 a2 a3 a4 ->
        Value.funcall4
          symbol
          (a1 |> type1.to_value)
          (a2 |> type2.to_value)
          (a3 |> type3.to_value)
          (a4 |> type4.to_value)
        |> ret type_
    | Cons (type1, Cons (type2, Cons (type3, Cons (type4, Cons (type5, Return type_))))) ->
      fun a1 a2 a3 a4 a5 ->
        Value.funcall5
          symbol
          (a1 |> type1.to_value)
          (a2 |> type2.to_value)
          (a3 |> type3.to_value)
          (a4 |> type4.to_value)
          (a5 |> type5.to_value)
        |> ret type_
    | t -> wrap t symbol
;;

let ( <: ) symbol t = wrap_unrolled t (symbol |> Symbol.to_value)

module On_parse_error = struct
  type t =
    | Allow_raise
    | Call_inner_function
  [@@deriving sexp_of]
end

let apply t f args ~on_parse_error =
  let wrong_number_of_args message =
    raise_s [%message message (arity t : int) (args : Value.t list)]
  in
  let rec apply : type a. a t -> a -> Value.t list -> Value.t =
    fun t f args ->
      match t with
      | Cons (type_, t) ->
        (match args with
         | arg :: args ->
           (match type_.of_value_exn arg with
            | arg -> apply t (f arg) args
            | exception exn -> on_parse_error exn)
         | [] ->
           (* Emacs convention: missing arguments are nil. *)
           (match type_.of_value_exn Value.nil with
            | arg -> apply t (f arg) args
            | exception exn -> on_parse_error exn))
      | Return type_ ->
        (match args with
         | [] -> type_.to_value f
         | _ :: _ -> wrong_number_of_args "Extra args.")
      | Nullary type_ ->
        (match args with
         | [] -> type_.to_value (f ())
         | _ :: _ -> wrong_number_of_args "Extra args.")
  in
  apply t f args
;;

module Private = struct
  let advice t f on_parse_error here inner rest =
    apply
      t
      (f (wrap_unrolled t inner))
      rest
      ~on_parse_error:
        (match (on_parse_error : On_parse_error.t) with
         | Allow_raise -> raise
         | Call_inner_function ->
           fun exn ->
             Echo_area.inhibit_messages (fun () ->
               Echo_area.message_s
                 [%message
                   "Ignoring advice that failed to parse its arguments."
                     ~_:(here : Source_code_position.t)
                     ~_:(exn : exn)]);
             Value.funcallN inner rest)
  ;;
end

include (Value.Type : Value.Type.S)
