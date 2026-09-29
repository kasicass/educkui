-module(educkui_layout_cache_tests).

-include_lib("eunit/include/eunit.hrl").

store_lookup_test() ->
    Cache = educkui_layout_cache:new(),
    ?assertEqual(miss, educkui_layout_cache:lookup(Cache, key)),
    ok = educkui_layout_cache:store(Cache, key, value),
    ?assertEqual({ok, value}, educkui_layout_cache:lookup(Cache, key)),
    educkui_layout_cache:destroy(Cache).
