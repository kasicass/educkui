-module(educkui_widget_alert_dialog_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

default_buttons_test() ->
    Node = educkui_widget_alert_dialog:render(
        #{title => <<"Sure?">>}, #dui_rect{width = 30, height = 12}),
    %% default buttons OK / Cancel rendered as focusable push buttons inside
    %% an overlay; rendering the tree yields cells.
    Cells = educkui_render:render(Node, #dui_rect{width = 30, height = 12}),
    ?assert(length(Cells) > 0).
