%% @doc Alert dialog showcase: OK/Cancel confirmation.
-module(dui_alert).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{show => false}.

event_to_msg(#dui_event{type = key, key = esc}, State) ->
    case maps:get(show, State) of
        true -> {msg, close_dialog};
        false -> {msg, quit}
    end;
event_to_msg(#dui_event{type = custom, key = shortcut, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) ->
    {State, [educkui_command:quit()]};
update(open_dialog, State) ->
    {State#{show := true}, [{focus, {dui_dialog_button, <<"OK">>}}]};
update(close_dialog, State) ->
    {State#{show := false}, []};
update(toggle_dialog, State) ->
    case maps:get(show, State) of
        true -> update(close_dialog, State);
        false -> update(open_dialog, State)
    end;
update({button, {dui_dialog_button, _Label}}, State) ->
    {State#{show := false}, []};
update(_Msg, State) ->
    {State, []}.

view(State) ->
    Base = base_view(),
    case maps:get(show, State) of
        true -> educkui_render_node:overlay([Base, dialog_view()]);
        false -> Base
    end.

base_view() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Alert dialog - Ctrl+A open, Enter/Space activate, Esc close/quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:text(
            <<"Press Ctrl+A to ask for confirmation.">>)
    ]).

dialog_view() ->
    educkui_render_node:widget(educkui_widget_alert_dialog, #{
        title => <<"Delete file?">>,
        content => <<"This action cannot be undone.">>,
        width => 40,
        height => 8
    }).
