%% @doc Layout constraint constructors.
-module(educkui_layout_constraint).

-export([fixed/1, min/1, max/1, flex/1]).

-type constraint() ::
    {fixed, non_neg_integer()}
    | {min, non_neg_integer()}
    | {max, non_neg_integer()}
    | {flex, pos_integer()}.
-export_type([constraint/0]).

-spec fixed(non_neg_integer()) -> {fixed, non_neg_integer()}.
fixed(N) -> {fixed, N}.

-spec min(non_neg_integer()) -> {min, non_neg_integer()}.
min(N) -> {min, N}.

-spec max(non_neg_integer()) -> {max, non_neg_integer()}.
max(N) -> {max, N}.

-spec flex(pos_integer()) -> {flex, pos_integer()}.
flex(N) -> {flex, N}.
