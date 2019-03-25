open! Core_kernel
open! Import
open Defun

let here = [%here]
let return_type = Value.Type.sexpable (module Sexp) ~name:[%sexp "sexp"]

let print_funcallN symbol args =
  print_s (Value.Type.of_value_exn return_type (Symbol.funcallN symbol args))
;;

let%expect_test "[defun]" =
  let symbol = Symbol.gensym () in
  defun
    symbol
    here
    ~docstring:"Returns its own arguments as a sexp."
    (Returns return_type)
    (let open Let_syntax in
     let%map_open () = return ()
     and i = required ("int" |> Symbol.intern) Value.Type.int
     and s = required ("string" |> Symbol.intern) Value.Type.string
     and s_o = optional ("string-optional" |> Symbol.intern) Value.Type.string
     and rest = rest ("rest" |> Symbol.intern) Value.Type.string in
     [%message
       "Got args." (i : int) (s : string) (s_o : string option) (rest : string list)]);
  print_funcallN
    symbol
    [ (1 |> Value.Type.(int |> to_value))
    ; ("two" |> Value.Type.(string |> to_value))
    ; ("three" |> Value.Type.(string |> to_value))
    ; ("four" |> Value.Type.(string |> to_value))
    ; ("five" |> Value.Type.(string |> to_value))
    ];
  [%expect
    {|
    ("Got args."
      (i 1)
      (s two)
      (s_o (three))
      (rest (four five))) |}];
  print_endline (Help.describe_function_text ~obscure_symbol:true symbol);
  [%expect
    {|
<SYMBOL> is a Lisp function.

(<SYMBOL> INT STRING &optional STRING-OPTIONAL &rest REST)

Returns its own arguments as a sexp. |}]
;;

let%expect_test "[defun] tuple ordering" =
  let symbol = Symbol.gensym () in
  defun
    symbol
    here
    ~docstring:""
    (Returns return_type)
    (let open Let_syntax in
     let%map_open () = return ()
     and difference =
       let%map minuend = required ("minuend" |> Symbol.intern) Value.Type.int
       and subtrahend = required ("subtrahend" |> Symbol.intern) Value.Type.int in
       minuend - subtrahend
     in
     [%message (difference : int)]);
  print_funcallN
    symbol
    [ (2 |> Value.Type.(int |> to_value)); (1 |> Value.Type.(int |> to_value)) ];
  [%expect {|
    (difference 1) |}];
  print_endline (Help.describe_function_text ~obscure_symbol:true symbol);
  [%expect {|
<SYMBOL> is a Lisp function.

(<SYMBOL> MINUEND SUBTRAHEND) |}]
;;

let%expect_test "[defun] wrong number of arguments" =
  let symbol = Symbol.gensym () in
  defun
    symbol
    here
    ~docstring:""
    (Returns return_type)
    (let open Defun.Let_syntax in
     let%map_open () = return ()
     and arg = required ("arg" |> Symbol.intern) int in
     [%message (arg : int)]);
  print_funcallN symbol (List.init 1 ~f:Value.Type.(int |> to_value));
  [%expect {| (arg 0) |}];
  show_raise (fun () ->
    Value.For_testing.map_elisp_signal_omit_data (fun () ->
      print_funcallN symbol (List.init 2 ~f:Value.Type.(int |> to_value))));
  [%expect {|
    (raised wrong-number-of-arguments) |}];
  show_raise (fun () ->
    Value.For_testing.map_elisp_signal_omit_data (fun () ->
      print_funcallN symbol (List.init 0 ~f:Value.Type.(int |> to_value))));
  [%expect {|
    (raised wrong-number-of-arguments) |}]
;;

let%expect_test "[defun] omitted optional arguments" =
  let symbol = Symbol.gensym () in
  defun
    symbol
    here
    ~docstring:""
    (Returns return_type)
    (let open Let_syntax in
     let%map_open () = return ()
     and optional = optional ("optional" |> Symbol.intern) Value.Type.int in
     [%message (optional : int option)]);
  print_funcallN symbol (List.init 1 ~f:Value.Type.(int |> to_value));
  [%expect {| (optional (0)) |}];
  print_funcallN symbol (List.init 0 ~f:Value.Type.(int |> to_value));
  [%expect {| (optional ()) |}]
;;

let%expect_test "[lambda]" =
  let fn =
    lambda
      [%here]
      (Returns Value.Type.int)
      (let open Defun.Let_syntax in
       let%map_open () = return ()
       and i = required ("int" |> Symbol.intern) int in
       i + 1)
  in
  let retval =
    Value.funcall1 (fn |> Function.to_value) (1 |> Value.Type.(int |> to_value))
    |> Value.Type.(int |> of_value_exn)
  in
  print_s [%sexp (retval : int)];
  [%expect {| 2 |}];
  let docstring =
    Symbol.funcall1 ("documentation" |> Symbol.intern) (fn |> Function.to_value)
    |> Value.Type.(string |> of_value_exn)
  in
  if not (String.is_prefix docstring ~prefix:"Implemented at")
  then print_endline docstring;
  [%expect {| |}]
;;

let%expect_test "[defalias]" =
  let f = "f" |> Symbol.intern in
  defalias f [%here] ~alias_of:("+" |> Symbol.intern) ();
  print_endline (Help.describe_function_text f);
  [%expect
    {|
    f is an alias for `+'.

    (f &rest NUMBERS-OR-MARKERS)

    Return sum of any number of arguments, which are numbers or markers. |}]
;;
