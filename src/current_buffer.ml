open! Core_kernel
open! Import

module Q = struct
  include Q

  let add_text_properties = "add-text-properties" |> Symbol.intern
  and put_text_property = "put-text-property" |> Symbol.intern
  and replace_buffer_contents = "replace-buffer-contents" |> Symbol.intern
  and set_text_properties = "set-text-properties" |> Symbol.intern
end

include Current_buffer0

module Window_display_state = struct
  include Value.Make_subtype (struct
      let here = [%here]
      let name = "Buffer.window-display-state"

      let is_in_subtype =
        let open Value in
        is_cons
          ~car:Position.is_in_subtype
          ~cdr:(is_cons ~car:Position.is_in_subtype ~cdr:Position.is_in_subtype)
      ;;
    end)

  let get = Funcall.("Buffer.window-display-state" <: nullary @-> return t)
  let restore = Funcall.("Buffer.restore-window-display-state" <: t @-> return nil)

  let save f =
    let t = get () in
    Exn.protect ~f ~finally:(fun () -> restore t)
  ;;
end

let get_buffer_local = Buffer_local.Private.get_in_current_buffer
let get_buffer_local_exn = Buffer_local.Private.get_in_current_buffer_exn
let set_buffer_local = Buffer_local.Private.set_in_current_buffer

let set_temporarily_to_temp_buffer sync_or_async f =
  let t = Buffer.create ~name:"*temp-buffer*" in
  Sync_or_async.protect
    [%here]
    sync_or_async
    ~f:(fun () -> set_temporarily sync_or_async t ~f)
    ~finally:(fun () -> Buffer.Blocking.kill t)
;;

let major_mode () =
  Major_mode.find_or_wrap_existing [%here] (get_buffer_local Major_mode.major_mode_var)
;;

let set_auto_mode = Funcall.("set-auto-mode" <: nil_or bool @-> return nil)
let set_auto_mode ?keep_mode_if_same () = set_auto_mode keep_mode_if_same
let bury = Funcall.("bury-buffer" <: nullary @-> return nil)
let directory = Buffer_local.Wrap.("default-directory" <: string)
let describe_mode = Funcall.("describe-mode" <: nullary @-> return nil)
let is_modified = Funcall.("buffer-modified-p" <: nullary @-> return bool)
let set_modified = Funcall.("set-buffer-modified-p" <: bool @-> return nil)
let fill_column = Buffer_local.Wrap.("fill-column" <: int)
let paragraph_start = Var.Wrap.("paragraph-start" <: Regexp.t)
let paragraph_separate = Var.Wrap.("paragraph-separate" <: Regexp.t)
let read_only = Buffer_local.Wrap.("buffer-read-only" <: bool)
let file_name () = Buffer.file_name (get ())

let file_name_exn () =
  match file_name () with
  | Some x -> x
  | None -> raise_s [%message "buffer does not have a file name" ~_:(get () : Buffer.t)]
;;

let name () =
  match Buffer.name (get ()) with
  | Some x -> x
  | None -> raise_s [%message "current buffer has nil buffer-name"]
;;

let file_name_var = Buffer_local.Wrap.("buffer-file-name" <: nil_or string)

module Coding_system = struct
  module T = struct
    type t =
      | Utf_8
      | Utf_8_unix
    [@@deriving enumerate, sexp]
  end

  include T

  let type_ =
    Value.Type.enum
      [%sexp "buffer-file-coding-system"]
      (module T)
      (function
        | Utf_8 -> "utf-8" |> Value.intern
        | Utf_8_unix -> "utf-8-unix" |> Value.intern)
  ;;

  let t = type_
end

let file_coding_system =
  Buffer_local.Wrap.("buffer-file-coding-system" <: nil_or Coding_system.t)
;;

