%% @doc A stateless canvas widget for direct cell drawing.
%%
%% Props: `{pixels, [{X, Y, Char}]}` where X/Y are 0-based coordinates relative
%% to the widget's rect and Char is a binary grapheme.
-module(educkui_widget_canvas).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Pixels = maps:get(pixels, Props, []),
    Cells = [{X, Y, educkui_cell:new(Char)} || {X, Y, Char} <- Pixels],
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Canvas">>, description => <<"A direct drawing surface">>}.

-spec default_props() -> map().
default_props() ->
    #{pixels => []}.
