%% @doc A simple flex layout solver.
%%
%% Distributes `Total' units across a list of constraints. Fixed and minimum
%% sizes are honoured first, then remaining space is distributed to flex items
%% proportionally to their flex factor, and finally `max' constraints are
%% applied.
-module(educkui_layout_solver).

-export([solve/2, align/3]).

-type constraint() :: educkui_layout_constraint:constraint().
-export_type([constraint/0]).

%% ---------------------------------------------------------------------------
%% Solving
%% ---------------------------------------------------------------------------

-spec solve(non_neg_integer(), [constraint()]) -> [non_neg_integer()].
solve(Total, Constraints) ->
    {Sizes, Remaining, FlexWeights} = assign_baseline(Constraints, Total),
    Sizes1 = distribute_flex(Sizes, Remaining, FlexWeights),
    apply_max(Sizes1, Constraints).

%% ---------------------------------------------------------------------------
%% Alignment
%% ---------------------------------------------------------------------------

%% @doc Returns per-child offsets within `Total' for the given alignment.
-spec align(start | center | 'end' | space_between, non_neg_integer(),
    [non_neg_integer()]) -> [non_neg_integer()].
align(start, _Total, Sizes) ->
    offsets_from(0, Sizes);
align(center, Total, Sizes) ->
    Used = lists:sum(Sizes),
    offsets_from(max(0, (Total - Used) div 2), Sizes);
align('end', Total, Sizes) ->
    Used = lists:sum(Sizes),
    offsets_from(max(0, Total - Used), Sizes);
align(space_between, Total, Sizes) when length(Sizes) > 1 ->
    Used = lists:sum(Sizes),
    Gap = case length(Sizes) of
        N when N > 1 -> max(0, (Total - Used) div (N - 1));
        _ -> 0
    end,
    space_between_offsets(0, Sizes, Gap);
align(space_between, _Total, Sizes) ->
    offsets_from(0, Sizes).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec assign_baseline([constraint()], non_neg_integer()) ->
    {[non_neg_integer()], non_neg_integer(), [{pos_integer(), non_neg_integer()}]}.
assign_baseline(Constraints, Total) ->
    lists:foldl(
        fun
            ({fixed, N}, {Sizes, Remaining, Flex}) ->
                {Sizes ++ [N], max(0, Remaining - N), Flex};
            ({min, N}, {Sizes, Remaining, Flex}) ->
                {Sizes ++ [N], max(0, Remaining - N), Flex};
            ({flex, F}, {Sizes, Remaining, Flex}) ->
                {Sizes ++ [0], Remaining, Flex ++ [{F, length(Sizes)}]};
            ({max, N}, {Sizes, Remaining, Flex}) ->
                {Sizes ++ [N], max(0, Remaining - N), Flex}
        end,
        {[], Total, []},
        Constraints).

-spec distribute_flex([non_neg_integer()], non_neg_integer(),
    [{pos_integer(), non_neg_integer()}]) -> [non_neg_integer()].
distribute_flex(Sizes, 0, _FlexWeights) ->
    Sizes;
distribute_flex(Sizes, _Remaining, []) ->
    Sizes;
distribute_flex(Sizes, Remaining, FlexWeights) ->
    TotalWeight = lists:sum([F || {F, _} <- FlexWeights]),
    case TotalWeight of
        0 -> Sizes;
        _ ->
            lists:foldl(
                fun({F, Index}, Acc) ->
                    Share = (Remaining * F) div TotalWeight,
                    set_nth(Index, Share, Acc)
                end,
                Sizes,
                FlexWeights)
    end.

-spec apply_max([non_neg_integer()], [constraint()]) -> [non_neg_integer()].
apply_max(Sizes, Constraints) ->
    lists:zipwith(
        fun(Size, {max, N}) -> min(Size, N);
           (Size, _) -> Size
        end,
        Sizes,
        Constraints).

-spec offsets_from(non_neg_integer(), [non_neg_integer()]) -> [non_neg_integer()].
offsets_from(Start, Sizes) ->
    {Offsets, _} = lists:mapfoldl(
        fun(Size, Acc) -> {Acc, Acc + Size} end,
        Start,
        Sizes),
    Offsets.

-spec space_between_offsets(non_neg_integer(), [non_neg_integer()], non_neg_integer()) ->
    [non_neg_integer()].
space_between_offsets(_Start, [], _Gap) -> [];
space_between_offsets(Start, [Size | Rest], Gap) ->
    [Start | space_between_offsets(Start + Size + Gap, Rest, Gap)].

-spec set_nth(non_neg_integer(), non_neg_integer(), [term()]) -> [term()].
set_nth(Index, Value, List) ->
    set_nth(Index, Value, List, 0, []).

-spec set_nth(non_neg_integer(), non_neg_integer(), [term()], non_neg_integer(),
    [term()]) -> [term()].
set_nth(Index, Value, [_H | T], I, Acc) when I =:= Index ->
    lists:reverse(Acc, [Value | T]);
set_nth(Index, Value, [H | T], I, Acc) ->
    set_nth(Index, Value, T, I + 1, [H | Acc]);
set_nth(_Index, _Value, [], _I, Acc) ->
    lists:reverse(Acc).
