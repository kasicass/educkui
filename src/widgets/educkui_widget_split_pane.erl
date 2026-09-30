%% @doc A stateful split-pane widget.
%%
%% Props: `{direction, horizontal | vertical}' (default horizontal),
%% `{children, [#dui_node{}]}' (two render trees), `{split, pos_integer()}'
%% (initial size of the first pane in columns/rows).
%%
%% Left/Right adjust the split for horizontal panes; Up/Down for vertical.
%% The first pane is fixed at `split', the second flexes to fill the rest.
-module(educkui_widget_split_pane).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    #{direction => proplists:get_value(direction, Opts, horizontal),
      children => proplists:get_value(children, Opts, []),
      split => max(1, proplists:get_value(split, Opts, 10)),
      focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = left}, State) ->
    case maps:get(direction, State) of
        horizontal -> {msg, split_dec};
        _ -> ignore
    end;
event_to_msg(#dui_event{type = key, key = right}, State) ->
    case maps:get(direction, State) of
        horizontal -> {msg, split_inc};
        _ -> ignore
    end;
event_to_msg(#dui_event{type = key, key = up}, State) ->
    case maps:get(direction, State) of
        vertical -> {msg, split_dec};
        _ -> ignore
    end;
event_to_msg(#dui_event{type = key, key = down}, State) ->
    case maps:get(direction, State) of
        vertical -> {msg, split_inc};
        _ -> ignore
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(split_inc, State) ->
    {State#{split := maps:get(split, State) + 1}, []};
update(split_dec, State) ->
    {State#{split := max(1, maps:get(split, State) - 1)}, []};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Direction = maps:get(direction, State),
    Split = maps:get(split, State),
    Children = maps:get(children, State),
    case {Direction, Children} of
        {_, [First, Second]} ->
            case Direction of
                horizontal ->
                    educkui_render_node:stack(horizontal, [
                        educkui_render_node:width(First, Split),
                        educkui_render_node:width(Second, auto)
                    ]);
                vertical ->
                    educkui_render_node:stack(vertical, [
                        educkui_render_node:height(First, Split),
                        educkui_render_node:height(Second, auto)
                    ])
            end;
        {_, [Only]} ->
            Only;
        {_, []} ->
            educkui_render_node:empty()
    end.
