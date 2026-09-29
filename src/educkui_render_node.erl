%% @doc Render tree node constructors.
%%
%% Render nodes are the output of component rendering. They form a tree that
%% the renderer converts into terminal buffer cells. Node types: `text`,
%% `box`, `stack`, `cells`, `empty`.
-module(educkui_render_node).

-include("educkui.hrl").

-export([
    empty/0,
    text/1, text/2,
    box/1, box/2,
    stack/2, stack/3,
    cells/1, cells/2,
    styled/2,
    width/2, height/2,
    is_empty/1,
    child_count/1
]).

-spec empty() -> #dui_node{}.
empty() -> #dui_node{type = empty}.

-spec text(binary()) -> #dui_node{}.
text(Content) -> text(Content, undefined).

-spec text(binary(), #dui_style{} | undefined) -> #dui_node{}.
text(Content, Style) when is_binary(Content) ->
    #dui_node{type = text, content = Content, style = Style}.

-spec box([#dui_node{}]) -> #dui_node{}.
box(Children) -> box(Children, []).

-spec box([#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
box(Children, Opts) when is_list(Children) ->
    #dui_node{
        type = box,
        children = Children,
        style = proplists:get_value(style, Opts),
        width = proplists:get_value(width, Opts),
        height = proplists:get_value(height, Opts)
    }.

-spec stack(vertical | horizontal, [#dui_node{}]) -> #dui_node{}.
stack(Direction, Children) -> stack(Direction, Children, []).

-spec stack(vertical | horizontal, [#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
stack(Direction, Children, Opts)
        when (Direction =:= vertical orelse Direction =:= horizontal),
             is_list(Children) ->
    #dui_node{
        type = stack,
        direction = Direction,
        children = Children,
        style = proplists:get_value(style, Opts),
        width = proplists:get_value(width, Opts),
        height = proplists:get_value(height, Opts)
    }.

-spec cells([{integer(), integer(), #dui_cell{}}]) -> #dui_node{}.
cells(Cells) -> cells(Cells, []).

-spec cells([{integer(), integer(), #dui_cell{}}], [{atom(), term()}]) -> #dui_node{}.
cells(Cells, Opts) when is_list(Cells) ->
    #dui_node{
        type = cells,
        cells = Cells,
        children = proplists:get_value(children, Opts, []),
        width = proplists:get_value(width, Opts),
        height = proplists:get_value(height, Opts)
    }.

-spec styled(#dui_node{}, #dui_style{}) -> #dui_node{}.
styled(#dui_node{} = Node, #dui_style{} = Style) ->
    #dui_node{type = box, style = Style, children = [Node]}.

-spec width(#dui_node{}, non_neg_integer() | auto) -> #dui_node{}.
width(#dui_node{} = Node, W) when (is_integer(W) andalso W >= 0) orelse W =:= auto ->
    Node#dui_node{width = W}.

-spec height(#dui_node{}, non_neg_integer() | auto) -> #dui_node{}.
height(#dui_node{} = Node, H) when (is_integer(H) andalso H >= 0) orelse H =:= auto ->
    Node#dui_node{height = H}.

-spec is_empty(#dui_node{}) -> boolean().
is_empty(#dui_node{type = empty}) -> true;
is_empty(#dui_node{}) -> false.

-spec child_count(#dui_node{}) -> non_neg_integer().
child_count(#dui_node{children = Children}) -> length(Children).
