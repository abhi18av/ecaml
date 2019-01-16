open! Core_kernel
open! Import

module Q = struct
  let describe_function = "describe-function" |> Symbol.intern
  let describe_variable = "describe-variable" |> Symbol.intern
  let describe_minor_mode = "describe-minor-mode" |> Symbol.intern
end

module F = struct
  open! Funcall
  open! Value.Type

  let describe_function = Q.describe_function <: Symbol.type_ @-> return nil
  let describe_variable = Q.describe_variable <: Symbol.type_ @-> return nil
  let describe_minor_mode = Q.describe_minor_mode <: Symbol.type_ @-> return nil
end

let get_text_of_help ~invoke_help =
  Echo_area.inhibit_messages invoke_help;
  Buffer.find ~name:"*Help*"
  |> Option.value_exn
  |> Current_buffer.set_temporarily ~f:(fun () ->
    Current_buffer.contents ()
    |> Text.to_utf8_bytes
    |> String.split_lines
    |> List.filter_map ~f:(fun line ->
      if (am_running_inline_test
          && String.is_prefix line ~prefix:"Implemented at")
      || String.( = ) "[back]" (String.strip line)
      then None
      else Some line)
    |> concat ~sep:"\n"
    |> String.strip)
;;

let function_ ?(obscure_symbol = false) symbol =
  let s = get_text_of_help ~invoke_help:(fun () -> F.describe_function symbol) in
  if obscure_symbol
  then
    String.Search_pattern.replace_all
      (String.Search_pattern.create (Symbol.name symbol))
      ~in_:s
      ~with_:"<SYMBOL>"
  else s
;;

let variable symbol = get_text_of_help ~invoke_help:(fun () -> F.describe_variable symbol)
let display_minor_mode symbol = F.describe_minor_mode symbol

let minor_mode symbol =
  get_text_of_help ~invoke_help:(fun () -> display_minor_mode symbol)
;;
