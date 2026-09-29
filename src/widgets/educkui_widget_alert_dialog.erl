%% @doc A stateless alert dialog (a dialog with OK/Cancel buttons by default).
-module(educkui_widget_alert_dialog).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Buttons = maps:get(buttons, Props, [<<"OK">>, <<"Cancel">>]),
    educkui_widget_dialog:render(maps:put(buttons, Buttons, Props), Rect).

-spec describe() -> map().
describe() ->
    #{name => <<"AlertDialog">>,
      description => <<"A confirmation dialog widget">>}.

-spec default_props() -> map().
default_props() ->
    Props = educkui_widget_dialog:default_props(),
    Props#{buttons := [<<"OK">>, <<"Cancel">>]}.
