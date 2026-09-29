%% @doc Rasterizes a render node tree into positioned cells.
%%
%% Produces `{X, Y, #dui_cell{}}` tuples with 0-based coordinates relative to
%% the given rect's origin. `render/3` also resolves child-component nodes:
%% it initializes or looks up each component's state, calls its `view/1`, and
%% returns the updated component tree, mouse-hit targets and focus order.
-module(educkui_render).

-include("educkui.hrl").

-export([render/2, render/3]).

%% @doc Pure convenience wrapper: renders with an empty component table.
-spec render(#dui_node{}, #dui_rect{}) -> [{integer(), integer(), #dui_cell{}}].
render(Node, Rect) ->
    {Cells, _Components, _Targets, _Order} = render(Node, Rect, #{}),
    Cells.

%% @doc Renders `Node` within `Rect`, resolving child components.
-spec render(#dui_node{}, #dui_rect{}, map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render(#dui_node{} = Node, #dui_rect{x = X, y = Y, width = W, height = H},
       Components) ->
    case Node#dui_node.type of
        empty -> {[], Components, [], []};
        text -> {render_text(Node, X, Y, W), Components, [], []};
        box -> render_box(Node, X, Y, W, H, Components);
        stack -> render_stack(Node, X, Y, W, H, Components);
        cells -> {render_cells(Node, X, Y), Components, [], []};
        component -> render_component(Node, X, Y, W, H, Components)
    end.

%% ---------------------------------------------------------------------------
%% Node renderers
%% ---------------------------------------------------------------------------

-spec render_component(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_component(#dui_node{component_id = Id, module = Mod, props = Props},
                 X, Y, W, H, Components) ->
    {Comp, Components1} = ensure_component(Id, Mod, Props, Components),
    ChildView = (Comp#dui_component.module):view(Comp#dui_component.state),
    Rect = #dui_rect{x = X, y = Y, width = W, height = H},
    {Cells, Components2, SubTargets, SubOrder} = render(ChildView, Rect, Components1),
    {Cells, Components2, [{Id, Rect} | SubTargets], [Id | SubOrder]}.

-spec render_box(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_box(#dui_node{style = Style, children = Children}, X, Y, W, H, Components) ->
    Background = fill_background(Style, X, Y, W, H),
    {Cells, Components1, Targets, Order} =
        render_children(Children, vertical_rects(X, Y, W, H, Children), Components),
    {Background ++ Cells, Components1, Targets, Order}.

-spec render_stack(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_stack(#dui_node{direction = vertical, children = Children},
             X, Y, W, H, Components) ->
    render_children(Children, vertical_rects(X, Y, W, H, Children), Components);
render_stack(#dui_node{direction = horizontal, children = Children},
             X, Y, W, H, Components) ->
    render_children(Children, horizontal_rects(X, Y, W, H, Children), Components).

-spec render_children([#dui_node{}], [#dui_rect{}], map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_children(Children, Rects, Components) ->
    lists:foldl(
        fun({Child, Rect}, {CellsAcc, CompAcc, TAcc, OAcc}) ->
            {Cells, Comp1, Targets, Order} = render(Child, Rect, CompAcc),
            {CellsAcc ++ Cells, Comp1, TAcc ++ Targets, OAcc ++ Order}
        end,
        {[], Components, [], []},
        zip_short(Children, Rects)).

%% ---------------------------------------------------------------------------
%% Layout (simple: vertical = 1 row each, horizontal = equal split)
%% ---------------------------------------------------------------------------

-spec vertical_rects(integer(), integer(), non_neg_integer(), non_neg_integer(),
    [#dui_node{}]) -> [#dui_rect{}].
vertical_rects(X, Y, W, H, Children) ->
    [#dui_rect{x = X, y = Y + J, width = W, height = 1}
     || J <- lists:seq(0, max(0, H - 1)), J < length(Children)].

-spec horizontal_rects(integer(), integer(), non_neg_integer(), non_neg_integer(),
    [#dui_node{}]) -> [#dui_rect{}].
horizontal_rects(X, Y, W, H, Children) ->
    N = max(1, length(Children)),
    ChildW = W div N,
    [#dui_rect{x = X + I * ChildW, y = Y, width = ChildW, height = H}
     || I <- lists:seq(0, N - 1)].

%% ---------------------------------------------------------------------------
%% Leaf renderers (cells only)
%% ---------------------------------------------------------------------------

-spec render_text(#dui_node{}, integer(), integer(), non_neg_integer()) ->
    [{integer(), integer(), #dui_cell{}}].
render_text(#dui_node{content = Content, style = Style}, X, Y, W) when W > 0 ->
    %% Truncate by display width (grapheme boundaries preserved).
    {Truncated, _} = educkui_display_width:truncate(Content, W),
    Graphemes = string:to_graphemes(Truncated),
    %% Place each grapheme at the current display column, advancing by its
    %% width and emitting a placeholder for the second column of wide chars.
    {RevCells, _} = lists:foldl(
        fun(G, {Acc, CurX}) ->
            Cell = grapheme_cell(G, Style),
            Width = educkui_cell:width(Cell),
            NewAcc = case Width >= 2 andalso CurX + 1 < X + W of
                true ->
                    Placeholder = educkui_cell:wide_placeholder(Cell),
                    [{CurX + 1, Y, Placeholder}, {CurX, Y, Cell} | Acc];
                false ->
                    [{CurX, Y, Cell} | Acc]
            end,
            {NewAcc, CurX + Width}
        end,
        {[], X},
        Graphemes),
    lists:reverse(RevCells);
render_text(_Node, _X, _Y, _W) ->
    [].

-spec render_cells(#dui_node{}, integer(), integer()) ->
    [{integer(), integer(), #dui_cell{}}].
render_cells(#dui_node{cells = Cells}, X, Y) ->
    [{X + Cx, Y + Cy, Cell} || {Cx, Cy, Cell} <- Cells].

-spec fill_background(#dui_style{} | undefined, integer(), integer(),
    non_neg_integer(), non_neg_integer()) -> [{integer(), integer(), #dui_cell{}}].
fill_background(#dui_style{bg = Bg}, X, Y, W, H)
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{X + I, Y + J, Cell}
     || J <- lists:seq(0, H - 1), I <- lists:seq(0, W - 1)];
fill_background(_Style, _X, _Y, _W, _H) ->
    [].

%% ---------------------------------------------------------------------------
%% Component table helpers
%% ---------------------------------------------------------------------------

-spec ensure_component(term(), module(), map(), map()) ->
    {#dui_component{}, map()}.
ensure_component(Id, Mod, Props, Components) ->
    case maps:find(Id, Components) of
        {ok, Comp} ->
            {Comp, Components};
        error ->
            InitResult = Mod:init(maps:to_list(Props)),
            {State, _Commands} = educkui_elm:normalize_init_result(InitResult),
            Comp = #dui_component{id = Id, module = Mod, state = State, props = Props},
            {Comp, maps:put(Id, Comp, Components)}
    end.

%% ---------------------------------------------------------------------------
%% Small helpers
%% ---------------------------------------------------------------------------

-spec grapheme_cell(char() | [char()], #dui_style{} | undefined) -> #dui_cell{}.
grapheme_cell(G, Style) ->
    Char = unicode:characters_to_binary([G]),
    Cell0 = educkui_cell:new(Char),
    apply_style(Cell0, Style).

-spec apply_style(#dui_cell{}, #dui_style{} | undefined) -> #dui_cell{}.
apply_style(Cell, undefined) -> Cell;
apply_style(Cell, #dui_style{fg = Fg, bg = Bg, attrs = Attrs}) ->
    C1 = case Fg of
        undefined -> Cell;
        _ -> educkui_cell:put_fg(Cell, Fg)
    end,
    C2 = case Bg of
        undefined -> C1;
        _ -> educkui_cell:put_bg(C1, Bg)
    end,
    lists:foldl(fun(A, C) -> educkui_cell:add_attr(C, A) end, C2, Attrs).

%% Zips two lists, truncating to the shorter one.
-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) ->
    zip_short(A, B, []).

-spec zip_short([term()], [term()], [{term(), term()}]) -> [{term(), term()}].
zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
