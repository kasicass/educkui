-module(educkui_widget_spinner_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_spinner(Props) ->
    Node = educkui_widget_spinner:render(Props, #dui_rect{width = 10, height = 1}),
    Node#dui_node.content.

frame_test() ->
    ?assertNotEqual(render_spinner(#{frame => 0}), render_spinner(#{frame => 1})).

frame_wraps_test() ->
    ?assertEqual(render_spinner(#{frame => 0}),
                 render_spinner(#{frame => length(educkui_widget_spinner:frames())})).

custom_frames_test() ->
    ?assertEqual(<<"b!">>,
                 render_spinner(#{frame => 1, frames => [<<"a">>, <<"b">>],
                                  suffix => <<"!">>})).

empty_frames_test() ->
    ?assertEqual(<<>>, render_spinner(#{frames => []})).

frames_test() ->
    ?assert(length(educkui_widget_spinner:frames()) > 0).
