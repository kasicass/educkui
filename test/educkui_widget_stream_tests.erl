-module(educkui_widget_stream_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

init_test() ->
    S = educkui_widget_stream:init([{buffer_size, 100}, {height, 5}]),
    ?assertEqual(0, maps:get(buffer_count, S)),
    ?assertEqual(100, maps:get(buffer_size, S)),
    ?assertEqual(5, maps:get(height, S)),
    ?assertEqual(drop_oldest, maps:get(overflow_strategy, S)),
    ?assertEqual(true, maps:get(show_stats, S)),
    ?assertEqual(false, maps:get(paused, S)),
    ?assertEqual(0, maps:get(items_received, maps:get(stats, S))).

add_item_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}]),
    {S1, []} = educkui_widget_stream:update({stream_item, <<"a">>}, S0),
    ?assertEqual(1, maps:get(buffer_count, S1)),
    ?assertEqual(1, maps:get(items_received, maps:get(stats, S1))),
    ?assertEqual(0, maps:get(items_dropped, maps:get(stats, S1))).

add_items_batch_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>, <<"c">>]}, S0),
    ?assertEqual(3, maps:get(buffer_count, S1)),
    ?assertEqual(3, maps:get(items_received, maps:get(stats, S1))).

overflow_drop_oldest_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 2},
                                     {overflow_strategy, drop_oldest}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    {S2, []} = educkui_widget_stream:update({stream_item, <<"c">>}, S1),
    ?assertEqual(2, maps:get(buffer_count, S2)),
    %% `drop_oldest` keeps the buffer full; the incoming item is counted as
    %% added and the displaced item is not counted as dropped (matching
    %% term_ui semantics).
    ?assertEqual(0, maps:get(items_dropped, maps:get(stats, S2))),
    All = queue:to_list(maps:get(buffer, S2)),
    ?assertEqual([<<"b">>, <<"c">>], [maps:get(data, I) || I <- All]).

overflow_drop_newest_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 2},
                                     {overflow_strategy, drop_newest}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    {S2, []} = educkui_widget_stream:update({stream_item, <<"c">>}, S1),
    ?assertEqual(2, maps:get(buffer_count, S2)),
    ?assertEqual(1, maps:get(items_dropped, maps:get(stats, S2))),
    All = queue:to_list(maps:get(buffer, S2)),
    ?assertEqual([<<"a">>, <<"b">>], [maps:get(data, I) || I <- All]).

overflow_sliding_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 2},
                                     {overflow_strategy, sliding}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    {S2, []} = educkui_widget_stream:update({stream_item, <<"c">>}, S1),
    All = queue:to_list(maps:get(buffer, S2)),
    ?assertEqual([<<"b">>, <<"c">>], [maps:get(data, I) || I <- All]).

overflow_block_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 2},
                                     {overflow_strategy, block}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    {S2, []} = educkui_widget_stream:update({stream_item, <<"c">>}, S1),
    ?assertEqual(2, maps:get(buffer_count, S2)),
    ?assertEqual(1, maps:get(items_dropped, maps:get(stats, S2))).

paused_drops_items_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}]),
    {S1, []} = educkui_widget_stream:update(toggle_pause, S0),
    ?assertEqual(true, maps:get(paused, S1)),
    {S2, []} = educkui_widget_stream:update({stream_item, <<"a">>}, S1),
    ?assertEqual(0, maps:get(buffer_count, S2)),
    ?assertEqual(1, maps:get(items_dropped, maps:get(stats, S2))).

clear_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    {S2, []} = educkui_widget_stream:update(clear, S1),
    ?assertEqual(0, maps:get(buffer_count, S2)),
    ?assertEqual(0, maps:get(cursor, S2)).

navigation_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}, {height, 3}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>, <<"c">>, <<"d">>]}, S0),
    {S2, []} = educkui_widget_stream:update('end', S1),
    ?assertEqual(3, maps:get(cursor, S2)),
    ?assertEqual(1, maps:get(scroll_offset, S2)),
    {S3, []} = educkui_widget_stream:update(home, S2),
    ?assertEqual(0, maps:get(cursor, S3)),
    ?assertEqual(0, maps:get(scroll_offset, S3)).

toggle_stats_test() ->
    S0 = educkui_widget_stream:init([]),
    {S1, []} = educkui_widget_stream:update(toggle_stats, S0),
    ?assertEqual(false, maps:get(show_stats, S1)),
    {S2, []} = educkui_widget_stream:update(toggle_stats, S1),
    ?assertEqual(true, maps:get(show_stats, S2)).

on_item_test() ->
    S0 = educkui_widget_stream:init([{on_item, fun(Data) -> self() ! {item, Data} end}]),
    {_S1, [_ExecCmd]} = educkui_widget_stream:update({stream_item, <<"x">>}, S0),
    ?assertMatch({exec, _}, _ExecCmd).

view_structure_test() ->
    S0 = educkui_widget_stream:init([{height, 3}]),
    {S1, []} = educkui_widget_stream:update(
        {stream_items, [<<"a">>, <<"b">>]}, S0),
    Node = educkui_widget_stream:view(S1),
    ?assertEqual(stack, Node#dui_node.type),
    %% stats row + 2 visible item rows.
    ?assertEqual(3, length(Node#dui_node.children)).

message_event_test() ->
    S0 = educkui_widget_stream:init([{buffer_size, 10}]),
    Event = educkui_event:custom(message, {stream, {stream_item, <<"x">>}}),
    ?assertEqual({msg, {stream_item, <<"x">>}},
                 educkui_widget_stream:event_to_msg(Event, S0)).
