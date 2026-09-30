%% @doc Property-style tests for educkui_diff.
%%
%% Randomized checks with a fixed seed (no external PropEr dependency).
%% Verifies self-diff is empty (idempotence) and that diff output always has
%% the expected operation shapes.
-module(educkui_diff_prop_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

diff_self_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> diff_self_case() end,
        lists:seq(1, 100)).

diff_self_case() ->
    Rows = educkui_prop_utils:rand_int(1, 20),
    Cols = educkui_prop_utils:rand_int(1, 30),
    Buf = random_buffer(Rows, Cols),
    try
        ?assertEqual([], educkui_diff:diff(Buf, Buf)),
        lists:foreach(
            fun(Row) -> ?assertEqual([], educkui_diff:diff_row(Buf, Buf, Row)) end,
            lists:seq(1, Rows))
    after
        educkui_buffer:destroy(Buf)
    end.

diff_shape_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> diff_shape_case() end,
        lists:seq(1, 100)).

diff_shape_case() ->
    Rows = educkui_prop_utils:rand_int(1, 20),
    Cols = educkui_prop_utils:rand_int(1, 30),
    A = random_buffer(Rows, Cols),
    B = random_buffer(Rows, Cols),
    try
        Ops = educkui_diff:diff(A, B),
        ?assert(is_list(Ops)),
        lists:foreach(fun(Op) -> ?assert(valid_op(Op)) end, Ops)
    after
        educkui_buffer:destroy(A),
        educkui_buffer:destroy(B)
    end.

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec random_buffer(pos_integer(), pos_integer()) -> #dui_buffer{}.
random_buffer(Rows, Cols) ->
    {ok, Buf} = educkui_buffer:new(Rows, Cols),
    Cells = [{Row, Col, random_cell()}
             || Row <- lists:seq(1, Rows), Col <- lists:seq(1, Cols)],
    ok = educkui_buffer:set_cells(Buf, Cells),
    Buf.

-spec random_cell() -> #dui_cell{}.
random_cell() ->
    Chars = [<<"a">>, <<"b">>, <<" ">>, <<"你">>, <<"x">>],
    Colors = [default, red, green, blue, 5, {10, 20, 30}],
    AttrsPool = [[], [bold], [reverse], [bold, underline]],
    educkui_cell:new(educkui_prop_utils:rand_choice(Chars),
                     [{fg, educkui_prop_utils:rand_choice(Colors)},
                      {bg, educkui_prop_utils:rand_choice(Colors)},
                      {attrs, educkui_prop_utils:rand_choice(AttrsPool)}]).

-spec valid_op(term()) -> boolean().
valid_op({move, Row, Col}) ->
    is_integer(Row) andalso Row >= 1 andalso is_integer(Col) andalso Col >= 1;
valid_op({style, Style}) ->
    is_record(Style, dui_style);
valid_op({text, Text}) ->
    is_binary(Text);
valid_op(reset) ->
    true;
valid_op(_) ->
    false.
