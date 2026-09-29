-module(educkui_widget_form_builder_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

fields() ->
    [#{id => username, type => text, label => <<"Username">>, required => true},
     #{id => password, type => password, label => <<"Password">>},
     #{id => remember, type => checkbox, label => <<"Remember me">>},
     #{id => role, type => radio, label => <<"Role">>,
       options => [{admin, <<"Admin">>}, {user, <<"User">>}]},
     #{id => country, type => select, label => <<"Country">>,
       options => [{us, <<"United States">>}, {ca, <<"Canada">>}]},
     #{id => interests, type => multi_select, label => <<"Interests">>,
       options => [{tech, <<"Tech">>}, {music, <<"Music">>}]}].

init_defaults_test() ->
    S = educkui_widget_form_builder:init([{fields, fields()}]),
    ?assertEqual(username, maps:get(focused_field, S)),
    ?assertEqual(<<"">>, maps:get(username, maps:get(values, S))),
    ?assertEqual(false, maps:get(remember, maps:get(values, S))),
    ?assertEqual(admin, maps:get(role, maps:get(values, S))),
    ?assertEqual(us, maps:get(country, maps:get(values, S))),
    ?assertEqual([], maps:get(interests, maps:get(values, S))),
    ?assertEqual(#{}, maps:get(errors, S)),
    ?assertEqual(true, maps:get(show_submit_button, S)).

init_initial_values_test() ->
    S = educkui_widget_form_builder:init(
        [{fields, fields()}, {values, #{username => <<"alice">>, remember => true}}]),
    ?assertEqual(<<"alice">>, maps:get(username, maps:get(values, S))),
    ?assertEqual(true, maps:get(remember, maps:get(values, S))).

text_insert_and_backspace_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    {msg, {char, <<"a">>}} =
        educkui_widget_form_builder:event_to_msg(
            educkui_event:key(<<"a">>, [{char, <<"a">>}]), S0),
    {S1, []} = educkui_widget_form_builder:update({char, <<"a">>}, S0),
    ?assertEqual(<<"a">>, maps:get(username, maps:get(values, S1))),
    {S2, []} = educkui_widget_form_builder:update({char, <<"b">>}, S1),
    ?assertEqual(<<"ab">>, maps:get(username, maps:get(values, S2))),
    ?assertEqual(2, maps:get(cursor, S2)),
    {S3, []} = educkui_widget_form_builder:update(backspace, S2),
    ?assertEqual(<<"a">>, maps:get(username, maps:get(values, S3))),
    ?assertEqual(1, maps:get(cursor, S3)).

checkbox_toggle_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    {S1, []} = educkui_widget_form_builder:update(down, S0),
    {S2, []} = educkui_widget_form_builder:update(down, S1),
    ?assertEqual(remember, maps:get(focused_field, S2)),
    {S3, []} = educkui_widget_form_builder:update(space, S2),
    ?assertEqual(true, maps:get(remember, maps:get(values, S3))),
    {S4, []} = educkui_widget_form_builder:update(space, S3),
    ?assertEqual(false, maps:get(remember, maps:get(values, S4))).

radio_navigation_and_select_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    %% Move from username -> password -> remember -> role (4th field).
    {S1, []} = educkui_widget_form_builder:update(down, S0),
    {S2, []} = educkui_widget_form_builder:update(down, S1),
    {S3, []} = educkui_widget_form_builder:update(down, S2),
    ?assertEqual(role, maps:get(focused_field, S3)),
    %% Radio field has options; right navigates options, not fields.
    {S4, []} = educkui_widget_form_builder:update(right, S3),
    ?assertEqual(1, maps:get(focused_option, S4)),
    ?assertEqual(role, maps:get(focused_field, S4)),
    {S5, []} = educkui_widget_form_builder:update(space, S4),
    ?assertEqual(user, maps:get(role, maps:get(values, S5))).

select_enter_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    %% Navigate to country (5th field): username -> password -> remember -> role -> country.
    S1 = nav_down(S0, 4),
    ?assertEqual(country, maps:get(focused_field, S1)),
    {S2, []} = educkui_widget_form_builder:update(right, S1),
    ?assertEqual(1, maps:get(focused_option, S2)),
    {S3, []} = educkui_widget_form_builder:update(enter, S2),
    ?assertEqual(ca, maps:get(country, maps:get(values, S3))),
    ?assertEqual(country, maps:get(focused_field, S3)).

multi_select_toggle_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    %% Navigate to interests (6th field).
    S1 = nav_down(S0, 5),
    ?assertEqual(interests, maps:get(focused_field, S1)),
    {S2, []} = educkui_widget_form_builder:update(space, S1),
    ?assertEqual([tech], maps:get(interests, maps:get(values, S2))),
    {S3, []} = educkui_widget_form_builder:update(right, S2),
    {S4, []} = educkui_widget_form_builder:update(space, S3),
    ?assertEqual([music, tech], maps:get(interests, maps:get(values, S4))),
    {S5, []} = educkui_widget_form_builder:update(space, S4),
    ?assertEqual([tech], maps:get(interests, maps:get(values, S5))).

required_validation_on_submit_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    %% Navigate to submit button (6 fields + submit).
    S1 = nav_down(S0, 6),
    ?assertEqual(true, maps:get(submit_focused, S1)),
    {S2, Cmds} = educkui_widget_form_builder:update(enter, S1),
    ?assertEqual([], Cmds),
    Errors = maps:get(errors, S2),
    ?assertNotEqual([], maps:get(username, Errors, [])),
    ?assertEqual([], maps:get(password, Errors, [])).

valid_submit_emits_parent_command_test() ->
    S0 = educkui_widget_form_builder:init(
        [{fields, fields()}, {values, #{username => <<"alice">>}}]),
    S1 = nav_down(S0, 6),
    {_S2, Cmds} = educkui_widget_form_builder:update(enter, S1),
    ?assertMatch([{parent, {form_submit, #{username := <<"alice">>}}}], Cmds).

on_submit_fun_test() ->
    Parent = self(),
    S0 = educkui_widget_form_builder:init(
        [{fields, fields()},
         {values, #{username => <<"alice">>}},
         {on_submit, fun(V) -> Parent ! {submitted, maps:get(username, V)} end}]),
    S1 = nav_down(S0, 6),
    {_S2, [_ExecCmd]} = educkui_widget_form_builder:update(enter, S1),
    ?assertMatch({exec, _}, _ExecCmd).

on_change_fun_test() ->
    S0 = educkui_widget_form_builder:init(
        [{fields, fields()},
         {on_change, fun(Id, Value) -> self() ! {changed, Id, Value} end}]),
    {_S1, [_ExecCmd]} = educkui_widget_form_builder:update({char, <<"a">>}, S0),
    ?assertMatch({exec, _}, _ExecCmd).

conditional_field_test() ->
    Fields = [#{id => name, type => text, label => <<"Name">>},
              #{id => nickname, type => text, label => <<"Nickname">>,
                visible_when => fun(Values) -> maps:get(name, Values) =/= <<>> end}],
    S0 = educkui_widget_form_builder:init([{fields, Fields}]),
    ?assertEqual(name, maps:get(focused_field, S0)),
    %% Fill name so nickname becomes visible.
    {S1, []} = educkui_widget_form_builder:update({char, <<"a">>}, S0),
    {S2, []} = educkui_widget_form_builder:update(down, S1),
    ?assertEqual(nickname, maps:get(focused_field, S2)).

password_masking_view_test() ->
    S0 = educkui_widget_form_builder:init([{fields, fields()}]),
    {S1, []} = educkui_widget_form_builder:update(down, S0),
    ?assertEqual(password, maps:get(focused_field, S1)),
    {S2, []} = educkui_widget_form_builder:update({char, <<"s">>}, S1),
    Node = educkui_widget_form_builder:view(S2),
    ?assertEqual(stack, Node#dui_node.type).

view_structure_test() ->
    S = educkui_widget_form_builder:init([{fields, fields()}]),
    Node = educkui_widget_form_builder:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    %% 6 field rows + 1 submit row.
    ?assertEqual(7, length(Node#dui_node.children)).

group_header_test() ->
    Fields = [#{id => a, type => text, label => <<"A">>, group => general},
              #{id => b, type => text, label => <<"B">>, group => general},
              #{id => c, type => text, label => <<"C">>, group => extra}],
    S = educkui_widget_form_builder:init(
        [{fields, Fields},
         {groups, [#{id => general, label => <<"General">>},
                   #{id => extra, label => <<"Extra">>}]}]),
    Node = educkui_widget_form_builder:view(S),
    %% 2 group headers + 3 field rows + 1 submit row.
    ?assertEqual(6, length(Node#dui_node.children)).

%% Helpers

nav_down(S, 0) -> S;
nav_down(S, N) ->
    {S1, []} = educkui_widget_form_builder:update(down, S),
    nav_down(S1, N - 1).
