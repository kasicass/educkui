%% @doc A stateful command palette with type-ahead filtering.
%%
%% Props: `{commands, [{Label :: binary(), Payload :: term()}]}`. Type to filter
%% (case-insensitive substring), Up/Down move the highlight, Enter executes the
%% highlighted command by sending `{parent, {command, Payload}}` to the root.
-module(educkui_widget_command_palette).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Commands = proplists:get_value(commands, Opts, []),
    #{commands => Commands, filter => <<>>, highlight => 0, focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, activate};
event_to_msg(#dui_event{type = key, key = backspace}, _State) -> {msg, filter_backspace};
event_to_msg(#dui_event{type = key, key = _Key, char = Char}, _State) ->
    case Char of
        undefined -> ignore;
        _ -> {msg, {filter_char, Char}}
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(up, State) ->
    {State#{highlight := max(0, maps:get(highlight, State) - 1)}, []};
update(down, State) ->
    Filtered = filter_commands(State),
    Max = max(0, length(Filtered) - 1),
    {State#{highlight := min(Max, maps:get(highlight, State) + 1)}, []};
update(activate, State) ->
    Filtered = filter_commands(State),
    case Filtered of
        [] ->
            {State, []};
        _ ->
            Highlight = min(maps:get(highlight, State), length(Filtered) - 1),
            {_Label, Payload} = lists:nth(Highlight + 1, Filtered),
            {State, [{parent, {command, Payload}}]}
    end;
update(filter_backspace, State) ->
    Filter = maps:get(filter, State),
    NewFilter = case Filter of
        <<>> -> <<>>;
        _ -> string:slice(Filter, 0, string:length(Filter) - 1)
    end,
    {State#{filter := NewFilter, highlight := 0}, []};
update({filter_char, Char}, State) ->
    Filter = maps:get(filter, State),
    {State#{filter := <<Filter/binary, Char/binary>>, highlight := 0}, []};
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Filter = maps:get(filter, State),
    Highlight = maps:get(highlight, State),
    Filtered = filter_commands(State),
    Header = educkui_render_node:text(<<"> ", Filter/binary>>,
        educkui_style:from([{bold, true}])),
    Items = lists:map(
        fun({{Label, _Payload}, I}) ->
            Style = case I =:= Highlight of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(Label, Style)
        end,
        lists:zip(Filtered, lists:seq(0, length(Filtered) - 1))),
    educkui_render_node:stack(vertical, [Header | Items]).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec filter_commands(map()) -> [{binary(), term()}].
filter_commands(State) ->
    Commands = maps:get(commands, State),
    Filter = string:lowercase(maps:get(filter, State)),
    [{Label, Payload} || {Label, Payload} <- Commands,
        Filter =:= <<>> orelse
        string:find(string:lowercase(Label), Filter) =/= nomatch].
