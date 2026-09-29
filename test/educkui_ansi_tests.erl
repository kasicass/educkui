-module(educkui_ansi_tests).

-include_lib("eunit/include/eunit.hrl").

cursor_position_test() ->
    ?assertEqual(<<"\e[5;10H">>, iolist_to_binary(educkui_ansi:cursor_position(5, 10))),
    ?assertEqual(<<"\e[1;1H">>, iolist_to_binary(educkui_ansi:cursor_position(1, 1))).

cursor_movement_test() ->
    ?assertEqual(<<"\e[A">>, iolist_to_binary(educkui_ansi:cursor_up())),
    ?assertEqual(<<"\e[3A">>, iolist_to_binary(educkui_ansi:cursor_up(3))),
    ?assertEqual(<<"\e[B">>, iolist_to_binary(educkui_ansi:cursor_down())),
    ?assertEqual(<<"\e[2B">>, iolist_to_binary(educkui_ansi:cursor_down(2))),
    ?assertEqual(<<"\e[C">>, iolist_to_binary(educkui_ansi:cursor_forward())),
    ?assertEqual(<<"\e[4C">>, iolist_to_binary(educkui_ansi:cursor_forward(4))),
    ?assertEqual(<<"\e[D">>, iolist_to_binary(educkui_ansi:cursor_back())),
    ?assertEqual(<<"\e[1D">>, iolist_to_binary(educkui_ansi:cursor_back(1))).

cursor_visibility_test() ->
    ?assertEqual(<<"\e[?25h">>, iolist_to_binary(educkui_ansi:cursor_show())),
    ?assertEqual(<<"\e[?25l">>, iolist_to_binary(educkui_ansi:cursor_hide())),
    ?assertEqual(<<"\e[s">>, iolist_to_binary(educkui_ansi:save_cursor())),
    ?assertEqual(<<"\e[u">>, iolist_to_binary(educkui_ansi:restore_cursor())).

screen_ops_test() ->
    ?assertEqual(<<"\e[2J">>, iolist_to_binary(educkui_ansi:clear_screen())),
    ?assertEqual(<<"\e[0J">>, iolist_to_binary(educkui_ansi:clear_screen_from_cursor())),
    ?assertEqual(<<"\e[1J">>, iolist_to_binary(educkui_ansi:clear_screen_to_cursor())),
    ?assertEqual(<<"\e[2K">>, iolist_to_binary(educkui_ansi:clear_line())),
    ?assertEqual(<<"\e[K">>, iolist_to_binary(educkui_ansi:clear_line_from_cursor())),
    ?assertEqual(<<"\e[1K">>, iolist_to_binary(educkui_ansi:clear_line_to_cursor())),
    ?assertEqual(<<"\e[5;20r">>, iolist_to_binary(educkui_ansi:set_scroll_region(5, 20))),
    ?assertEqual(<<"\e[S">>, iolist_to_binary(educkui_ansi:scroll_up())),
    ?assertEqual(<<"\e[3S">>, iolist_to_binary(educkui_ansi:scroll_up(3))),
    ?assertEqual(<<"\e[T">>, iolist_to_binary(educkui_ansi:scroll_down())),
    ?assertEqual(<<"\e[2T">>, iolist_to_binary(educkui_ansi:scroll_down(2))).

colors_test() ->
    ?assertEqual(<<"\e[31m">>, iolist_to_binary(educkui_ansi:foreground(red))),
    ?assertEqual(<<"\e[94m">>, iolist_to_binary(educkui_ansi:foreground(bright_blue))),
    ?assertEqual(<<"\e[39m">>, iolist_to_binary(educkui_ansi:foreground(default))),
    ?assertEqual(<<"\e[44m">>, iolist_to_binary(educkui_ansi:background(blue))),
    ?assertEqual(<<"\e[101m">>, iolist_to_binary(educkui_ansi:background(bright_red))),
    ?assertEqual(<<"\e[38;5;196m">>, iolist_to_binary(educkui_ansi:foreground_256(196))),
    ?assertEqual(<<"\e[48;5;21m">>, iolist_to_binary(educkui_ansi:background_256(21))),
    ?assertEqual(<<"\e[38;2;255;128;0m">>,
                 iolist_to_binary(educkui_ansi:foreground_rgb(255, 128, 0))),
    ?assertEqual(<<"\e[48;2;1;2;3m">>,
                 iolist_to_binary(educkui_ansi:background_rgb(1, 2, 3))).

