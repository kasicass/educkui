%% @doc A stateless gauge widget (progress bar with percentage label).
%%
%% Props: `{value, float()}` (0.0..1.0), `{style, term()}`, `{fill_style, term()}`.
-module(educkui_widget_gauge).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Value = maps:get(value, Props, 0.0),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    FillStyle = style_from_prop(maps:get(fill_style, Props, undefined)),
    W = Rect#dui_rect.width,
    Filled = clamp(round(Value * W), 0, W),
    BarCells = [{X, 0, bar_cell(X < Filled, Style, FillStyle)}
                || X <- lists:seq(0, W - 1)],
    Percent = integer_to_list(round(Value * 100)) ++ "%",
    LabelCells = [{W + 1 + I, 0, label_cell(G)}
                  || {I, G} <- zip_short(lists:seq(0, length(Percent) - 1),
                                         string:to_graphemes(Percent))],
    educkui_render_node:cells(BarCells ++ LabelCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Gauge">>, description => <<"A gauge widget">>}.

-spec default_props() -> map().
default_props() ->
    #{value => 0.0, style => undefined, fill_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec bar_cell(boolean(), #dui_style{} | undefined, #dui_style{} | undefined) ->
    #dui_cell{}.
bar_cell(true, _Style, FillStyle) ->
    apply_style(educkui_cell:new(<<"█"/utf8>>), FillStyle);
bar_cell(false, Style, _FillStyle) ->
    apply_style(educkui_cell:new(<<"░"/utf8>>), Style).

-spec label_cell(char() | [char()]) -> #dui_cell{}.
label_cell(G) ->
    educkui_cell:new(unicode:characters_to_binary([G])).

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

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(V, Lo, Hi) -> min(Hi, max(Lo, V)).

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) -> zip_short(A, B, []).

zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
