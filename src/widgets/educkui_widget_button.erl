%% @doc A button widget with focus highlight.
-module(educkui_widget_button).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Label = maps:get(label, Props, <<>>),
    Focused = maps:get(focused, Props, false),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    FocusStyle = style_from_prop(maps:get(focus_style, Props, undefined)),

    EffectiveStyle = case Focused of
        true -> merge_opt(default_style(Style), FocusStyle);
        false -> default_style(Style)
    end,

    %% Draw border with the effective style, then centered label.
    Border = border_cells(Rect, EffectiveStyle),
    LabelCells = label_cells(Label, Rect, EffectiveStyle),
    educkui_render_node:cells(Border ++ LabelCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Button">>, description => <<"A button widget">>}.

-spec default_props() -> map().
default_props() ->
    #{label => <<>>, focused => false, style => undefined, focus_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec border_cells(#dui_rect{}, #dui_style{}) -> [{integer(), integer(), #dui_cell{}}].
border_cells(#dui_rect{width = W, height = H}, Style) when W >= 2, H >= 2 ->
    Corners = [
        {0, 0, cell(<<"["/utf8>>, Style)},
        {W - 1, 0, cell(<<"]"/utf8>>, Style)},
        {0, H - 1, cell(<<"["/utf8>>, Style)},
        {W - 1, H - 1, cell(<<"]"/utf8>>, Style)}
    ],
    Top = [{X, 0, cell(<<"─"/utf8>>, Style)} || X <- lists:seq(1, W - 2)],
    Bottom = [{X, H - 1, cell(<<"─"/utf8>>, Style)} || X <- lists:seq(1, W - 2)],
    Left = [{0, Y, cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(1, H - 2)],
    Right = [{W - 1, Y, cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(1, H - 2)],
    Corners ++ Top ++ Bottom ++ Left ++ Right;
border_cells(_Rect, _Style) ->
    [].

-spec label_cells(binary(), #dui_rect{}, #dui_style{}) ->
    [{integer(), integer(), #dui_cell{}}].
label_cells(Label, #dui_rect{width = W, height = H}, Style) when H >= 1 ->
    InnerW = max(0, W - 2),
    Display = educkui_component_helpers:truncate_text(Label, InnerW),
    Graphemes = string:to_graphemes(Display),
    Padding = InnerW - length(Graphemes),
    LeftPad = Padding div 2,
    Y = H div 2,
    [{1 + X, Y, cell(unicode:characters_to_binary([G]), Style)}
     || {X, G} <- lists:zip(lists:seq(LeftPad, LeftPad + length(Graphemes) - 1),
                            Graphemes)];
label_cells(_Label, _Rect, _Style) ->
    [].

-spec cell(binary(), #dui_style{}) -> #dui_cell{}.
cell(Char, Style) ->
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
