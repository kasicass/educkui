-module(educkui_config_tests).

-include_lib("eunit/include/eunit.hrl").

merge_options_precedence_test() ->
    application:set_env(educkui, render_interval, 100),
    try
        Merged = educkui_config:merge_options(
            [{render_interval, 50}, {root, my_app}]),
        ?assertEqual(50, proplists:get_value(render_interval, Merged)),
        ?assertEqual(my_app, proplists:get_value(root, Merged)),
        ?assertEqual(100, proplists:get_value(render_interval,
                                              educkui_config:merge_options([])))
    after
        application:unset_env(educkui, render_interval)
    end.

get_test() ->
    Opts = [{a, 1}],
    ?assertEqual(1, educkui_config:get(a, Opts)),
    ?assertEqual(default, educkui_config:get(b, Opts, default)).
