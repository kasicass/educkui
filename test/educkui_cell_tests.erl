-module(educkui_cell_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

new_test() ->
    Cell = educkui_cell:new(<<"A">>),
    ?assertEqual(<<"A">>, Cell#dui_cell.char),
    ?assertEqual(default, Cell#dui_cell.fg),
    ?assertEqual(default, Cell#dui_cell.bg),
    ?assertEqual([], Cell#dui_cell.attrs),
    ?assertEqual(1, Cell#dui_cell.width).

new_with_opts_test() ->
    Cell = educkui_cell:new(<<"X">>, [{fg, red}, {attrs, [bold, underline]}]),
    ?assertEqual(red, Cell#dui_cell.fg),
    ?assertEqual([bold, underline], Cell#dui_cell.attrs).

empty_cell_test() ->
    Cell = educkui_cell:empty(),
    ?assert(educkui_cell:empty(Cell)),
    ?assertEqual(<<" ">>, Cell#dui_cell.char),
    ?assertEqual(1, Cell#dui_cell.width),
    ?assertNot(Cell#dui_cell.placeholder).

wide_char_test() ->
    Wide = educkui_cell:new(<<"日"/utf8>>),
    ?assert(educkui_cell:wide(Wide)),
    ?assertEqual(2, educkui_cell:width(Wide)),
    Narrow = educkui_cell:new(<<"A">>),
    ?assertNot(educkui_cell:wide(Narrow)).

placeholder_test() ->
    Primary = educkui_cell:new(<<"日"/utf8>>, [{fg, red}]),
    Placeholder = educkui_cell:wide_placeholder(Primary),
    ?assert(educkui_cell:is_wide_placeholder(Placeholder)),
    ?assertEqual(<<>>, Placeholder#dui_cell.char),
    ?assertEqual(red, Placeholder#dui_cell.fg),
    ?assertEqual(0, Placeholder#dui_cell.width).

sanitize_control_chars_test() ->
    ?assertEqual(<<" ">>, (educkui_cell:new(<<"\n">>))#dui_cell.char),
    ?assertEqual(<<" ">>, (educkui_cell:new(<<"\t">>))#dui_cell.char),
    ?assertEqual(<<"A">>, (educkui_cell:new(<<"A">>))#dui_cell.char).

sanitize_escape_sequences_test() ->
    ?assertEqual(<<" ">>, (educkui_cell:new(<<"\e[31m">>))#dui_cell.char),
    ?assertEqual(<<" ">>, (educkui_cell:new(<<"\e]0;title\a">>))#dui_cell.char),
    %% Escape sequence embedded in text is stripped, text preserved.
    ?assertEqual(<<"AB">>, (educkui_cell:new(<<"A\e[1mB">>))#dui_cell.char).

updates_test() ->
    C0 = educkui_cell:new(<<"A">>, [{fg, red}]),
    C1 = educkui_cell:put_char(C0, <<"B">>),
    ?assertEqual(<<"B">>, C1#dui_cell.char),
    ?assertEqual(red, C1#dui_cell.fg),
    C2 = educkui_cell:put_fg(C1, blue),
    ?assertEqual(blue, C2#dui_cell.fg),
    C3 = educkui_cell:put_bg(C2, green),
    ?assertEqual(green, C3#dui_cell.bg),
    C4 = educkui_cell:add_attr(C3, bold),
    ?assert(educkui_cell:has_attr(C4, bold)),
    C5 = educkui_cell:remove_attr(C4, bold),
    ?assertNot(educkui_cell:has_attr(C5, bold)).

equal_test() ->
    A = educkui_cell:new(<<"A">>, [{fg, red}, {attrs, [bold]}]),
    B = educkui_cell:new(<<"A">>, [{attrs, [bold]}, {fg, red}]),
    C = educkui_cell:new(<<"B">>, [{fg, red}, {attrs, [bold]}]),
    ?assert(educkui_cell:equal(A, B)),
    ?assertNot(educkui_cell:equal(A, C)).

invalid_color_test() ->
    ?assertError({invalid_color, _}, educkui_cell:new(<<"A">>, [{fg, not_a_color}])),
    ?assertError({invalid_color, _}, educkui_cell:new(<<"A">>, [{fg, 300}])),
    ?assertError({invalid_color, _}, educkui_cell:new(<<"A">>, [{fg, {1, 2}}])).

invalid_attr_test() ->
    ?assertError({invalid_attribute, _}, educkui_cell:new(<<"A">>, [{attrs, [bogus]}])).

rgb_color_test() ->
    Cell = educkui_cell:new(<<"A">>, [{fg, {255, 0, 128}}]),
    ?assertEqual({255, 0, 128}, Cell#dui_cell.fg).

introspection_test() ->
    ?assertEqual(16, length(educkui_cell:named_colors())),
    ?assertEqual(8, length(educkui_cell:valid_attributes())).
