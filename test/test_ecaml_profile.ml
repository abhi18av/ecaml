open! Core_kernel
open! Import
open! Nested_profile

let sec = Time_ns.Span.of_sec

module Set = struct
  type t = T : ('a ref * 'a) -> t

  let save_current ts = List.map ts ~f:(fun (T (r, _)) -> T (r, !r))
  let sets ts = List.iter ts ~f:(fun (T (r, a)) -> r := a)

  let set_temporarily ts ~f =
    let saved = save_current ts in
    sets ts;
    protect ~f ~finally:(fun () -> sets saved)
  ;;
end

let%expect_test _ =
  let module Clock = Profile.Private.Clock in
  let clock = Clock.create ~now:Time_ns.epoch in
  Set.set_temporarily
    [ T (Profile.should_profile, true)
    ; T (Profile.hide_top_level_if_less_than, Time_ns.Span.zero)
    ; T (Profile.hide_if_less_than, Time_ns.Span.zero)
    ; T (Profile.output_profile, fun string -> message string)
    ; T (Profile.Private.clock, clock)
    ]
    ~f:(fun () ->
      profile
        Sync
        (lazy [%sexp "nest"])
        (fun () ->
           Clock.advance clock ~by:(sec 0.1);
           Elisp_gc.garbage_collect ();
           Clock.advance clock ~by:(sec 0.2);
           Elisp_gc.garbage_collect ();
           Clock.advance clock ~by:(sec 0.3)));
  [%expect
    {|
    (620_000us nest (19:00:00.000000000-05:00 1969-12-31) (
       ( 16% 100_000us gap)
       (  2%  10_000us (garbage-collect) (
          (  0%       0us (boundp gc-elapsed))
          (  0%       0us (symbol-value gc-elapsed))
          (100%  10_000us (gc (gcs_done _)))))
       ( 32% 200_000us gap)
       (  2%  10_000us (garbage-collect) (
          (  0%       0us (boundp gc-elapsed))
          (  0%       0us (symbol-value gc-elapsed))
          (100%  10_000us (gc (gcs_done _)))))
       ( 48% 300_000us gap))) |}]
;;
