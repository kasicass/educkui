%% @doc A stateless list widget with selection highlight.
-module(educkui_widget_list).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Items = maps:get(items, Props, []),
    Selected = maps:get(selected, Props, 0),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    SelectedStyle = style_from_prop(maps:get(selected_style, Props, undefined)),

    Cells = lists:flatmap(
        fun({Item, Y}) when Y < Rect#dui_rect.height ->
            ItemStyle = case Y =:= Selected of
                true -> merge_opt(default_style(Style), SelectedStyle);
                false -> default_style(Style)
            end,
            item_cells(Item, Y, Rect#dui_rect.width, ItemStyle);
           (_) -> []
        end,
        lists:zip(Items, lists:seq(0, Rect#dui_rect.height - 1))),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"List">>, description => <<"A list widget with selection">>}.

-spec default_props() -> map().
default_props() ->
    #{items => [], selected => 0, style => undefined, selected_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec item_cells(binary(), integer(), non_neg_integer(), #dui_style{}) ->
    [{integer(), integer(), #dui_cell{}}].
item_cells(Item, Y, Width, Style) ->
    Display = educkui_component_helpers:truncate_text(Item, Width),
    Graphemes = string:to_graphemes(Display),
    [{X, Y, item_cell(unicode:characters_to_binary([G]), Style)}
     || {X, G} <- lists:zip(lists:seq(0, length(Graphemes) - 1), Graphemes)].

-spec item_cell(binary(), #dui_style{}) -> #dui_cell{}.
item_cell(Char, Style) ->
    {_X, _Y, C} = educkui_component_helpers:positioned_cell(0, 0, Char, Style),
    C.

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
