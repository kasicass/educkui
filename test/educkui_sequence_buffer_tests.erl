-module(educkui_sequence_buffer_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

append_and_flush_test() ->
    B0 = educkui_sequence_buffer:new(),
    {ok, B1} = educkui_sequence_buffer:append(B0, <<"abc">>),
    ?assertEqual(3, educkui_sequence_buffer:size(B1)),
    ?assertNot(educkui_sequence_buffer:is_empty(B1)),
    {Data, B2} = educkui_sequence_buffer:flush(B1),
    ?assertEqual(<<"abc">>, iolist_to_binary(Data)),
    ?assert(educkui_sequence_buffer:is_empty(B2)),
    {Bytes, 1} = educkui_sequence_buffer:stats(B2),
    ?assertEqual(3, Bytes).

auto_flush_on_threshold_test() ->
    B0 = educkui_sequence_buffer:new([{threshold, 4}]),
    {ok, B1} = educkui_sequence_buffer:append(B0, <<"ab">>),
    {flush, Data, B2} = educkui_sequence_buffer:append(B1, <<"cdef">>),
    ?assertEqual(<<"abcdef">>, iolist_to_binary(Data)),
    ?assert(educkui_sequence_buffer:is_empty(B2)).

append_style_delta_test() ->
    S0 = educkui_sequence_buffer:new(),
    Style = #dui_style{fg = red, bg = default, attrs = [bold]},
    {ok, S1} = educkui_sequence_buffer:append_style(S0, Style),
    {Data1, S2} = educkui_sequence_buffer:flush(S1),
    ?assertEqual(<<"\e[31;1m">>, iolist_to_binary(Data1)),
    %% Same style emits nothing.
    {ok, S3} = educkui_sequence_buffer:append_style(S2, Style),
    {Data2, S4} = educkui_sequence_buffer:flush(S3),
    ?assertEqual(<<>>, iolist_to_binary(Data2)),
    %% Only fg changed: emit fg param.
    Style2 = #dui_style{fg = blue, bg = default, attrs = [bold]},
    {ok, S5} = educkui_sequence_buffer:append_style(S4, Style2),
    {Data3, _S6} = educkui_sequence_buffer:flush(S5),
    ?assertEqual(<<"\e[34m">>, iolist_to_binary(Data3)).

reset_and_clear_test() ->
    S0 = educkui_sequence_buffer:new(),
    {ok, S1} = educkui_sequence_buffer:append(S0, <<"abc">>),
    S2 = educkui_sequence_buffer:clear(S1),
    ?assert(educkui_sequence_buffer:is_empty(S2)),
    S3 = educkui_sequence_buffer:reset_style(S2),
    ?assertEqual(undefined, S3#dui_seqbuf.last_style).

to_iodata_test() ->
    S0 = educkui_sequence_buffer:new(),
    {ok, S1} = educkui_sequence_buffer:append(S0, [<<"a">>, <<"b">>]),
    ?assertEqual(<<"ab">>, iolist_to_binary(educkui_sequence_buffer:to_iodata(S1))).
