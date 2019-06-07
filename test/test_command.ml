open! Core_kernel
open! Import
open! Command

let is_command value = print_s [%sexp (Value.is_command value : bool)]

let%expect_test "[Raw_prefix_argument]" =
  let f = Symbol.gensym () in
  defun
    f
    [%here]
    ~interactive:Raw_prefix
    (Returns Value.Type.unit)
    (let open Defun.Let_syntax in
     let%map_open arg = required ("arg" |> Symbol.intern) value in
     print_s
       [%message
         ""
           (arg : Value.t)
           ~for_current_command:
             ( Current_buffer.value_exn Raw_prefix_argument.for_current_command
               : Raw_prefix_argument.t )
           ~raw_prefix_argument:
             (arg |> Raw_prefix_argument.of_value_exn : Raw_prefix_argument.t)]);
  is_command (f |> Symbol.to_value);
  [%expect {|
    true |}];
  List.iter
    [ Value.nil
    ; 3 |> Value.of_int_exn
    ; Value.list [ 4 |> Value.of_int_exn ]
    ; "-" |> Value.intern
    ]
    ~f:(fun prefix_arg ->
      print_s [%message (prefix_arg : Value.t)];
      Command.call_interactively
        (f |> Symbol.to_value)
        ~raw_prefix_argument:(prefix_arg |> Raw_prefix_argument.of_value_exn));
  [%expect
    {|
    (prefix_arg nil)
    ((arg                 nil)
     (for_current_command Absent)
     (raw_prefix_argument Absent))
    (prefix_arg 3)
    ((arg 3)
     (for_current_command (Int 3))
     (raw_prefix_argument (Int 3)))
    (prefix_arg (4))
    ((arg (4))
     (for_current_command (Nested 4))
     (raw_prefix_argument (Nested 4)))
    (prefix_arg -)
    ((arg                 -)
     (for_current_command Minus)
     (raw_prefix_argument Minus)) |}]
;;

let%expect_test "[call_interactively ~record:true]" =
  let f1 = "test-f1" |> Symbol.intern in
  defun_nullary_nil f1 [%here] ~interactive:No_arg Fn.ignore;
  let f2 = "test-f2" |> Symbol.intern in
  defun_nullary_nil f2 [%here] ~interactive:No_arg Fn.ignore;
  let most_recent_command () =
    print_s [%sexp (List.hd_exn (Command.history ()) : Form.t)]
  in
  call_interactively (f1 |> Symbol.to_value) ~record:true;
  most_recent_command ();
  [%expect {| (test-f1) |}];
  call_interactively (f2 |> Symbol.to_value) ~record:false;
  most_recent_command ();
  [%expect {| (test-f1) |}];
  call_interactively (f2 |> Symbol.to_value) ~record:true;
  most_recent_command ();
  [%expect {| (test-f2) |}]
;;

let give_emacs_chance_to_signal () = ignore (Text.of_utf8_bytes "ignoreme")

let%expect_test "quit" =
  show_raise (fun () ->
    Command.request_quit ();
    give_emacs_chance_to_signal ());
  [%expect {| (raised quit) |}]
;;

let%expect_test "inhibit-quit" =
  show_raise (fun () ->
    Current_buffer.set_value_temporarily inhibit_quit true Sync ~f:(fun () ->
      Command.request_quit ();
      give_emacs_chance_to_signal ()));
  [%expect {| "did not raise" |}];
  show_raise (fun () -> give_emacs_chance_to_signal ());
  [%expect {| (raised quit) |}]
;;
