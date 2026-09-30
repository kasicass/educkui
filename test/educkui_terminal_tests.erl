-module(educkui_terminal_tests).

-include_lib("eunit/include/eunit.hrl").

start_stop_test() ->
    {ok, Pid} = educkui_terminal:start_link(),
    ?assert(is_process_alive(Pid)),
    ok = gen_server:stop(educkui_terminal),
    ?assertNot(is_process_alive(Pid)).

size_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    {ok, {Rows, Cols}} = educkui_terminal:get_terminal_size(),
    ?assert(Rows > 0),
    ?assert(Cols > 0),
    gen_server:stop(educkui_terminal).

raw_mode_state_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    ?assertNot(educkui_terminal:raw_mode()),
    gen_server:stop(educkui_terminal).

screen_ops_no_crash_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    ok = educkui_terminal:hide_cursor(),
    ok = educkui_terminal:show_cursor(),
    ok = educkui_terminal:enter_alternate_screen(),
    ok = educkui_terminal:leave_alternate_screen(),
    ok = educkui_terminal:enable_mouse_tracking(click),
    ok = educkui_terminal:disable_mouse_tracking(),
    ok = educkui_terminal:copy_to_clipboard(<<"hello">>),
    ok = educkui_terminal:restore(),
    gen_server:stop(educkui_terminal).

activate_raw_no_crash_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    _ = educkui_terminal:activate_raw_mode(),
    _ = educkui_terminal:deactivate_raw_mode(),
    gen_server:stop(educkui_terminal).
