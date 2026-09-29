-module(educkui_diff_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

no_change_test() ->
    {ok, Cur} = educkui_buffer:new(2, 2),
    {ok, Prev} = educkui_buffer:new(2, 2),
    ?assertEqual([], educkui_diff:diff(Cur, Prev)),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

text_added_test() ->
    {ok, Cur} = educkui_buffer:new(1, 10),
    {ok, Prev} = educkui_buffer:new(1, 10),
    educkui_buffer:write_string(Cur, 1, 1, <<"Hello">>),
    Ops = educkui_diff:diff(Cur, Prev),
    ExpectedStyle = #dui_style{fg = default, bg = default, attrs = []},
    ?assertEqual([reset, {move, 1, 1}, {style, ExpectedStyle}, {text, <<"Hello">>}], Ops),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

text_removed_test() ->
    {ok, Cur} = educkui_buffer:new(1, 10),
    {ok, Prev} = educkui_buffer:new(1, 10),
    educkui_buffer:write_string(Prev, 1, 1, <<"Hello">>),
    Ops = educkui_diff:diff(Cur, Prev),
    ExpectedStyle = #dui_style{fg = default, bg = default, attrs = []},
    %% The changed cells are now spaces.
    ?assertEqual([reset, {move, 1, 1}, {style, ExpectedStyle}, {text, <<"     ">>}], Ops),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

single_char_change_test() ->
    {ok, Cur} = educkui_buffer:new(1, 10),
    {ok, Prev} = educkui_buffer:new(1, 10),
    educkui_buffer:write_string(Prev, 1, 1, <<"Hello">>),
    educkui_buffer:write_string(Cur, 1, 1, <<"Jello">>),
    Ops = educkui_diff:diff(Cur, Prev),
    ExpectedStyle = #dui_style{fg = default, bg = default, attrs = []},
    ?assertEqual([reset, {move, 1, 1}, {style, ExpectedStyle}, {text, <<"J">>}], Ops),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

style_change_test() ->
    {ok, Cur} = educkui_buffer:new(1, 10),
    {ok, Prev} = educkui_buffer:new(1, 10),
    educkui_buffer:set_cell(Prev, 1, 1, educkui_cell:new(<<"A">>)),
    educkui_buffer:set_cell(Cur, 1, 1, educkui_cell:new(<<"A">>, [{fg, red}])),
    Ops = educkui_diff:diff(Cur, Prev),
    ?assertEqual([reset, {move, 1, 1}, {style, #dui_style{fg = red, bg = default, attrs = []}},
                  {text, <<"A">>}], Ops),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

wide_char_test() ->
    {ok, Cur} = educkui_buffer:new(1, 10),
    {ok, Prev} = educkui_buffer:new(1, 10),
    educkui_buffer:write_string(Cur, 1, 1, <<"日"/utf8>>),
    Ops = educkui_diff:diff(Cur, Prev),
    ?assertEqual([reset, {move, 1, 1},
                  {style, #dui_style{fg = default, bg = default, attrs = []}},
                  {text, <<"日"/utf8>>}], Ops),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).

diff_row_same_test() ->
    {ok, Cur} = educkui_buffer:new(2, 5),
    {ok, Prev} = educkui_buffer:new(2, 5),
    educkui_buffer:write_string(Cur, 2, 1, <<"Hi">>),
    ?assertEqual([reset, {move, 2, 1},
                  {style, #dui_style{fg = default, bg = default, attrs = []}},
                  {text, <<"Hi">>}], educkui_diff:diff_row(Cur, Prev, 2)),
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev).
