%% @doc Shared helpers for visualization widgets.
%%
%% Extracted from the chart and gauge widgets: style coercion/application,
%% clamping, zip and series sampling/ratio math.
-module(educkui_visualization_helper).

-include("educkui.hrl").

-export([
    style_from_prop/1,
    apply_style/2,
    clamp/3,
    zip_short/2, zip_short/3,
    sample_series/2,
    ratio/3
]).

%% ---------------------------------------------------------------------------
%% Style helpers
%% ---------------------------------------------------------------------------

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap);
style_from_prop(StyleList) when is_list(StyleList) -> educkui_style:from(StyleList).

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

%% ---------------------------------------------------------------------------
%% Numeric / series helpers
%% ---------------------------------------------------------------------------

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(V, Lo, Hi) -> min(Hi, max(Lo, V)).

-spec sample_series([number()], non_neg_integer()) -> [number()].
sample_series([], _Width) -> [];
sample_series(_Values, 0) -> [];
sample_series(Values, Width) when length(Values) =< Width ->
    Values;
sample_series(Values, Width) ->
    Len = length(Values),
    [lists:nth(max(1, round(I * Len / Width)), Values) || I <- lists:seq(1, Width)].

-spec ratio(number(), number(), number()) -> float().
ratio(_Value, Min, Max) when Max =:= Min ->
    0.5;
ratio(Value, Min, Max) ->
    (Value - Min) / (Max - Min).

%% ---------------------------------------------------------------------------
%% Zip helpers
%% ---------------------------------------------------------------------------

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) ->
    zip_short(A, B, []).

-spec zip_short([term()], [term()], [{term(), term()}]) -> [{term(), term()}].
zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
