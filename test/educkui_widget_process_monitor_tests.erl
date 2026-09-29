-module(educkui_widget_process_monitor_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

render_test() ->
    Node = educkui_widget_process_monitor:render(
        #{rows => [{<<"<0.1.0>">>, <<"app">>, <<"100">>}]},
        #dui_rect{width = 40, height = 5}),
    ?assertEqual(stack, Node#dui_node.type),
    %% header + one row
    ?assertEqual(2, length(Node#dui_node.children)).

collect_test() ->
    Rows = educkui_widget_process_monitor:collect(),
    ?assert(is_list(Rows)),
    ?assert(length(Rows) > 0),
    {Pid, _Name, _Reds} = hd(Rows),
    ?assert(is_binary(Pid)).
