%% @doc Rasterizes a render node tree into positioned cells.
%%
%% Produces `{X, Y, #dui_cell{}}' tuples with 0-based coordinates relative to
%% the given rect's origin. `render/3' also resolves child-component nodes:
%% it initializes or looks up each component's state, calls its `view/1', and
%% returns the updated component tree, mouse-hit targets and focus order.
-module(educkui_render).

-include("educkui.hrl").

-export([render/2, render/3]).

%% @doc Pure convenience wrapper: renders with an empty component table.
-spec render(#dui_node{}, #dui_rect{}) -> [{integer(), integer(), #dui_cell{}}].
render(Node, Rect) ->
    {Cells, _Components, _Targets, _Order} = render(Node, Rect, #{}),
    Cells.

%% @doc Renders `Node' within `Rect', resolving child components.
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
        overlay -> render_overlay(Node, X, Y, W, H, Components);
        at -> render_at(Node, X, Y, W, H, Components);
        widget -> render_widget(Node, X, Y, W, H, Components);
        component -> render_component(Node, X, Y, W, H, Components)
    end.

%% ---------------------------------------------------------------------------
%% Node renderers
%% ---------------------------------------------------------------------------

%% @doc Renders children in order on top of each other within the same rect.
-spec render_overlay(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_overlay(#dui_node{children = Children}, X, Y, W, H, Components) ->
    Rect = #dui_rect{x = X, y = Y, width = W, height = H},
    lists:foldl(
        fun(Child, {CellsAcc, CompAcc, TAcc, OAcc}) ->
            {Cells, Comp1, Targets, Order} = render(Child, Rect, CompAcc),
            {CellsAcc ++ Cells, Comp1, TAcc ++ Targets, OAcc ++ Order}
        end,
        {[], Components, [], []},
        Children).

%% @doc Renders a single child at absolute coordinates within the rect.
-spec render_at(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_at(#dui_node{x = Ax, y = Ay, children = [Child]}, X, Y, W, H, Components) ->
    case Ax < W andalso Ay < H of
        true ->
            Rect = #dui_rect{x = X + Ax, y = Y + Ay,
                             width = W - Ax, height = H - Ay},
            render(Child, Rect, Components);
        false ->
            {[], Components, [], []}
    end;
render_at(#dui_node{}, _X, _Y, _W, _H, Components) ->
    {[], Components, [], []}.

%% @doc Renders a stateless widget by calling `Module:render(Props, Rect)'.
-spec render_widget(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_widget(#dui_node{module = Mod, props = Props}, X, Y, W, H, Components) ->
    Rect = #dui_rect{x = X, y = Y, width = W, height = H},
    Child = Mod:render(Props, Rect),
    render(Child, Rect, Components).

-spec render_component(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_component(#dui_node{component_id = Id, module = Mod, props = Props},
                 X, Y, W, H, Components) ->
    {Comp, Components1} = ensure_component(Id, Mod, Props, Components),
    ChildView = (Comp#dui_component.module):view(Comp#dui_component.state),
    Rect = #dui_rect{x = X, y = Y, width = W, height = H},
    {Cells, Components2, SubTargets, SubOrder} = render(ChildView, Rect, Components1),
    %% `focusable => false' keeps transparent overlay components (e.g. a mouse
    %% layer) out of Tab focus traversal.
    Order = case maps:get(focusable, Props, true) of
        false -> SubOrder;
        _ -> [Id | SubOrder]
    end,
    {Cells, Components2, [{Id, Rect} | SubTargets], Order}.

-spec render_box(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_box(#dui_node{style = Style, children = Children, align = Align},
           X, Y, W, H, Components) ->
    Background = fill_background(Style, X, Y, W, H),
    {Rects, Components0} =
        layout_children(vertical, X, Y, W, H, Children, Align, Components),
    {Cells, Components1, Targets, Order} =
        render_children(Children, Rects, Components0),
    {Background ++ Cells, Components1, Targets, Order}.

-spec render_stack(#dui_node{}, integer(), integer(), non_neg_integer(),
    non_neg_integer(), map()) ->
    {[{integer(), integer(), #dui_cell{}}], map(), [{term(), #dui_rect{}}], [term()]}.
render_stack(#dui_node{direction = Direction, children = Children, align = Align},
             X, Y, W, H, Components) ->
    {Rects, Components0} =
        layout_children(Direction, X, Y, W, H, Children, Align, Components),
    render_children(Children, Rects, Components0).

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
%% Layout (flex solver + alignment)
%% ---------------------------------------------------------------------------

-spec layout_children(vertical | horizontal, integer(), integer(),
    non_neg_integer(), non_neg_integer(), [#dui_node{}], atom(), map()) ->
    {[#dui_rect{}], map()}.
layout_children(vertical, X, Y, W, H, Children, Align, Components) ->
    {Constraints, Components1} =
        lists:mapfoldl(fun(C, Acc) -> height_constraint(C, Acc) end,
                       Components, Children),
    Sizes = educkui_layout_solver:solve(H, Constraints),
    Offsets = educkui_layout_solver:align(align_or(Align), H, Sizes),
    Rects = [#dui_rect{x = X, y = Y + Off, width = W, height = Size}
             || {Off, Size} <- zip_short(Offsets, Sizes)],
    {Rects, Components1};
layout_children(horizontal, X, Y, W, H, Children, Align, Components) ->
    {Constraints, Components1} =
        lists:mapfoldl(fun(C, Acc) -> width_constraint(C, Acc) end,
                       Components, Children),
    Sizes = educkui_layout_solver:solve(W, Constraints),
    Offsets = educkui_layout_solver:align(align_or(Align), W, Sizes),
    Rects = [#dui_rect{x = X + Off, y = Y, width = Size, height = H}
             || {Off, Size} <- zip_short(Offsets, Sizes)],
    {Rects, Components1}.

-spec height_constraint(#dui_node{}, map()) ->
    {educkui_layout_constraint:constraint(), map()}.
height_constraint(#dui_node{height = auto}, Components) ->
    {{flex, 1}, Components};
height_constraint(#dui_node{height = N}, Components)
        when is_integer(N), N >= 0 ->
    {{fixed, N}, Components};
height_constraint(Node, Components) ->
    {Size, Components1} = nat_size(Node, Components),
    {{fixed, element(2, Size)}, Components1}.

-spec width_constraint(#dui_node{}, map()) ->
    {educkui_layout_constraint:constraint(), map()}.
width_constraint(#dui_node{width = auto}, Components) ->
    {{flex, 1}, Components};
width_constraint(#dui_node{width = N}, Components)
        when is_integer(N), N >= 0 ->
    {{fixed, N}, Components};
width_constraint(Node, Components) ->
    {Size, Components1} = nat_size(Node, Components),
    {{fixed, element(1, Size)}, Components1}.

%% @doc Natural (preferred) size of a node in cells. Resolves component and
%% widget nodes so containers can size themselves around their content.
-spec nat_size(#dui_node{}, map()) ->
    {{non_neg_integer(), non_neg_integer()}, map()}.
nat_size(#dui_node{type = text, content = Content, width = W, height = H},
         Components) ->
    Lines = binary:split(Content, <<"\n">>, [global]),
    W1 = case Lines of
        [] -> 0;
        _ -> lists:max([educkui_display_width:string_width(L) || L <- Lines])
    end,
    {{apply_size(W, W1), apply_size(H, max(1, length(Lines)))}, Components};
nat_size(#dui_node{type = empty, width = W, height = H}, Components) ->
    {{apply_size(W, 0), apply_size(H, 0)}, Components};
nat_size(#dui_node{type = cells, cells = Cells, width = W, height = H},
         Components) ->
    W1 = case Cells of [] -> 0; _ -> lists:max([Cx + 1 || {Cx, _, _} <- Cells]) end,
    H1 = case Cells of [] -> 0; _ -> lists:max([Cy + 1 || {_, Cy, _} <- Cells]) end,
    {{apply_size(W, W1), apply_size(H, H1)}, Components};
nat_size(#dui_node{type = component, component_id = Id, module = Mod, props = Props,
                   width = W, height = H}, Components) ->
    {Comp, Components1} = ensure_component(Id, Mod, Props, Components),
    View = (Comp#dui_component.module):view(Comp#dui_component.state),
    {Size, Components2} = nat_size(View, Components1),
    {{apply_size(W, element(1, Size)), apply_size(H, element(2, Size))},
     Components2};
nat_size(#dui_node{type = widget, module = Mod, props = Props,
                   width = W, height = H}, Components) ->
    %% Widgets that declare a prop-driven size (e.g. a centered dialog) must
    %% not be measured against a dummy rect, otherwise rect-relative placement
    %% yields an enormous natural size.
    case widget_declared_size(Mod, Props) of
        {ok, NatW, NatH} ->
            {{apply_size(W, NatW), apply_size(H, NatH)}, Components};
        false ->
            %% A dummy large rect: widget natural size is prop-driven;
            %% rect-dependent positioning is resolved again at render time.
            Dummy = #dui_rect{x = 0, y = 0, width = 1000, height = 1000},
            Sub = Mod:render(Props, Dummy),
            {Size, Components1} = nat_size(Sub, Components),
            {{apply_size(W, element(1, Size)), apply_size(H, element(2, Size))},
             Components1}
    end;
nat_size(#dui_node{type = overlay, children = Children, width = W, height = H},
         Components) ->
    {Sizes, Components1} =
        lists:mapfoldl(fun(C, Acc) -> nat_size(C, Acc) end, Components, Children),
    W1 = case Sizes of [] -> 0; _ -> lists:max([SW || {SW, _} <- Sizes]) end,
    H1 = case Sizes of [] -> 0; _ -> lists:max([SH || {_, SH} <- Sizes]) end,
    {{apply_size(W, W1), apply_size(H, H1)}, Components1};
nat_size(#dui_node{type = at, x = Ax, y = Ay, children = [Child]}, Components) ->
    {Size, Components1} = nat_size(Child, Components),
    {{Ax + element(1, Size), Ay + element(2, Size)}, Components1};
nat_size(#dui_node{type = Type, children = Children, direction = Direction,
                   width = W, height = H}, Components)
        when Type =:= box; Type =:= stack ->
    {Sizes, Components1} =
        lists:mapfoldl(fun(C, Acc) -> nat_size(C, Acc) end, Components, Children),
    W1 = case Sizes of [] -> 0; _ -> lists:max([SW || {SW, _} <- Sizes]) end,
    H1 = case Direction of
        horizontal -> case Sizes of [] -> 0; _ -> lists:max([SH || {_, SH} <- Sizes]) end;
        _ -> lists:sum([SH || {_, SH} <- Sizes])
    end,
    {{apply_size(W, W1), apply_size(H, H1)}, Components1};
nat_size(#dui_node{width = W, height = H}, Components) ->
    %% unknown node: assume a single cell.
    {{apply_size(W, 1), apply_size(H, 1)}, Components}.

-spec widget_declared_size(module(), map()) ->
    {ok, non_neg_integer(), non_neg_integer()} | false.
widget_declared_size(Mod, Props) ->
    _ = code:ensure_loaded(Mod),
    case erlang:function_exported(Mod, natural_size, 1) of
        true ->
            case Mod:natural_size(Props) of
                {Nw, Nh} when is_integer(Nw), Nw >= 0,
                              is_integer(Nh), Nh >= 0 -> {ok, Nw, Nh};
                _ -> false
            end;
        false ->
            false
    end.

-spec apply_size(term(), non_neg_integer()) -> non_neg_integer().
apply_size(undefined, Nat) -> Nat;
apply_size(auto, Nat) -> Nat;
apply_size(N, _Nat) when is_integer(N), N >= 0 -> N;
apply_size(_N, Nat) -> Nat.

-spec align_or(atom() | undefined) -> start | center | 'end' | space_between.
align_or(undefined) -> start;
align_or(Align) -> Align.

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
