%% @doc A small ETS-backed layout cache.
%%
%% Caches layout results keyed by arbitrary terms. The caller owns the table
%% lifetime via `new/0' and `destroy/1'.
-module(educkui_layout_cache).

-export([new/0, lookup/2, store/3, destroy/1]).

-spec new() -> ets:tid().
new() ->
    ets:new(dui_layout_cache, [set, public]).

-spec lookup(ets:tid(), term()) -> {ok, term()} | miss.
lookup(Cache, Key) ->
    case ets:lookup(Cache, Key) of
        [{Key, Value}] -> {ok, Value};
        [] -> miss
    end.

-spec store(ets:tid(), term(), term()) -> ok.
store(Cache, Key, Value) ->
    ets:insert(Cache, {Key, Value}),
    ok.

-spec destroy(ets:tid()) -> ok.
destroy(Cache) ->
    ets:delete(Cache),
    ok.