let transient_mark_mode = Var.Wrap.("transient-mark-mode" <: bool)
let buffer_undo_list = Buffer_local.Wrap.("buffer-undo-list" <: value)
let is_undo_enabled () = not (Value.eq (get_buffer_local buffer_undo_list) Value.t)
let buffer_disable_undo = Funcall.("buffer-disable-undo" <: nullary @-> return nil)
let buffer_enable_undo = Funcall.("buffer-enable-undo" <: nullary @-> return nil)

let set_undo_enabled bool =
  if bool then buffer_enable_undo () else buffer_disable_undo ()
;;

let undo_list () = get_buffer_local buffer_undo_list
let undo = Funcall.("undo" <: int @-> return nil)
let add_undo_boundary = Funcall.("undo-boundary" <: nullary @-> return nil)

let or_point_max option =
  match option with
  | Some x -> x
  | None -> Point.max ()
;;

let or_point_min option =
  match option with
  | Some x -> x
  | None -> Point.min ()
;;

let buffer_substring =
  Funcall.("buffer-substring" <: Position.t @-> Position.t @-> return Text.t)
;;

let buffer_substring_no_properties =
  Funcall.(
    "buffer-substring-no-properties" <: Position.t @-> Position.t @-> return Text.t)
;;

let contents ?start ?end_ ?(text_properties = false) () =
  (if text_properties then buffer_substring else buffer_substring_no_properties)
    (or_point_min start)
    (or_point_max end_)
;;

let kill_buffer = Funcall.("kill-buffer" <: nullary @-> return nil)

let kill () =
  Value.Private.run_outside_async [%here] ~allowed_in_background:true kill_buffer
;;

let save_buffer = Funcall.("save-buffer" <: nullary @-> return nil)

let save () =
  Value.Private.run_outside_async [%here] ~allowed_in_background:true save_buffer
;;

let erase = Funcall.("erase-buffer" <: nullary @-> return nil)
let delete_region = Funcall.("delete-region" <: Position.t @-> Position.t @-> return nil)
let delete_region ~start ~end_ = delete_region start end_
let kill_region = Funcall.("kill-region" <: Position.t @-> Position.t @-> return nil)
let kill_region ~start ~end_ = kill_region start end_
let widen = Funcall.("widen" <: nullary @-> return nil)
let save_current_buffer f = Save_wrappers.save_current_buffer f
let save_excursion f = Save_wrappers.save_excursion f
let save_mark_and_excursion f = Save_wrappers.save_mark_and_excursion f
let save_restriction f = Save_wrappers.save_restriction f
let save_window_display_state = Window_display_state.save
let set_multibyte = Funcall.("set-buffer-multibyte" <: bool @-> return nil)

let enable_multibyte_characters =
  Buffer_local.Wrap.("enable-multibyte-characters" <: bool)
;;

let is_multibyte () = get_buffer_local enable_multibyte_characters
let rename_buffer = Funcall.("rename-buffer" <: string @-> bool @-> return nil)
let rename_exn ?(unique = false) () ~name = rename_buffer name unique

let put_text_property =
  Funcall.(
    "put-text-property"
    <: Position.t @-> Position.t @-> Symbol.t @-> value @-> return nil)
;;

let set_text_property ?start ?end_ property_name property_value =
  put_text_property
    (or_point_min start)
    (or_point_max end_)
    (property_name |> Text.Property_name.name)
    (property_value |> Text.Property_name.to_value property_name)
;;

(* The [*_staged] functions are special-cased for performance. *)

let set_text_property_staged property_name property_value =
  let property_value = property_value |> Text.Property_name.to_value property_name in
  let property_name = property_name |> Text.Property_name.name_as_value in
  stage (fun ~start ~end_ ->
    Symbol.funcall_int_int_value_value_unit
      Q.put_text_property
      start
      end_
      property_name
      property_value)
;;

let set_text_properties =
  Funcall.(
    "set-text-properties" <: Position.t @-> Position.t @-> list value @-> return nil)
;;

