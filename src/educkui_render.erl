%% @doc Rasterizes a render node tree into positioned cells.
%%
%% Produces a list of `{X, Y, #dui_cell{}}` tuples with 0-based coordinates
%% relative to the given rect's origin. The runtime offsets these by 1 when
%% writing into the 1-indexed screen buffer.
-module(educkui_render).

-include("educkui.hrl").

-export([render/2]).

-spec render(#dui_node{}, #dui_rect{}) -> [{integer(), integer(), #dui_cell{}}].
render(#dui_node{} = Node, #dui_rect{x = X, y = Y, width = W, height = H}) ->
    case Node#dui_node.type of
        empty -> [];
        text -> render_text(Node, X, Y, W);
        box -> render_box(Node, X, Y, W, H);
        stack -> render_stack(Node, X, Y, W, H);
        cells -> render_cells(Node, X, Y)
    end.

%% ---------------------------------------------------------------------------
%% Internal
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

-spec render_box(#dui_node{}, integer(), integer(), non_neg_integer(), non_neg_integer()) ->
    [{integer(), integer(), #dui_cell{}}].
render_box(#dui_node{style = Style, children = Children}, X, Y, W, H) ->
    Background = fill_background(Style, X, Y, W, H),
    ChildrenCells = render_vertical_children(Children, X, Y, W, H),
    Background ++ ChildrenCells.

-spec render_stack(#dui_node{}, integer(), integer(), non_neg_integer(), non_neg_integer()) ->
    [{integer(), integer(), #dui_cell{}}].
render_stack(#dui_node{direction = vertical, children = Children}, X, Y, W, H) ->
    render_vertical_children(Children, X, Y, W, H);
render_stack(#dui_node{direction = horizontal, children = Children}, X, Y, W, H) ->
    render_horizontal_children(Children, X, Y, W, H).

-spec render_cells(#dui_node{}, integer(), integer()) ->
    [{integer(), integer(), #dui_cell{}}].
render_cells(#dui_node{cells = Cells}, X, Y) ->
    [{X + Cx, Y + Cy, Cell} || {Cx, Cy, Cell} <- Cells].

-spec render_vertical_children([#dui_node{}], integer(), integer(),
    non_neg_integer(), non_neg_integer()) -> [{integer(), integer(), #dui_cell{}}].
render_vertical_children(Children, X, Y, W, H) ->
    lists:flatmap(
        fun({Child, J}) ->
            render(Child, #dui_rect{x = X, y = Y + J, width = W, height = 1})
        end,
        zip_short(Children, lists:seq(0, H - 1))).

-spec render_horizontal_children([#dui_node{}], integer(), integer(),
    non_neg_integer(), non_neg_integer()) -> [{integer(), integer(), #dui_cell{}}].
render_horizontal_children(Children, X, Y, W, H) ->
    N = max(1, length(Children)),
    ChildW = W div N,
    lists:flatmap(
        fun({Child, I}) ->
            render(Child, #dui_rect{x = X + I * ChildW, y = Y, width = ChildW, height = H})
        end,
        zip_short(Children, lists:seq(0, N - 1))).

-spec fill_background(#dui_style{} | undefined, integer(), integer(),
    non_neg_integer(), non_neg_integer()) -> [{integer(), integer(), #dui_cell{}}].
fill_background(#dui_style{bg = Bg}, X, Y, W, H)
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{X + I, Y + J, Cell}
     || J <- lists:seq(0, H - 1), I <- lists:seq(0, W - 1)];
fill_background(_Style, _X, _Y, _W, _H) ->
    [].

%% Zips two lists, truncating to the shorter one.
-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) ->
    zip_short(A, B, []).

-spec zip_short([term()], [term()], [{term(), term()}]) -> [{term(), term()}].
zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).

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
