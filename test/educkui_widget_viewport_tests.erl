-module(educkui_widget_viewport_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

content() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"row0">>),
        educkui_render_node:text(<<"row1">>),
        educkui_render_node:text(<<"row2">>)
    ]).

char_at(Cells, X, Y) ->
    case lists:search(fun({Cx, Cy, _}) -> Cx =:= X andalso Cy =:= Y end, Cells) of
        {value, {_X, _Y, Cell}} -> {ok, Cell#dui_cell.char};
        false -> missing
    end.

no_scroll_test() ->
    Node = educkui_widget_viewport:render(#{content => content()},
        #dui_rect{width = 10, height = 3}),
    Cells = Node#dui_node.cells,
    ?assertEqual({ok, <<"r">>}, char_at(Cells, 0, 0)),
    ?assertEqual({ok, <<"r">>}, char_at(Cells, 0, 2)).

scrolled_test() ->
    Node = educkui_widget_viewport:render(#{content => content(), scroll_y => 1},
        #dui_rect{width = 10, height = 3}),
    Cells = Node#dui_node.cells,
    %% After scrolling by 1, "row0" is shifted out of view (y=-1) and
    %% "row1" is now at y=0.
    ?assertEqual({ok, <<"r">>}, char_at(Cells, 0, 0)),
    ?assertEqual(missing, char_at(Cells, 0, 3)).

clips_to_viewport_height_test() ->
    %% Content taller than the viewport must be clipped to the viewport rect.
    Node = educkui_widget_viewport:render(
        #{content => content(), scroll_y => 0, content_height => 10},
        #dui_rect{width = 10, height = 2}),
    Cells = Node#dui_node.cells,
    ?assertEqual(missing, char_at(Cells, 0, 2)).
