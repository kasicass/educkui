%% @doc A stateless context menu widget.
%%
%% Renders a list of items in a bordered box at a position. Props:
%% `{items, [binary()]}`, `{selected, non_neg_integer()}`, `{x, integer()}`,
%% `{y, integer()}` (0-based, relative to the widget's rect), `{style, term()}`.
-module(educkui_widget_context_menu).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Items = maps:get(items, Props, []),
    Selected = maps:get(selected, Props, 0),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    X = maps:get(x, Props, 0),
    Y = maps:get(y, Props, 0),
    W = case Items of
        [] -> 2;
        _ -> lists:max([string:length(I) || I <- Items]) + 4
    end,
    H = length(Items) + 2,
    Background = fill_background(X, Y, W, H, Style),
    Border = border_cells(X, Y, W, H, Style),
    ItemCells = lists:flatmap(
        fun({Item, I}) ->
            ItemStyle = case I =:= Selected of
                true -> educkui_style:from([{reverse, true}]);
                false -> undefined
            end,
            text_cells(Item, X + 2, Y + 1 + I, W - 4, ItemStyle)
        end,
        lists:zip(Items, lists:seq(0, length(Items) - 1))),
    educkui_render_node:cells(Background ++ Border ++ ItemCells).

-spec describe() -> map().
describe() ->
    #{name => <<"ContextMenu">>, description => <<"A context menu widget">>}.

-spec default_props() -> map().
default_props() ->
    #{items => [], selected => 0, x => 0, y => 0, style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec fill_background(integer(), integer(), non_neg_integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
fill_background(BX, BY, W, H, #dui_style{bg = Bg})
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{BX + X, BY + Y, Cell} || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1)];
fill_background(_BX, _BY, _W, _H, _Style) ->
    [].

-spec border_cells(integer(), integer(), non_neg_integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
border_cells(BX, BY, W, H, Style) when W >= 2, H >= 2 ->
    Corners = [
        {BX, BY, cell(<<"┌"/utf8>>, Style)},
        {BX + W - 1, BY, cell(<<"┐"/utf8>>, Style)},
        {BX, BY + H - 1, cell(<<"└"/utf8>>, Style)},
        {BX + W - 1, BY + H - 1, cell(<<"┘"/utf8>>, Style)}
    ],
    Top = [{X, BY, cell(<<"─"/utf8>>, Style)} || X <- lists:seq(BX + 1, BX + W - 2)],
    Bottom = [{X, BY + H - 1, cell(<<"─"/utf8>>, Style)}
              || X <- lists:seq(BX + 1, BX + W - 2)],
    Left = [{BX, Y, cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(BY + 1, BY + H - 2)],
    Right = [{BX + W - 1, Y, cell(<<"│"/utf8>>, Style)}
             || Y <- lists:seq(BY + 1, BY + H - 2)],
    Corners ++ Top ++ Bottom ++ Left ++ Right;
border_cells(_BX, _BY, _W, _H, _Style) ->
    [].

-spec text_cells(binary(), integer(), integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
text_cells(Text, X, Y, MaxW, Style) ->
    Display = educkui_component_helpers:truncate_text(Text, MaxW),
    Graphemes = string:to_graphemes(Display),
    [{X + I, Y, cell(unicode:characters_to_binary([G]), Style)}
     || {I, G} <- zip_short(lists:seq(0, MaxW - 1), Graphemes)].

-spec cell(binary(), #dui_style{} | undefined) -> #dui_cell{}.
cell(Char, Style) ->
    {_X, _Y, C} = educkui_component_helpers:positioned_cell(0, 0, Char, Style),
    C.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) -> zip_short(A, B, []).

zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
