-module(educkui_widget_command_palette_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

commands() ->
    [{<<"Open file">>, open_file},
     {<<"Save file">>, save_file},
     {<<"Quit">>, quit}].

filter_test() ->
    S0 = educkui_widget_command_palette:init([{commands, commands()}]),
    {S1, []} = educkui_widget_command_palette:update({filter_char, <<"file">>}, S0),
    %% "file" matches Open file and Save file.
    Filtered = filter(S1),
    ?assertEqual([open_file, save_file],
                 [P || {_L, P} <- Filtered]).

activate_test() ->
    S0 = educkui_widget_command_palette:init([{commands, commands()}]),
    {S1, []} = educkui_widget_command_palette:update(down, S0),
    {S2, [{parent, {command, save_file}}]} =
        educkui_widget_command_palette:update(activate, S1),
    ?assertEqual(1, maps:get(highlight, S2)).

view_test() ->
    S = educkui_widget_command_palette:init([{commands, commands()}]),
    Node = educkui_widget_command_palette:view(S),
    ?assertEqual(stack, Node#dui_node.type),
    ?assertEqual(4, length(Node#dui_node.children)).

filter(S) ->
    Commands = maps:get(commands, S),
    F = string:lowercase(maps:get(filter, S)),
    [{L, P} || {L, P} <- Commands,
        F =:= <<>> orelse string:find(string:lowercase(L), F) =/= nomatch].
