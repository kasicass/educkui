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
    overlay/1, overlay/2,
    at/3,
    widget/2, widget/3,
    component/2, component/3,
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
        height = proplists:get_value(height, Opts),
        align = proplists:get_value(align, Opts)
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
        height = proplists:get_value(height, Opts),
        align = proplists:get_value(align, Opts)
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

%% @doc Creates a stateless-widget node. The renderer calls
%% `Module:render(Props, Rect)` and renders the result within this node's rect.
-spec widget(module(), map()) -> #dui_node{}.
widget(Module, Props) -> widget(Module, Props, []).

-spec widget(module(), map(), [{atom(), term()}]) -> #dui_node{}.
widget(Module, Props, _Opts) when is_atom(Module), is_map(Props) ->
    #dui_node{type = widget, module = Module, props = Props}.

%% @doc Places a single child node at absolute coordinates within the parent
%% rect (0-based). The child gets the remaining width/height.
-spec at(integer(), integer(), #dui_node{}) -> #dui_node{}.
at(X, Y, Child) ->
    #dui_node{type = at, x = X, y = Y, children = [Child]}.

%% @doc Creates an overlay node: children are rendered in order on top of each
%% other within the same rect (later children win).
-spec overlay([#dui_node{}]) -> #dui_node{}.
overlay(Children) -> overlay(Children, []).

-spec overlay([#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
overlay(Children, _Opts) when is_list(Children) ->
    #dui_node{type = overlay, children = Children}.

%% @doc Creates a child-component node. The runtime resolves it by looking up
%% (or initializing) the component's state, calling its `view/1`, and rendering
%% the result within this node's rect.
-spec component(term(), module()) -> #dui_node{}.
component(Id, Module) -> component(Id, Module, #{}).

-spec component(term(), module(), map()) -> #dui_node{}.
component(Id, Module, Props) when is_atom(Module), is_map(Props) ->
    #dui_node{type = component, component_id = Id, module = Module, props = Props}.

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
