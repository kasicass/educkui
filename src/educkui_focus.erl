%% @doc Focus management.
%%
%% Focus is represented as a stack of component ids (most recently focused
%% first). Traversal helpers move focus through an ordered list of focusable
%% ids.
-module(educkui_focus).

-export([new/0, current/1, focus/2, blur/1, next/2, prev/2, index_of/2]).

-type focus_stack() :: [term()].
-export_type([focus_stack/0]).

-spec new() -> focus_stack().
new() -> [].

-spec current(focus_stack()) -> term() | undefined.
current([]) -> undefined;
current([Head | _]) -> Head.

-spec focus(focus_stack(), term()) -> focus_stack().
focus(Stack, Id) -> [Id | Stack].

-spec blur(focus_stack()) -> focus_stack().
blur([]) -> [];
blur([_ | Rest]) -> Rest.

%% @doc Moves focus to the next id in `Ids' (wrapping around).
-spec next(focus_stack(), [term()]) -> focus_stack().
next(Stack, []) -> Stack;
next(Stack, Ids) ->
    case current(Stack) of
        undefined -> [hd(Ids)];
        Cur ->
            case index_of(Cur, Ids) of
                undefined -> [hd(Ids)];
                I -> [lists:nth((I rem length(Ids)) + 1, Ids)]
            end
    end.

%% @doc Moves focus to the previous id in `Ids' (wrapping around).
-spec prev(focus_stack(), [term()]) -> focus_stack().
prev(Stack, []) -> Stack;
prev(Stack, Ids) ->
    case current(Stack) of
        undefined -> [lists:last(Ids)];
        Cur ->
            case index_of(Cur, Ids) of
                undefined -> [lists:last(Ids)];
                1 -> [lists:last(Ids)];
                I -> [lists:nth(I - 1, Ids)]
            end
    end.

-spec index_of(term(), [term()]) -> pos_integer() | undefined.
index_of(Id, Ids) ->
    case index_of(Id, Ids, 1) of
        0 -> undefined;
        I -> I
    end.

-spec index_of(term(), [term()], pos_integer()) -> non_neg_integer().
index_of(_Id, [], _N) -> 0;
index_of(Id, [Id | _], N) -> N;
index_of(Id, [_ | Rest], N) -> index_of(Id, Rest, N + 1).