attributes_test() ->
    ?assertEqual(<<"\e[1m">>, iolist_to_binary(educkui_ansi:bold())),
    ?assertEqual(<<"\e[2m">>, iolist_to_binary(educkui_ansi:dim())),
    ?assertEqual(<<"\e[3m">>, iolist_to_binary(educkui_ansi:italic())),
    ?assertEqual(<<"\e[4m">>, iolist_to_binary(educkui_ansi:underline())),
    ?assertEqual(<<"\e[5m">>, iolist_to_binary(educkui_ansi:blink())),
    ?assertEqual(<<"\e[7m">>, iolist_to_binary(educkui_ansi:reverse())),
    ?assertEqual(<<"\e[8m">>, iolist_to_binary(educkui_ansi:hidden())),
    ?assertEqual(<<"\e[9m">>, iolist_to_binary(educkui_ansi:strikethrough())),
    ?assertEqual(<<"\e[0m">>, iolist_to_binary(educkui_ansi:reset())),
    ?assertEqual(<<"\e[0m">>, iolist_to_binary(educkui_ansi:reset_style())).

format_test() ->
    ?assertEqual(<<>>, iolist_to_binary(educkui_ansi:format([]))),
    ?assertEqual(<<"\e[1;31m">>, iolist_to_binary(educkui_ansi:format([bold, red]))),
    ?assertEqual(<<"\e[4;94;43m">>,
                 iolist_to_binary(educkui_ansi:format([underline, bright_blue, bg_yellow]))).

special_modes_test() ->
    ?assertEqual(<<"\e[?2004h">>, iolist_to_binary(educkui_ansi:enable_bracketed_paste())),
    ?assertEqual(<<"\e[?2004l">>, iolist_to_binary(educkui_ansi:disable_bracketed_paste())),
    ?assertEqual(<<"\e[?1004h">>, iolist_to_binary(educkui_ansi:enable_focus_events())),
    ?assertEqual(<<"\e[?1004l">>, iolist_to_binary(educkui_ansi:disable_focus_events())),
    ?assertEqual(<<"\e[?1h">>, iolist_to_binary(educkui_ansi:enable_app_cursor())),
    ?assertEqual(<<"\e[?1l">>, iolist_to_binary(educkui_ansi:disable_app_cursor())).

mouse_modes_test() ->
    ?assertEqual(<<"\e[?9h">>, iolist_to_binary(educkui_ansi:enable_mouse_tracking(x10))),
    ?assertEqual(<<"\e[?1000h">>, iolist_to_binary(educkui_ansi:enable_mouse_tracking(normal))),
    ?assertEqual(<<"\e[?1002h">>, iolist_to_binary(educkui_ansi:enable_mouse_tracking(button))),
    ?assertEqual(<<"\e[?1003h">>, iolist_to_binary(educkui_ansi:enable_mouse_tracking(all))),
    ?assertEqual(<<"\e[?9l">>, iolist_to_binary(educkui_ansi:disable_mouse_tracking(x10))),
    ?assertEqual(<<"\e[?1000l">>, iolist_to_binary(educkui_ansi:disable_mouse_tracking(normal))),
    ?assertEqual(<<"\e[?1002l">>, iolist_to_binary(educkui_ansi:disable_mouse_tracking(button))),
    ?assertEqual(<<"\e[?1003l">>, iolist_to_binary(educkui_ansi:disable_mouse_tracking(all))),
    ?assertEqual(<<"\e[?1006h">>, iolist_to_binary(educkui_ansi:enable_sgr_mouse())),
    ?assertEqual(<<"\e[?1006l">>, iolist_to_binary(educkui_ansi:disable_sgr_mouse())).

alternate_screen_test() ->
    ?assertEqual(<<"\e[?1049h">>, iolist_to_binary(educkui_ansi:enter_alternate_screen())),
    ?assertEqual(<<"\e[?1049l">>, iolist_to_binary(educkui_ansi:leave_alternate_screen())).
