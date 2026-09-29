%% @doc Form demo component with two text inputs, used by interaction tests.
-module(dui_form).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{msgs => []}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = custom, key = shortcut, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(focus_email, State) ->
    {State, [educkui_command:focus(email_input)]};
update(Msg, State) ->
    {State#{msgs := maps:get(msgs, State) ++ [Msg]}, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"Tab to switch, type to edit, Esc to quit">>),
        educkui_render_node:component(name_input, educkui_widget_text_input,
                                      #{value => <<"Alice">>}),
        educkui_render_node:component(email_input, educkui_widget_text_input,
                                      #{value => <<>>})
    ]).
