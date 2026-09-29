%% @doc Supervision tree viewer showcase: lists the running applications.
-module(dui_supervision).

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
        educkui_render_node:text(<<"Applications - Esc to quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:widget(educkui_widget_supervision_tree_viewer,
                                   #{tree => collect_apps()})
    ]).

collect_apps() ->
    Apps = lists:sort(
        fun({A, _, _}, {B, _, _}) -> A =< B end,
        application:which_applications()),
    [{label(Name, Vsn), []} || {Name, _Desc, Vsn} <- Apps].

label(Name, Vsn) ->
    iolist_to_binary([atom_to_binary(Name, utf8), <<" (">>, Vsn, <<")">>]).
