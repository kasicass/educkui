-module(educkui_widget_cluster_dashboard_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_test() ->
    Node = educkui_widget_cluster_dashboard:render(
        #{nodes => [{<<"a@host">>, <<"local">>}]},
        #dui_rect{width = 40, height = 5}),
    ?assertEqual(stack, Node#dui_node.type),
    %% header + one row
    ?assertEqual(2, length(Node#dui_node.children)).

collect_test() ->
    Rows = educkui_widget_cluster_dashboard:collect(),
    ?assert(length(Rows) >= 1),
    {Name, Slogan} = hd(Rows),
    ?assert(is_binary(Name)),
    ?assertEqual(<<"local">>, Slogan).
