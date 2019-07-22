open! Core_kernel
open! Async_kernel
open! Import

let other_window = Funcall.("other-window" <: int @-> return nil)
let height = Funcall.("window-height" <: nullary @-> return int)
let width = Funcall.("window-width" <: nullary @-> return int)
let get = Funcall.("selected-window" <: nullary @-> return Window.t)
let select_window = Funcall.("select-window" <: Window.t @-> bool @-> return nil)

let set ?(move_to_front_of_buffer_list = true) window =
  select_window window (not move_to_front_of_buffer_list)
;;

let switch_to_buffer = Funcall.("switch-to-buffer" <: Buffer.t @-> return nil)

let switch_to_buffer_other_window =
  Funcall.("switch-to-buffer-other-window" <: Buffer.t @-> return nil)
;;

let split_horizontally_exn =
  Funcall.("split-window-horizontally" <: nullary @-> return nil)
;;

let split_sensibly_exn = Funcall.("split-window-sensibly" <: nullary @-> return nil)
let split_vertically_exn = Funcall.("split-window-vertically" <: nullary @-> return nil)
let find_file_other_window = Funcall.("find-file-other-window" <: string @-> return nil)
let quit = Funcall.("quit-window" <: nullary @-> return nil)

let save_window_excursion sync_or_async f =
  Save_wrappers.save_window_excursion sync_or_async f
;;

let save_selected_window f = Save_wrappers.save_selected_window f

let set_temporarily sync_or_async window ~f =
  Save_wrappers.with_selected_window sync_or_async (window |> Window.to_value) f
;;

module Blocking = struct
  let find_file = Funcall.("find-file" <: string @-> return nil)
  let view_file = Funcall.("view-file" <: string @-> return nil)
end

let find_file path =
  Value.Private.run_outside_async [%here] (fun () -> Blocking.find_file path)
;;

let view_file path =
  Value.Private.run_outside_async [%here] (fun () -> Blocking.view_file path)
;;
