%% @doc A stateful streaming-data widget with a bounded buffer.
%%
%% Implements The Elm Architecture. The widget is embedded as a component
%% node (`educkui_render_node:component/3') and receives stream items via
%% `educkui_runtime:send_message(Runtime, ComponentId, {stream_item, Data})'
%% or `{stream_items, [Data]}'.
%%
%% Props:
%% - `{buffer_size, pos_integer()}'      (default `1000')
%% - `{overflow_strategy, atom()}'       `drop_oldest | drop_newest | block |
%%                                        sliding' (default `drop_oldest')
%% - `{show_stats, boolean()}'           (default `true')
%% - `{height, pos_integer()}'           visible item count (default `10')
%% - `{item_renderer, fun((term()) -> term())}' per-item renderer
%% - `{on_item, fun((term()) -> term())}'      called for each received item
%% - `{on_error, fun((term()) -> term())}'     reserved for error notifications
%%
%% Keyboard:
%% - Space: pause/resume
%% - c: clear buffer
%% - s: toggle stats display
%% - Up/Down/PageUp/PageDown/Home/End: scroll through the buffer
%% - Esc: propagate to the parent
-module(educkui_widget_stream).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-define(STATS_WINDOW_MS, 5000).
-define(PAGE_SIZE, 20).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    BufferSize = max(1, proplists:get_value(buffer_size, Opts, 1000)),
    Height = max(1, proplists:get_value(height, Opts, 10)),
    #{buffer => queue:new(),
      buffer_count => 0,
      buffer_size => BufferSize,
      overflow_strategy => proplists:get_value(overflow_strategy, Opts, drop_oldest),
      paused => false,
      stats => #{items_received => 0,
                 items_dropped => 0,
                 items_per_second => 0.0,
                 buffer_size => 0,
                 buffer_capacity => BufferSize,
                 last_update => undefined},
      stats_window => [],
      show_stats => proplists:get_value(show_stats, Opts, true),
      scroll_offset => 0,
      cursor => 0,
      height => Height,
      item_renderer => proplists:get_value(item_renderer, Opts, undefined),
      on_item => proplists:get_value(on_item, Opts, undefined),
      on_error => proplists:get_value(on_error, Opts, undefined),
      focused => false,
      next_id => 0}.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = page_up}, _State) -> {msg, page_up};
event_to_msg(#dui_event{type = key, key = page_down}, _State) -> {msg, page_down};
event_to_msg(#dui_event{type = key, key = home}, _State) -> {msg, home};
event_to_msg(#dui_event{type = key, key = 'end'}, _State) -> {msg, 'end'};
event_to_msg(#dui_event{type = key, key = <<" ">>}, _State) -> {msg, toggle_pause};
event_to_msg(#dui_event{type = key, key = <<"c">>}, _State) -> {msg, clear};
event_to_msg(#dui_event{type = key, key = <<"s">>}, _State) -> {msg, toggle_stats};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(#dui_event{type = custom, key = message, content = {_Id, Msg}}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update({stream_item, Data}, State) ->
    add_items([Data], State);
update({stream_items, Datas}, State) when is_list(Datas) ->
    add_items(Datas, State);
update(up, State) ->
    move_cursor(State, -1);
update(down, State) ->
    move_cursor(State, 1);
update(page_up, State) ->
    move_cursor(State, -?PAGE_SIZE);
update(page_down, State) ->
    move_cursor(State, ?PAGE_SIZE);
update(home, State) ->
    {State#{cursor := 0, scroll_offset := 0}, []};
update('end', State) ->
    move_cursor_to_end(State);
update(toggle_pause, State) ->
    {State#{paused := not maps:get(paused, State)}, []};
update(clear, State) ->
    {clear_buffer(State), []};
update(toggle_stats, State) ->
    {State#{show_stats := not maps:get(show_stats, State)}, []};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

%% ---------------------------------------------------------------------------
%% Buffer management
%% ---------------------------------------------------------------------------

-spec add_items([term()], map()) -> {map(), [term()]}.
add_items(Items, State) ->
    case maps:get(paused, State, false) of
        true ->
            {bump_stats(State, 0, length(Items)), []};
        false ->
            {State1, Added, Dropped} =
                lists:foldl(
                    fun(Data, {Acc, A, D}) ->
                        case add_item_to_buffer(Acc, Data) of
                            {ok, Acc1} -> {Acc1, A + 1, D};
                            {dropped, Acc1} -> {Acc1, A, D + 1}
                        end
                    end,
                    {State, 0, 0},
                    Items),
            {bump_stats(State1, Added, Dropped), item_cmds(State1, Items)}
    end.

-spec add_item_to_buffer(map(), term()) -> {ok, map()} | {dropped, map()}.
add_item_to_buffer(State, Data) ->
    Item = make_item(State, Data),
    case maps:get(buffer_count, State) < maps:get(buffer_size, State) of
        true ->
            Q = maps:get(buffer, State),
            {ok, State#{buffer := queue:in(Item, Q),
                        buffer_count := maps:get(buffer_count, State) + 1,
                        next_id := maps:get(next_id, State) + 1}};
        false ->
            handle_overflow(State, Item)
    end.

-spec make_item(map(), term()) -> map().
make_item(State, Data) ->
    #{id => maps:get(next_id, State),
      timestamp => now_ms(),
      data => Data,
      metadata => #{}}.

-spec handle_overflow(map(), map()) -> {ok, map()} | {dropped, map()}.
handle_overflow(State, Item) ->
    NextId = maps:get(next_id, State) + 1,
    case maps:get(overflow_strategy, State) of
        drop_oldest -> drop_oldest(State, Item, NextId);
        sliding -> drop_oldest(State, Item, NextId);
        drop_newest -> {dropped, State#{next_id := NextId}};
        block -> {dropped, State#{next_id := NextId}}
    end.

-spec drop_oldest(map(), map(), non_neg_integer()) -> {ok, map()}.
drop_oldest(State, Item, NextId) ->
    Q = maps:get(buffer, State),
    {_, Q1} = queue:out(Q),
    Q2 = queue:in(Item, Q1),
    {ok, State#{buffer := Q2, next_id := NextId}}.

-spec clear_buffer(map()) -> map().
clear_buffer(State) ->
    State#{buffer := queue:new(), buffer_count := 0, cursor := 0,
           scroll_offset := 0}.

-spec item_cmds(map(), [term()]) -> [term()].
item_cmds(State, Items) ->
    case maps:get(on_item, State, undefined) of
        Fun when is_function(Fun, 1) ->
            [{exec, fun() -> lists:foreach(Fun, Items) end}];
        _ ->
            []
    end.

%% ---------------------------------------------------------------------------
%% Statistics
%% ---------------------------------------------------------------------------

-spec bump_stats(map(), non_neg_integer(), non_neg_integer()) -> map().
bump_stats(State, Added, Dropped) ->
    Stats = maps:get(stats, State),
    Received = maps:get(items_received, Stats) + Added,
    DroppedTotal = maps:get(items_dropped, Stats) + Dropped,
    Now = now_ms(),
    Window = update_window(maps:get(stats_window, State), Added, Now),
    Stats1 = Stats#{items_received := Received,
                    items_dropped := DroppedTotal,
                    items_per_second := calc_rate(Window, Now),
                    buffer_size := maps:get(buffer_count, State),
                    buffer_capacity := maps:get(buffer_size, State),
                    last_update := Now},
    State#{stats := Stats1, stats_window := Window}.

-spec update_window([{integer(), non_neg_integer()}], non_neg_integer(),
                    integer()) -> [{integer(), non_neg_integer()}].
update_window(Window, Added, Now) ->
    Cutoff = Now - ?STATS_WINDOW_MS,
    Filtered = [{T, C} || {T, C} <- Window, T > Cutoff],
    case Added of
        0 -> Filtered;
        _ -> Filtered ++ [{Now, Added}]
    end.

-spec calc_rate([{integer(), non_neg_integer()}], integer()) -> float().
calc_rate([], _Now) ->
    0.0;
calc_rate(Window, Now) ->
    Total = lists:sum([C || {_T, C} <- Window]),
    Oldest = lists:min([T || {T, _C} <- Window]),
    DurationMs = Now - Oldest,
    case DurationMs > 0 of
        true -> Total / (DurationMs / 1000.0);
        false -> 0.0
    end.

%% ---------------------------------------------------------------------------
%% Navigation
%% ---------------------------------------------------------------------------

-spec move_cursor(map(), integer()) -> {map(), [term()]}.
move_cursor(State, Delta) ->
    Count = maps:get(buffer_count, State),
    Max = max(0, Count - 1),
    NewCursor = clamp(0, Max, maps:get(cursor, State) + Delta),
    {ensure_visible(State#{cursor := NewCursor}), []}.

-spec move_cursor_to_end(map()) -> {map(), [term()]}.
move_cursor_to_end(State) ->
    Count = maps:get(buffer_count, State),
    {ensure_visible(State#{cursor := max(0, Count - 1)}), []}.

-spec ensure_visible(map()) -> map().
ensure_visible(State) ->
    Height = maps:get(height, State),
    Cursor = maps:get(cursor, State),
    Offset = maps:get(scroll_offset, State),
    NewOffset =
        if
            Cursor < Offset -> Cursor;
            Cursor >= Offset + Height -> Cursor - Height + 1;
            true -> Offset
        end,
    State#{scroll_offset := max(0, NewOffset)}.

%% ---------------------------------------------------------------------------
%% view
%% ---------------------------------------------------------------------------

-spec view(map()) -> #dui_node{}.
view(State) ->
    StatsNode = case maps:get(show_stats, State, true) of
        true -> educkui_render_node:text(render_stats(State),
                                         educkui_style:from([{fg, cyan}]));
        false -> educkui_render_node:empty()
    end,
    ItemNodes = render_items(State),
    educkui_render_node:stack(vertical, [StatsNode | ItemNodes]).

-spec render_items(map()) -> [#dui_node{}].
render_items(State) ->
    All = queue:to_list(maps:get(buffer, State)),
    Height = maps:get(height, State),
    Offset = maps:get(scroll_offset, State),
    Cursor = maps:get(cursor, State),
    Focused = maps:get(focused, State),
    Visible = lists:sublist(lists:nthtail(Offset, All), Height),
    lists:map(
        fun({Item, I}) ->
            Style = case Focused andalso I =:= Cursor of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(render_item(State, Item), Style)
        end,
        lists:zip(Visible, lists:seq(Offset, Offset + length(Visible) - 1))).

-spec render_item(map(), map()) -> binary().
render_item(State, Item) ->
    Data = maps:get(data, Item),
    case maps:get(item_renderer, State, undefined) of
        Fun when is_function(Fun, 1) -> to_bin(Fun(Data));
        _ -> default_item_renderer(Data)
    end.

-spec default_item_renderer(term()) -> binary().
default_item_renderer(Data) when is_binary(Data) -> Data;
default_item_renderer(Data) -> to_bin(Data).

-spec render_stats(map()) -> binary().
render_stats(State) ->
    Stats = maps:get(stats, State),
    Paused = case maps:get(paused, State) of
        true -> <<"PAUSED">>;
        false -> <<"running">>
    end,
    Recv = integer_to_binary(maps:get(items_received, Stats)),
    Drop = integer_to_binary(maps:get(items_dropped, Stats)),
    Rate = format_rate(maps:get(items_per_second, Stats)),
    Buf = integer_to_binary(maps:get(buffer_count, State)),
    Cap = integer_to_binary(maps:get(buffer_size, State)),
    <<"stream ", Paused/binary, "  items:", Recv/binary,
      "  dropped:", Drop/binary, "  rate:", Rate/binary, "/s  buf:",
      Buf/binary, "/", Cap/binary>>.

-spec format_rate(float()) -> binary().
format_rate(F) ->
    float_to_binary(F, [{decimals, 1}]).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(Min, _Max, V) when V < Min -> Min;
clamp(_Min, Max, V) when V > Max -> Max;
clamp(_Min, _Max, V) -> V.

-spec now_ms() -> integer().
now_ms() ->
    erlang:monotonic_time(millisecond).

-spec to_bin(term()) -> binary().
to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(T) -> unicode:characters_to_binary(io_lib:format("~p", [T])).
