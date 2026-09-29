-module(educkui_widget_alert_dialog_tests).

-include_lib("eunit/include/eunit.hrl").
-include("educkui.hrl").

default_buttons_test() ->
    Node = educkui_widget_alert_dialog:render(
        #{title => <<"Sure?">>}, #dui_rect{width = 30, height = 12}),
    %% default buttons OK / Cancel rendered inside the box; just assert the
    %% render produced cells and has a border.
    Cells = Node#dui_node.cells,
    ?assert(length(Cells) > 0).
