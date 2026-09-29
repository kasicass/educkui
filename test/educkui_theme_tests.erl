-module(educkui_theme_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

put_get_test() ->
    Theme = educkui_theme:new(),
    Style = educkui_style:from([{fg, red}]),
    Theme2 = educkui_theme:put(Theme, primary, Style),
    ?assertEqual(Style, educkui_theme:get(Theme2, primary)),
    ?assertEqual(undefined, educkui_theme:get(Theme2, missing)),
    ?assertEqual(educkui_style:new(), educkui_theme:get(Theme2, missing, educkui_style:new())).

merge_test() ->
    S1 = educkui_style:from([{fg, red}]),
    S2 = educkui_style:from([{fg, blue}]),
    A = educkui_theme:put(educkui_theme:new(), x, S1),
    B = educkui_theme:put(educkui_theme:new(), x, S2),
    Merged = educkui_theme:merge(A, B),
    ?assertEqual(S2, educkui_theme:get(Merged, x)).

color_rgb_test() ->
    ?assertEqual({255, 0, 0}, educkui_theme:color_rgb(bright_red)),
    ?assertEqual({128, 0, 0}, educkui_theme:color_rgb(red)),
    ?assertEqual(16, length(educkui_theme:named_colors())).
