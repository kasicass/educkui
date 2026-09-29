%% @doc Basic stateless widgets: label, progress, list, button and block.
-module(dui_basic).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) -> #{}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update(_Msg, State) -> {State, []}.

view(_State) ->
    educkui_render_node:stack(vertical, [
        title(<<"Basic widgets - Esc to quit">>),
        text(<<"Label (centered, cyan):">>),
        wsized(educkui_widget_label,
               #{text => <<"Hello, educkui!">>, align => center,
                 style => #{fg => cyan}}, 30, 1),
        text(<<"Progress:">>),
        wsized(educkui_widget_progress, #{value => 0.6}, 30, 1),
        text(<<"List (selected item 1):">>),
        wsized(educkui_widget_list,
               #{items => [<<"apple">>, <<"banana">>, <<"cherry">>],
                 selected => 1, selected_style => #{reverse => true}}, 15, 3),
        text(<<"Buttons:">>),
        educkui_render_node:stack(horizontal, [
            wsized(educkui_widget_button, #{label => <<"OK">>, focused => true}, 10, 3),
            educkui_render_node:text(<<"  ">>),
            wsized(educkui_widget_button, #{label => <<"Cancel">>, focused => false}, 10, 3)
        ]),
        text(<<"Block with a label inside:">>),
        educkui_render_node:overlay([
            wsized(educkui_widget_block, #{border => true}, 20, 3),
            educkui_render_node:at(2, 1, text(<<"Inside the block">>))
        ])
    ]).

title(T) ->
    educkui_render_node:text(T, educkui_style:from([{fg, cyan}, {bold, true}])).

text(T) ->
    educkui_render_node:text(T).

wsized(Module, Props, W, H) ->
    educkui_render_node:height(
        educkui_render_node:width(
            educkui_render_node:widget(Module, Props), W),
        H).
