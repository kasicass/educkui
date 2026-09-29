-module(educkui_style_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

new_test() ->
    S = educkui_style:new(),
    ?assertEqual(undefined, educkui_style:fg(S)),
    ?assertEqual(undefined, educkui_style:bg(S)),
    ?assertEqual([], educkui_style:attrs(S)).

from_list_test() ->
    S = educkui_style:from([{fg, blue}, {bg, white}, {bold, true}, {underline, true}]),
    ?assertEqual(blue, educkui_style:fg(S)),
    ?assertEqual(white, educkui_style:bg(S)),
    ?assert(educkui_style:has_attr(S, bold)),
    ?assert(educkui_style:has_attr(S, underline)),
    ?assertNot(educkui_style:has_attr(S, italic)).

from_map_test() ->
    S = educkui_style:from(#{fg => red, attrs => [bold, blink]}),
    ?assertEqual(red, educkui_style:fg(S)),
    ?assert(educkui_style:has_attr(S, bold)),
    ?assert(educkui_style:has_attr(S, blink)).

setters_test() ->
    S0 = educkui_style:new(),
    S1 = educkui_style:fg(S0, cyan),
    ?assertEqual(cyan, educkui_style:fg(S1)),
    ?assertEqual(undefined, educkui_style:fg(S0)),
    S2 = educkui_style:bg(S1, magenta),
    ?assertEqual(magenta, educkui_style:bg(S2)).

attr_ops_test() ->
    S = educkui_style:new(),
    S1 = educkui_style:bold(S),
    ?assert(educkui_style:has_attr(S1, bold)),
    S2 = educkui_style:remove_attr(S1, bold),
    ?assertNot(educkui_style:has_attr(S2, bold)),
    S3 = educkui_style:bold(educkui_style:bold(S)),
    ?assertEqual(1, length(educkui_style:attrs(S3))),
    S4 = educkui_style:clear_attrs(S3),
    ?assertEqual([], educkui_style:attrs(S4)).

merge_test() ->
    Base = educkui_style:from([{fg, white}, {bold, true}]),
    Override = educkui_style:from([{fg, red}, {underline, true}]),
    M = educkui_style:merge(Base, Override),
    ?assertEqual(red, educkui_style:fg(M)),
    ?assertEqual(undefined, educkui_style:bg(M)),
    ?assert(educkui_style:has_attr(M, bold)),
    ?assert(educkui_style:has_attr(M, underline)).

merge_keeps_base_when_override_unset_test() ->
    Base = educkui_style:from([{fg, white}]),
    Override = educkui_style:from([{underline, true}]),
    M = educkui_style:merge(Base, Override),
    ?assertEqual(white, educkui_style:fg(M)),
    ?assert(educkui_style:has_attr(M, underline)).

inherit_test() ->
    Parent = educkui_style:from([{fg, green}, {bg, black}, {bold, true}]),
    Child = educkui_style:from([{fg, red}]),
    I = educkui_style:inherit(Child, Parent),
    ?assertEqual(red, educkui_style:fg(I)),
    ?assertEqual(black, educkui_style:bg(I)),
    ?assert(educkui_style:has_attr(I, bold)).

variants_test() ->
    Normal = educkui_style:from([{fg, white}]),
    Focused = educkui_style:from([{fg, blue}, {bold, true}]),
    Variants = #{normal => Normal, focused => Focused},
    ?assert(educkui_style:equal(Focused, educkui_style:get_variant(Variants, focused))),
    ?assert(educkui_style:equal(Normal, educkui_style:get_variant(Variants, missing))),
    Empty = #{},
    ?assert(educkui_style:equal(educkui_style:new(), educkui_style:get_variant(Empty, anything))).

create_variant_test() ->
    Normal = educkui_style:from([{fg, white}]),
    V = educkui_style:from([{fg, blue}]),
    Created = educkui_style:create_variant(Normal, V),
    ?assertEqual(blue, educkui_style:fg(Created)).

equal_test() ->
    A = educkui_style:from([{fg, red}, {bold, true}]),
    B = educkui_style:from([{bold, true}, {fg, red}]),
    C = educkui_style:from([{fg, blue}, {bold, true}]),
    ?assert(educkui_style:equal(A, B)),
    ?assertNot(educkui_style:equal(A, C)).
