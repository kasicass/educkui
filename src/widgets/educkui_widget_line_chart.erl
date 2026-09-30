%% @doc A stateless ASCII line chart widget.
%%
%% Plots a series of values as `*' points across the widget's width, mapping
%% each sampled value into the vertical range. Props: `{values, [number()]}',
%% `{style, term()}'.
-module(educkui_widget_line_chart).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Values = maps:get(values, Props, []),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    W = Rect#dui_rect.width,
    H = Rect#dui_rect.height,
    case Values of
        [] ->
            educkui_render_node:empty();
        _ ->
            Points = sample(Values, W),
            Min = lists:min(Points),
            Max = lists:max(Points),
            Cells = [{X, y_for(V, Min, Max, H), point_cell(Style)}
                     || {X, V} <- zip_short(lists:seq(0, W - 1), Points)],
            educkui_render_node:cells(Cells)
    end.

-spec describe() -> map().
describe() ->
    #{name => <<"LineChart">>, description => <<"An ASCII line chart widget">>}.

-spec default_props() -> map().
default_props() ->
    #{values => [], style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec sample([number()], non_neg_integer()) -> [number()].
sample(Values, W) when length(Values) =< W ->
    Values;
sample(Values, W) ->
    Len = length(Values),
    [lists:nth(max(1, round(I * Len / W)), Values) || I <- lists:seq(1, W)].

-spec y_for(number(), number(), number(), non_neg_integer()) -> non_neg_integer().
y_for(V, Min, Max, H) when H > 1 ->
    case Max =:= Min of
        true -> H div 2;
        false -> max(0, min(H - 1, round((1 - (V - Min) / (Max - Min)) * (H - 1))))
    end;
y_for(_V, _Min, _Max, _H) ->
    0.

-spec point_cell(#dui_style{} | undefined) -> #dui_cell{}.
point_cell(Style) ->
    apply_style(educkui_cell:new(<<"*">>), Style).

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

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) -> zip_short(A, B, []).

zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