let set_text_properties ?start ?end_ properties =
  set_text_properties
    (or_point_min start)
    (or_point_max end_)
    (properties |> Text.Property.to_property_list)
;;

let set_text_properties_staged properties =
  let properties = properties |> Text.Property.to_property_list |> Value.list in
  stage (fun ~start ~end_ ->
    Symbol.funcall_int_int_value_unit Q.set_text_properties start end_ properties)
;;

let get_text_property =
  Funcall.("get-text-property" <: Position.t @-> value @-> return (nil_or value))
;;

let get_text_property at property_name =
  get_text_property at (property_name |> Text.Property_name.name_as_value)
  |> Option.map ~f:(Text.Property_name.of_value_exn property_name)
;;

let add_text_properties =
  Funcall.(
    "add-text-properties" <: Position.t @-> Position.t @-> list value @-> return nil)
;;

let add_text_properties ?start ?end_ properties =
  add_text_properties
    (or_point_min start)
    (or_point_max end_)
    (properties |> Text.Property.to_property_list)
;;

let add_text_properties_staged properties =
  let properties = properties |> Text.Property.to_property_list |> Value.list in
  stage (fun ~start ~end_ ->
    Symbol.funcall_int_int_value_unit Q.add_text_properties start end_ properties)
;;

let text_property_not_all =
  Funcall.(
    "text-property-not-all"
    <: Position.t @-> Position.t @-> Symbol.t @-> value @-> return value)
;;

let text_property_is_present ?start ?end_ property_name =
  Value.is_not_nil
    (text_property_not_all
       (or_point_min start)
       (or_point_max end_)
       (property_name |> Text.Property_name.name)
       Value.nil)
;;

let set_marker_position =
  Funcall.("set-marker" <: Marker.t @-> Position.t @-> return nil)
;;

let mark = Funcall.("mark-marker" <: nullary @-> return Marker.t)
let set_mark = Funcall.("set-mark" <: Position.t @-> return nil)
let mark_active = Buffer_local.Wrap.("mark-active" <: bool)
let mark_is_active () = get_buffer_local mark_active
let deactivate_mark = Funcall.("deactivate-mark" <: nullary @-> return nil)
let region_beginning = Funcall.("region-beginning" <: nullary @-> return Position.t)
let region_end = Funcall.("region-end" <: nullary @-> return Position.t)

let active_region () =
  if mark_is_active () then Some (region_beginning (), region_end ()) else None
;;

let make_local_variable = Funcall.("make-local-variable" <: Symbol.t @-> return nil)

let make_buffer_local var =
  add_gc_root (var |> Var.symbol_as_value);
  make_local_variable (var |> Var.symbol)
;;

let local_variable_p = Funcall.("local-variable-p" <: Symbol.t @-> return bool)
let is_buffer_local var = local_variable_p (var |> Var.symbol)

let local_variable_if_set_p =
  Funcall.("local-variable-if-set-p" <: Symbol.t @-> return bool)
;;

let is_buffer_local_if_set var = local_variable_if_set_p (var |> Var.symbol)

let buffer_local_variables =
  Funcall.("buffer-local-variables" <: nullary @-> return (list value))
;;

let buffer_local_variables () =
  buffer_local_variables ()
  |> List.map ~f:(fun value ->
    if Value.is_symbol value
    then value |> Symbol.of_value_exn, None
    else Value.car_exn value |> Symbol.of_value_exn, Some (Value.cdr_exn value))
;;

let kill_local_variable = Funcall.("kill-local-variable" <: Symbol.t @-> return nil)
let kill_buffer_local var = kill_local_variable (var |> Var.symbol)
let char_syntax = Funcall.("char-syntax" <: Char_code.t @-> return Char_code.t)
let syntax_class char_code = char_syntax char_code |> Syntax_table.Class.of_char_code_exn
let syntax_table = Funcall.("syntax-table" <: nullary @-> return Syntax_table.t)
let set_syntax_table = Funcall.("set-syntax-table" <: Syntax_table.t @-> return nil)
let local_keymap = Funcall.("current-local-map" <: nullary @-> return (nil_or Keymap.t))
let set_local_keymap = Funcall.("use-local-map" <: Keymap.t @-> return nil)

