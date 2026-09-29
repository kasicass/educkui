%% @doc Form demo with two stateful text inputs.
%%
%% Demonstrates the interaction loop: Tab switches focus, typing edits the
%% focused field, mouse click focuses a field, Esc quits.
%%
%% Build:  rebar3 compile
%% Run:    ./examples/form/run.sh
-module(dui_form).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(_Msg, State) -> {State, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Form demo: Tab to switch, type to edit, Esc to quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:text(<<"Name:">>),
        educkui_render_node:component(name_input, educkui_widget_text_input,
                                      #{value => <<"Alice">>}),
        educkui_render_node:text(<<"">>),
        educkui_render_node:text(<<"Email:">>),
        educkui_render_node:component(email_input, educkui_widget_text_input,
                                      #{value => <<>>})
    ]).
