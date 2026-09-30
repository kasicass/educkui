%% @doc Property-style tests for educkui_buffer.
%%
%% Randomized checks with a fixed seed (no external PropEr dependency).
-module(educkui_buffer_prop_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

new_dimensions_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> new_dimensions_case() end,
        lists:seq(1, 100)).

new_dimensions_case() ->
    Rows = educkui_prop_utils:rand_int(1, 20),
    Cols = educkui_prop_utils:rand_int(1, 30),
    {ok, Buf} = educkui_buffer:new(Rows, Cols),
    try
        ?assertEqual({Rows, Cols}, educkui_buffer:dimensions(Buf))
    after
        educkui_buffer:destroy(Buf)
    end.

set_get_roundtrip_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> set_get_roundtrip_case() end,
        lists:seq(1, 100)).

set_get_roundtrip_case() ->
    Rows = educkui_prop_utils:rand_int(1, 20),
    Cols = educkui_prop_utils:rand_int(1, 30),
    {ok, Buf} = educkui_buffer:new(Rows, Cols),
    try
        Row = educkui_prop_utils:rand_int(1, Rows),
        Col = educkui_prop_utils:rand_int(1, Cols),
        Cell = random_cell(),
        ok = educkui_buffer:set_cell(Buf, Row, Col, Cell),
        ?assert(educkui_cell:equal(Cell, educkui_buffer:get_cell(Buf, Row, Col))),
        %% Out-of-bounds reads return an empty cell.
        ?assert(educkui_cell:equal(educkui_cell:empty(),
                                   educkui_buffer:get_cell(Buf, 0, 0)))
    after
        educkui_buffer:destroy(Buf)
    end.

get_row_length_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> get_row_length_case() end,
        lists:seq(1, 100)).

get_row_length_case() ->
    Rows = educkui_prop_utils:rand_int(1, 20),
    Cols = educkui_prop_utils:rand_int(1, 30),
    {ok, Buf} = educkui_buffer:new(Rows, Cols),
    try
        Row = educkui_prop_utils:rand_int(1, Rows),
        ?assertEqual(Cols, length(educkui_buffer:get_row(Buf, Row)))
    after
        educkui_buffer:destroy(Buf)
    end.

clear_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) -> clear_case() end,
        lists:seq(1, 50)).

clear_case() ->
    Rows = educkui_prop_utils:rand_int(1, 10),
    Cols = educkui_prop_utils:rand_int(1, 15),
    {ok, Buf} = educkui_buffer:new(Rows, Cols),
    try
        ok = educkui_buffer:set_cells(Buf, [{Row, Col, random_cell()}
                                            || Row <- lists:seq(1, Rows),
                                               Col <- lists:seq(1, Cols)]),
        ok = educkui_buffer:clear(Buf),
        lists:foreach(
            fun(Row) ->
                lists:foreach(
                    fun(Col) ->
                        ?assert(educkui_cell:equal(
                            educkui_cell:empty(),
                            educkui_buffer:get_cell(Buf, Row, Col)))
                    end,
                    lists:seq(1, Cols))
            end,
            lists:seq(1, Rows))
    after
        educkui_buffer:destroy(Buf)
    end.

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec random_cell() -> #dui_cell{}.
random_cell() ->
    Chars = [<<"a">>, <<"b">>, <<" ">>, <<"你">>, <<"x">>],
    Colors = [default, red, green, blue, 5, {10, 20, 30}],
    AttrsPool = [[], [bold], [reverse], [bold, underline]],
    educkui_cell:new(educkui_prop_utils:rand_choice(Chars),
                     [{fg, educkui_prop_utils:rand_choice(Colors)},
                      {bg, educkui_prop_utils:rand_choice(Colors)},
                      {attrs, educkui_prop_utils:rand_choice(AttrsPool)}]).
