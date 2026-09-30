%% @doc A stateful tree view widget.
%%
%% The tree is a list of `{Id, Label, Children}' tuples (children is a list of
%% the same shape). Up/Down move the selection among visible nodes; Right
%% expands the selected node, Left collapses it, Enter toggles expansion.
%% Expanded state is an ordset of node ids.
-module(educkui_widget_tree_view).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Tree = proplists:get_value(items, Opts, []),
    Selected = case Tree of
        [{Id, _, _} | _] -> Id;
        [] -> undefined
    end,
    #{tree => Tree, expanded => [], selected => Selected, focused => false}.

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = right}, _State) -> {msg, expand};
event_to_msg(#dui_event{type = key, key = left}, _State) -> {msg, collapse};
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, toggle};
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

-spec update(term(), map()) -> {map(), [term()]}.
update(up, State) ->
    move_selection(State, -1);
update(down, State) ->
    move_selection(State, 1);
update(expand, State) ->
    toggle_expand(State, true);
update(collapse, State) ->
    toggle_expand(State, false);
update(toggle, State) ->
    Selected = maps:get(selected, State),
    Expanded = maps:get(expanded, State),
    case ordsets:is_element(Selected, Expanded) of
        true -> toggle_expand(State, false);
        false -> toggle_expand(State, true)
    end;
update(focus_gained, State) ->
    {State#{focused := true}, []};
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec view(map()) -> #dui_node{}.
view(State) ->
    Tree = maps:get(tree, State),
    Expanded = maps:get(expanded, State),
    Selected = maps:get(selected, State),
    Visible = flatten(Tree, Expanded),
    Nodes = lists:map(
        fun({Id, Label, Depth, HasChildren}) ->
            ExpandedNode = ordsets:is_element(Id, Expanded),
            Marker = case HasChildren of
                true -> case ExpandedNode of
                    true -> <<"▾"/utf8>>;
                    false -> <<"▸"/utf8>>
                end;
                false -> <<" "/utf8>>
            end,
            Indent = lists:duplicate(Depth * 2, $\s),
            Text = iolist_to_binary([Indent, Marker, <<" ">>, Label]),
            Style = case Id =:= Selected of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            educkui_render_node:text(Text, Style)
        end,
        Visible),
    educkui_render_node:stack(vertical, Nodes).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec flatten([term()], [term()]) -> [{term(), binary(), non_neg_integer(),
    boolean()}].
flatten(Tree, Expanded) ->
    lists:reverse(flatten_acc(Tree, Expanded, 0, [])).

flatten_acc([], _Expanded, _Depth, Acc) ->
    Acc;
flatten_acc([{Id, Label, Children} | Rest], Expanded, Depth, Acc) ->
    Acc1 = [{Id, Label, Depth, Children =/= []} | Acc],
    Acc2 = case ordsets:is_element(Id, Expanded) of
        true -> flatten_acc(Children, Expanded, Depth + 1, Acc1);
        false -> Acc1
    end,
    flatten_acc(Rest, Expanded, Depth, Acc2).

-spec move_selection(map(), -1 | 1) -> {map(), [term()]}.
move_selection(State, Delta) ->
    Tree = maps:get(tree, State),
    Expanded = maps:get(expanded, State),
    Selected = maps:get(selected, State),
    Visible = flatten(Tree, Expanded),
    Ids = [Id || {Id, _, _, _} <- Visible],
    case Ids of
        [] -> {State, []};
        _ ->
            Idx = index_of(Selected, Ids),
            NewIdx = case Idx of
                undefined -> 1;
                I -> clamp(I + Delta, 1, length(Ids))
            end,
            {State#{selected := lists:nth(NewIdx, Ids)}, []}
    end.

-spec toggle_expand(map(), boolean()) -> {map(), [term()]}.
toggle_expand(State, Expand) ->
    Selected = maps:get(selected, State),
    Expanded = maps:get(expanded, State),
    case find_node(Selected, maps:get(tree, State)) of
        {ok, {_Id, _Label, Children}} when Children =/= [] ->
            NewExpanded = case Expand of
                true -> ordsets:add_element(Selected, Expanded);
                false -> ordsets:del_element(Selected, Expanded)
            end,
            {State#{expanded := NewExpanded}, []};
        _ ->
            {State, []}
    end.

-spec find_node(term(), [term()]) -> {ok, term()} | error.
find_node(Id, Tree) ->
    find_node(Id, Tree, []).

find_node(Id, [{Id, _, _} = Node | _], _Path) ->
    {ok, Node};
find_node(Id, [{_OId, _Label, Children} | Rest], Path) ->
    case find_node(Id, Children, [Id | Path]) of
        {ok, _} = Ok -> Ok;
        error -> find_node(Id, Rest, Path)
    end;
find_node(_Id, [], _Path) ->
    error.

-spec index_of(term(), [term()]) -> pos_integer() | undefined.
index_of(Id, List) ->
    case index_of(Id, List, 1) of
        0 -> undefined;
        I -> I
    end.

index_of(_Id, [], _N) -> 0;
index_of(Id, [Id | _], N) -> N;
index_of(Id, [_ | Rest], N) -> index_of(Id, Rest, N + 1).

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(V, Lo, Hi) -> min(Hi, max(Lo, V)).