let minor_mode_keymaps =
  Funcall.("current-minor-mode-maps" <: nullary @-> return (list Keymap.t))
;;

let flush_lines =
  Funcall.("flush-lines" <: Regexp.t @-> Position.t @-> Position.t @-> return nil)
;;

let delete_lines_matching ?start ?end_ regexp =
  flush_lines regexp (or_point_min start) (or_point_max end_)
;;

let sort_lines =
  Funcall.("sort-lines" <: value @-> Position.t @-> Position.t @-> return nil)
;;

let sort_lines ?start ?end_ () =
  sort_lines Value.nil (or_point_min start) (or_point_max end_)
;;

let delete_duplicate_lines =
  Funcall.("delete-duplicate-lines" <: Position.t @-> Position.t @-> return nil)
;;

let delete_duplicate_lines ?start ?end_ () =
  delete_duplicate_lines (or_point_min start) (or_point_max end_)
;;

let indent_region = Funcall.("indent-region" <: Position.t @-> Position.t @-> return nil)

let indent_region ?start ?end_ () =
  Echo_area.inhibit_messages Sync (fun () ->
    indent_region (or_point_min start) (or_point_max end_))
;;

module Blocking = struct
  let change_major_mode = Major_mode.Blocking.change_in_current_buffer
  let save = save_buffer
end

let change_major_mode major_mode = Major_mode.change_to major_mode ~in_:(get ())
let revert ?confirm () = Buffer.revert ?confirm (get ())

let revert_buffer_function =
  Buffer_local.Wrap.(
    let ( <: ) = ( <: ) ~make_buffer_local_always:true in
    "revert-buffer-function" <: Function.t)
;;

let set_revert_buffer_function here returns f =
  set_buffer_local
    revert_buffer_function
    (Defun.lambda
       here
       returns
       (let%map_open.Defun () = return ()
        and () = required "ignore-auto" ignored
        and noconfirm = required "noconfirm" bool in
        f ~confirm:(not noconfirm)))
;;

let replace_buffer_contents =
  if not (Symbol.function_is_defined Q.replace_buffer_contents)
  then
    Or_error.error_s
      [%message "function not defined" ~symbol:(Q.replace_buffer_contents : Symbol.t)]
  else Ok Funcall.("replace-buffer-contents" <: Buffer.t @-> return nil)
;;

let size = Funcall.("buffer-size" <: nullary @-> return int)
let truncate_lines = Buffer_local.Wrap.("truncate-lines" <: bool)

let chars_modified_tick =
  Funcall.("buffer-chars-modified-tick" <: nullary @-> return Modified_tick.t)
;;

let append_to string =
  let point_max_before = Point.max () in
  save_excursion Sync (fun () ->
    Point.goto_max ();
    Point.insert string);
  let point_max_after = Point.max () in
  if Position.equal (Point.get ()) point_max_before then Point.goto_max ();
  List.iter
    (Buffer.displayed_in (get ()))
    ~f:(fun window ->
      if Position.equal (Window.point_exn window) point_max_before
      then Window.set_point_exn window point_max_after)
;;

let inhibit_read_only = Var.Wrap.("inhibit-read-only" <: bool)

let inhibit_read_only sync_or_async f =
  set_value_temporarily sync_or_async inhibit_read_only true ~f
;;

let position_of_line_and_column line_and_column =
  save_excursion Sync (fun () ->
    Point.goto_line_and_column line_and_column;
    Point.get ())
;;

let line_and_column_of_position position =
  save_excursion Sync (fun () ->
    Point.goto_char position;
    Point.get_line_and_column ())
;;
