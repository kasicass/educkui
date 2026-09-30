%% @doc A stateless list widget with selection highlight and optional scroll
%% offset.
%%
%% Props: `{items, [binary()]}', `{selected, non_neg_integer()}' (index into the
%% full list), `{offset, non_neg_integer()}' (number of items scrolled off the
%% top), `{style, style()}', `{selected_style, style()}'.
%%
%% Use `visible_range/3,4' to compute the offset that keeps the selection in
%% view when rendering a windowed list.
-module(educkui_widget_list).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0, visible_range/3, visible_range/4]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Items = maps:get(items, Props, []),
    Selected = maps:get(selected, Props, 0),
    Offset = max(0, maps:get(offset, Props, 0)),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    SelectedStyle = style_from_prop(maps:get(selected_style, Props, undefined)),
    Height = max(0, Rect#dui_rect.height),
    Visible = lists:sublist(Items, Offset + 1, Height),

    Cells = lists:flatmap(
        fun({Item, I}) ->
            GlobalIndex = Offset + I,
            ItemStyle = case GlobalIndex =:= Selected of
                true -> merge_opt(default_style(Style), SelectedStyle);
                false -> default_style(Style)
            end,
            item_cells(Item, I, Rect#dui_rect.width, ItemStyle)
        end,
        lists:zip(Visible, lists:seq(0, length(Visible) - 1))),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"List">>, description => <<"A list widget with selection">>}.

-spec default_props() -> map().
default_props() ->
    #{items => [], selected => 0, offset => 0, style => undefined,
      selected_style => undefined}.

%% @doc Computes the window `{Offset, Count}' that keeps `Selected' visible
%% within a viewport of `Height' rows.
-spec visible_range(non_neg_integer(), non_neg_integer(), non_neg_integer()) ->
    {non_neg_integer(), non_neg_integer()}.
visible_range(Total, Selected, Height) ->
    visible_range(Total, Selected, Height, 0).

%% @doc Like `visible_range/3' but starting from a previous `Offset', so the
%% viewport scrolls minimally instead of jumping to the top.
-spec visible_range(non_neg_integer(), non_neg_integer(), non_neg_integer(),
                    non_neg_integer()) -> {non_neg_integer(), non_neg_integer()}.
visible_range(_Total, _Selected, Height, _Offset) when Height =< 0 ->
    {0, 0};
visible_range(Total, Selected, Height, Offset0) ->
    Offset1 = clamp_offset(Total, Height, Offset0),
    Offset2 = case Selected < Offset1 of
        true -> Selected;
        false ->
            case Selected >= Offset1 + Height of
                true -> Selected - Height + 1;
                false -> Offset1
            end
    end,
    Offset3 = clamp_offset(Total, Height, Offset2),
    Count = min(Height, max(0, Total - Offset3)),
    {Offset3, Count}.

-spec clamp_offset(non_neg_integer(), pos_integer(), integer()) -> non_neg_integer().
clamp_offset(Total, Height, Offset) ->
    max(0, min(Offset, max(0, Total - Height))).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec item_cells(binary(), integer(), non_neg_integer(), #dui_style{}) ->
    [{integer(), integer(), #dui_cell{}}].
item_cells(Item, Y, Width, Style) ->
    {Display, _} = educkui_display_width:truncate(Item, Width),
    Graphemes = string:to_graphemes(Display),
    {Rev, _} = lists:foldl(
        fun(G, {Acc, X}) ->
            Char = unicode:characters_to_binary([G]),
            {_CX, _CY, Cell} = educkui_component_helpers:positioned_cell(X, Y, Char, Style),
            W = educkui_cell:width(Cell),
            NewAcc = case W >= 2 andalso X + 1 < Width of
                true ->
                    [{X + 1, Y, educkui_cell:wide_placeholder(Cell)}, {X, Y, Cell} | Acc];
                false ->
                    [{X, Y, Cell} | Acc]
            end,
            {NewAcc, X + W}
        end,
        {[], 0},
        Graphemes),
    lists:reverse(Rev).

-spec default_style(#dui_style{} | undefined) -> #dui_style{}.
default_style(undefined) -> educkui_style:new();
default_style(#dui_style{} = S) -> S.

-spec merge_opt(#dui_style{}, #dui_style{} | undefined) -> #dui_style{}.
merge_opt(Base, undefined) -> Base;
merge_opt(Base, #dui_style{} = Override) -> educkui_style:merge(Base, Override).

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
