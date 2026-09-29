%% @doc Canvas showcase: direct cell drawing.
-module(dui_canvas).

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
        educkui_render_node:text(<<"Canvas - Esc to quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        educkui_render_node:widget(educkui_widget_canvas, #{pixels => duck()})
    ]).

%% A small box drawn with block characters.
duck() ->
    W = 21,
    H = 6,
    Top = [{X, 0, <<"█">>} || X <- lists:seq(0, W - 1)],
    Bottom = [{X, H - 1, <<"█">>} || X <- lists:seq(0, W - 1)],
    Left = [{0, Y, <<"█">>} || Y <- lists:seq(1, H - 2)],
    Right = [{W - 1, Y, <<"█">>} || Y <- lists:seq(1, H - 2)],
    Inner = [{X, Y, <<".">>} || Y <- lists:seq(1, H - 2), X <- lists:seq(1, W - 2)],
    Top ++ Bottom ++ Left ++ Right ++ Inner.
