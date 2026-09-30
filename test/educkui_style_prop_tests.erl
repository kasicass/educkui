%% @doc Property-style tests for educkui_style.
%%
%% Randomized checks with a fixed seed (no external PropEr dependency).
-module(educkui_style_prop_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

attrs_ordset_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) ->
            Style = random_style_ops(20),
            ?assertEqual(ordsets:from_list(Style#dui_style.attrs),
                         Style#dui_style.attrs)
        end,
        lists:seq(1, 200)).

add_remove_attr_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) ->
            Attr = educkui_prop_utils:rand_choice(
                [bold, dim, italic, underline, blink, reverse, hidden,
                 strikethrough]),
            S0 = educkui_style:new(),
            S1 = educkui_style:add_attr(S0, Attr),
            ?assert(educkui_style:has_attr(S1, Attr)),
            S2 = educkui_style:remove_attr(S1, Attr),
            ?assertNot(educkui_style:has_attr(S2, Attr))
        end,
        lists:seq(1, 100)).

merge_reset_prop_test() ->
    ok = educkui_prop_utils:seed(),
    lists:foreach(
        fun(_) ->
            Style = random_style_ops(20),
            ?assert(educkui_style:equal(
                Style, educkui_style:merge(Style, educkui_style:new()))),
            ?assert(educkui_style:equal(
                educkui_style:new(), educkui_style:reset(Style)))
        end,
        lists:seq(1, 100)).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec random_style_ops(non_neg_integer()) -> #dui_style{}.
random_style_ops(0) ->
    educkui_style:new();
random_style_ops(N) ->
    Style = random_style_ops(N - 1),
    Op = educkui_prop_utils:rand_choice([add_attr, remove_attr, fg, bg]),
    case Op of
        add_attr ->
            educkui_style:add_attr(
                Style, educkui_prop_utils:rand_choice(
                    [bold, dim, italic, underline, blink, reverse, hidden,
                     strikethrough]));
        remove_attr ->
            educkui_style:remove_attr(
                Style, educkui_prop_utils:rand_choice(
                    [bold, dim, italic, underline, blink, reverse, hidden,
                     strikethrough]));
        fg ->
            educkui_style:fg(Style, educkui_prop_utils:rand_choice(
                [default, red, green, 5, {10, 20, 30}]));
        bg ->
            educkui_style:bg(Style, educkui_prop_utils:rand_choice(
                [default, blue, cyan, 17, {1, 2, 3}]))
    end.
