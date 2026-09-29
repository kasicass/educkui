-module(educkui_backend_selector_tests).

-include_lib("eunit/include/eunit.hrl").

select_tty_test() ->
    ?assertEqual({ok, {tty, educkui_backend_tty}},
                 educkui_backend_selector:select(tty)).

select_auto_falls_back_without_tty_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    Result = educkui_backend_selector:select(auto),
    case educkui_capabilities:is_tty() of
        true ->
            ?assertMatch({ok, {raw, _}}, Result);
        false ->
            ?assertEqual({ok, {tty, educkui_backend_tty}}, Result)
    end,
    gen_server:stop(educkui_terminal).

select_raw_returns_error_without_tty_test() ->
    {ok, _Pid} = educkui_terminal:start_link(),
    case educkui_capabilities:is_tty() of
        true ->
            ?assertEqual({ok, {raw, educkui_backend_raw}},
                         educkui_backend_selector:select(raw));
        false ->
            ?assertMatch({error, _}, educkui_backend_selector:select(raw))
    end,
    gen_server:stop(educkui_terminal).
