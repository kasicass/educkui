%% @doc A stateful hierarchical menu widget.
%%
%% Props: `{items, [{Id, Label, Children}]}` where `Children = []` marks a leaf
%% item (activating it sends `{parent, {menu_activate, Id}}` to the root), and
%% a non-empty `Children` opens a submenu.
%%
%% Up/Down move the selection; Right/Enter open a submenu or activate a leaf;
%% Left goes back; Esc propagates (so the app can close the menu).
-module(educkui_widget_menu).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Items = proplists:get_value(items, Opts, []),
    #{items => Items, path => [], selected => 0, focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, activate};
event_to_msg(#dui_event{type = key, key = right}, _State) -> {msg, activate};
event_to_msg(#dui_event{type = key, key = left}, _State) -> {msg, back};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(up, State) ->
    {State#{selected := max(0, maps:get(selected, State) - 1)}, []};
update(down, State) ->
    Level = current_level(maps:get(items, State), maps:get(path, State)),
    Max = max(0, length(Level) - 1),
    {State#{selected := min(Max, maps:get(selected, State) + 1)}, []};
update(activate, State) ->
    Level = current_level(maps:get(items, State), maps:get(path, State)),
    Selected = maps:get(selected, State),
    case Level of
        [] ->
            {State, []};
        _ ->
            {Id, _Label, Children} = lists:nth(min(length(Level), Selected + 1), Level),
            case Children of
                [] ->
                    {State, [{parent, {menu_activate, Id}}]};
                _ ->
                    {State#{path := maps:get(path, State) ++ [Selected],
                            selected := 0}, []}
            end
    end;
update(back, State) ->
    case maps:get(path, State) of
        [] -> {State, []};
        Path -> {State#{path := lists:sublist(Path, length(Path) - 1),
                        selected := 0}, []}
    end;
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Level = current_level(maps:get(items, State), maps:get(path, State)),
    Selected = maps:get(selected, State),
    Nodes = lists:map(
        fun({{_Id, Label, Children}, I}) ->
            Marker = case Children of
                [] -> <<" ">>;
                _ -> <<"▸"/utf8>>
            end,
            Style = case I =:= Selected of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(
                iolist_to_binary([Marker, <<" ">>, Label]),
                Style)
        end,
        lists:zip(Level, lists:seq(0, length(Level) - 1))),
    educkui_render_node:stack(vertical, Nodes).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec current_level([term()], [non_neg_integer()]) -> [term()].
current_level(Items, []) -> Items;
current_level(Items, [I | Rest]) ->
    {_Id, _Label, Children} = lists:nth(min(length(Items), I + 1), Items),
    current_level(Children, Rest).
