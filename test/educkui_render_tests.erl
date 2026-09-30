-module(educkui_render_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

char_at(Cells, X, Y) ->
    case lists:search(
        fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells) of
        {value, {_X, _Y, Cell}} -> Cell#dui_cell.char;
        false -> undefined
    end.

text_truncation_test() ->
    View = educkui_render_node:text(<<"hello">>),
    Cells = educkui_render:render(View, #dui_rect{width = 3, height = 1}),
    ?assertEqual(3, length(Cells)),
    ?assertEqual(<<"h">>, char_at(Cells, 0, 0)),
    ?assertEqual(<<"l">>, char_at(Cells, 2, 0)).

cells_offset_test() ->
    View = educkui_render_node:cells([{0, 0, educkui_cell:new(<<"a">>)}]),
    Cells = educkui_render:render(
        View, #dui_rect{x = 2, y = 3, width = 5, height = 5}),
    ?assertEqual(<<"a">>, char_at(Cells, 2, 3)).

component_state_test() ->
    View = educkui_render_node:component(
        my_input, educkui_widget_text_input, #{value => <<"hi">>}),
    {Cells, Components, Targets, Order} =
        educkui_render:render(View,
                              #dui_rect{width = 10, height = 1},
                              #{}),
    ?assert(maps:is_key(my_input, Components)),
    Comp = maps:get(my_input, Components),
    ?assertEqual(educkui_widget_text_input, Comp#dui_component.module),
    ?assertEqual(<<"hi">>, maps:get(value, Comp#dui_component.state)),
    ?assertEqual([{my_input, #dui_rect{x = 0, y = 0, width = 10, height = 1}}],
                 Targets),
    ?assertEqual([my_input], Order),
    ?assert(length(Cells) > 0).
