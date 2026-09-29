%% @doc Scroll showcase: viewport + scroll bar over a long list, driven by the
%% root component's offset state.
-module(dui_scroll).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-define(VIEWPORT, 10).
-define(TOTAL, 40).

init(_Opts) ->
    #{offset => 0}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = page_up}, _State) -> {msg, page_up};
event_to_msg(#dui_event{type = key, key = page_down}, _State) -> {msg, page_down};
event_to_msg(#dui_event{type = key, key = home}, _State) -> {msg, home};
event_to_msg(#dui_event{type = key, key = 'end'}, _State) -> {msg, 'end'};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(up, State) -> {State#{offset := max(0, maps:get(offset, State) - 1)}, []};
update(down, State) ->
    Max = max(0, ?TOTAL - ?VIEWPORT),
    {State#{offset := min(Max, maps:get(offset, State) + 1)}, []};
update(page_up, State) ->
    {State#{offset := max(0, maps:get(offset, State) - ?VIEWPORT)}, []};
update(page_down, State) ->
    Max = max(0, ?TOTAL - ?VIEWPORT),
    {State#{offset := min(Max, maps:get(offset, State) + ?VIEWPORT)}, []};
update(home, State) -> {State#{offset := 0}, []};
update('end', State) -> {State#{offset := max(0, ?TOTAL - ?VIEWPORT)}, []};
update(_Msg, State) -> {State, []}.

view(State) ->
    Offset = maps:get(offset, State),
    Content = items(),
    educkui_render_node:stack(vertical, [
        title(<<"Scroll - Up/Down/PgUp/PgDn/Home/End, Esc quit">>),
        educkui_render_node:height(
            educkui_render_node:stack(horizontal, [
                educkui_render_node:width(
                    educkui_render_node:widget(educkui_widget_viewport, #{
                        scroll_y => Offset,
                        content => Content,
                        content_height => ?TOTAL}),
                    30),
                educkui_render_node:width(
                    educkui_render_node:widget(educkui_widget_scroll_bar, #{
                        total => ?TOTAL,
                        offset => Offset,
                        viewport => ?VIEWPORT}),
                    1)
            ]),
            ?VIEWPORT)
    ]).

title(T) ->
    educkui_render_node:text(T, educkui_style:from([{fg, cyan}, {bold, true}])).

items() ->
    educkui_render_node:stack(vertical,
        [educkui_render_node:text(<<"Item ", (integer_to_binary(I))/binary>>)
         || I <- lists:seq(1, ?TOTAL)]).
