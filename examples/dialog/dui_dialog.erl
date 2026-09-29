%% @doc Dialog showcase: overlay dialog with focusable buttons, plus toast and
%% context menu widgets.
%%
%% Ctrl+D opens the dialog; Enter/Space activates the focused OK button;
%% Esc closes the dialog (or quits when no dialog is open).
-module(dui_dialog).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{show_dialog => false}.

event_to_msg(#dui_event{type = key, key = esc}, State) ->
    case maps:get(show_dialog, State) of
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
    {State#{show_dialog := true},
     [{focus, {dui_dialog_button, <<"OK">>}}]};
update(close_dialog, State) ->
    {State#{show_dialog := false}, []};
update(toggle_dialog, State) ->
    case maps:get(show_dialog, State) of
        true -> update(close_dialog, State);
        false -> update(open_dialog, State)
    end;
update({button, {dui_dialog_button, _Label}}, State) ->
    {State#{show_dialog := false}, []};
update(_Msg, State) ->
    {State, []}.

view(State) ->
    Base = base_view(),
    case maps:get(show_dialog, State) of
        true -> educkui_render_node:overlay([Base, dialog_view()]);
        false -> Base
    end.

base_view() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Dialog showcase - Ctrl+D open, Esc close/quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:widget(educkui_widget_context_menu, #{
            items => [<<"Copy">>, <<"Cut">>, <<"Paste">>, <<"Delete">>],
            selected => 0,
            x => 1,
            y => 2
        }),
        educkui_render_node:widget(educkui_widget_toast, #{
            message => <<"Changes saved">>
        })
    ]).

dialog_view() ->
    educkui_render_node:widget(educkui_widget_dialog, #{
        title => <<"Confirm">>,
        content => <<"Save your changes?">>,
        buttons => [<<"OK">>, <<"Cancel">>],
        width => 34,
        height => 7
    }).
