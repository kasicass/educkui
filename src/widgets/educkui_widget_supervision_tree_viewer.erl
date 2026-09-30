%% @doc A stateless supervision tree viewer.
%%
%% Props: `{tree, [{Label :: binary(), Children :: [same_shape()]}]}'. Renders
%% the tree fully expanded with indentation.
-module(educkui_widget_supervision_tree_viewer).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Tree = maps:get(tree, Props, []),
    Lines = flatten_labels(Tree, 0, []),
    Nodes = [educkui_render_node:text(Line) || Line <- Lines],
    educkui_render_node:stack(vertical, Nodes).

-spec describe() -> map().
describe() ->
    #{name => <<"SupervisionTreeViewer">>,
      description => <<"A supervision tree viewer widget">>}.

-spec default_props() -> map().
default_props() ->
    #{tree => []}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec flatten_labels([{binary(), [term()]}], non_neg_integer(), [binary()]) ->
    [binary()].
flatten_labels([], _Depth, Acc) ->
    lists:reverse(Acc);
flatten_labels([{Label, Children} | Rest], Depth, Acc) ->
    Indent = lists:duplicate(Depth * 2, $\s),
    Line = iolist_to_binary([Indent, Label]),
    Acc1 = [Line | Acc],
    Acc2 = flatten_labels(Children, Depth + 1, Acc1),
    flatten_labels(Rest, Depth, Acc2).
