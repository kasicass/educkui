%% @doc ANSI escape sequence generation.
%%
%% All functions return iolists for efficient concatenation and writing
%% (see the OTP Efficiency Guide: avoid `lists:flatten/1', write deep iolists
%% directly with `io:put_chars/2').
-module(educkui_ansi).

-export([
    cursor_position/2,
    cursor_up/0, cursor_up/1,
    cursor_down/0, cursor_down/1,
    cursor_forward/0, cursor_forward/1,
    cursor_back/0, cursor_back/1,
    cursor_show/0, cursor_hide/0,
    save_cursor/0, restore_cursor/0,
    clear_screen/0,
    clear_screen_from_cursor/0, clear_screen_to_cursor/0,
    clear_line/0,
    clear_line_from_cursor/0, clear_line_to_cursor/0,
    set_scroll_region/2,
    scroll_up/0, scroll_up/1,
    scroll_down/0, scroll_down/1,
    foreground/1, background/1,
    foreground_256/1, background_256/1,
    foreground_rgb/3, background_rgb/3,
    bold/0, dim/0, italic/0, underline/0, blink/0,
    reverse/0, hidden/0, strikethrough/0,
    reset/0, reset_style/0, format/1,
    enable_bracketed_paste/0, disable_bracketed_paste/0,
    enable_focus_events/0, disable_focus_events/0,
    enable_app_cursor/0, disable_app_cursor/0,
    enable_mouse_tracking/1, disable_mouse_tracking/1,
    enable_sgr_mouse/0, disable_sgr_mouse/0,
    enter_alternate_screen/0, leave_alternate_screen/0,
    osc/2, set_title/1, clipboard/1, clipboard/2
]).

-define(CSI, "\e[").
-define(OSC, "\e]").
-define(BEL, "\x07").

-define(FOREGROUND_CODES, #{
    black => "30", red => "31", green => "32", yellow => "33",
    blue => "34", magenta => "35", cyan => "36", white => "37",
    default => "39",
    bright_black => "90", bright_red => "91", bright_green => "92",
    bright_yellow => "93", bright_blue => "94", bright_magenta => "95",
    bright_cyan => "96", bright_white => "97"
}).

-define(BACKGROUND_CODES, #{
    black => "40", red => "41", green => "42", yellow => "43",
    blue => "44", magenta => "45", cyan => "46", white => "47",
    default => "49",
    bright_black => "100", bright_red => "101", bright_green => "102",
    bright_yellow => "103", bright_blue => "104", bright_magenta => "105",
    bright_cyan => "106", bright_white => "107"
}).

-define(ATTRIBUTE_CODES, #{
    reset => "0",
    bold => "1", dim => "2", italic => "3", underline => "4",
    blink => "5", reverse => "7", hidden => "8", strikethrough => "9",
    black => "30", red => "31", green => "32", yellow => "33",
    blue => "34", magenta => "35", cyan => "36", white => "37",
    default => "39",
    bright_black => "90", bright_red => "91", bright_green => "92",
    bright_yellow => "93", bright_blue => "94", bright_magenta => "95",
    bright_cyan => "96", bright_white => "97",
    bg_black => "40", bg_red => "41", bg_green => "42", bg_yellow => "43",
    bg_blue => "44", bg_magenta => "45", bg_cyan => "46", bg_white => "47",
    bg_default => "49",
    bg_bright_black => "100", bg_bright_red => "101",
    bg_bright_green => "102", bg_bright_yellow => "103",
    bg_bright_blue => "104", bg_bright_magenta => "105",
    bg_bright_cyan => "106", bg_bright_white => "107"
}).

%% ---------------------------------------------------------------------------
%% Cursor control
%% ---------------------------------------------------------------------------

-spec cursor_position(pos_integer(), pos_integer()) -> iodata().
cursor_position(Row, Col)
        when is_integer(Row), Row > 0, is_integer(Col), Col > 0 ->
    [?CSI, integer_to_list(Row), ";", integer_to_list(Col), "H"].

-spec cursor_up() -> iodata().
cursor_up() -> [?CSI, "A"].

-spec cursor_up(pos_integer()) -> iodata().
cursor_up(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "A"].

-spec cursor_down() -> iodata().
cursor_down() -> [?CSI, "B"].

-spec cursor_down(pos_integer()) -> iodata().
cursor_down(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "B"].

-spec cursor_forward() -> iodata().
cursor_forward() -> [?CSI, "C"].

-spec cursor_forward(pos_integer()) -> iodata().
cursor_forward(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "C"].

-spec cursor_back() -> iodata().
cursor_back() -> [?CSI, "D"].

-spec cursor_back(pos_integer()) -> iodata().
cursor_back(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "D"].

-spec cursor_show() -> iodata().
cursor_show() -> [?CSI, "?25h"].

-spec cursor_hide() -> iodata().
cursor_hide() -> [?CSI, "?25l"].

-spec save_cursor() -> iodata().
save_cursor() -> [?CSI, "s"].

-spec restore_cursor() -> iodata().
restore_cursor() -> [?CSI, "u"].

%% ---------------------------------------------------------------------------
%% Screen manipulation
%% ---------------------------------------------------------------------------

-spec clear_screen() -> iodata().
clear_screen() -> [?CSI, "2J"].

-spec clear_screen_from_cursor() -> iodata().
clear_screen_from_cursor() -> [?CSI, "0J"].

-spec clear_screen_to_cursor() -> iodata().
clear_screen_to_cursor() -> [?CSI, "1J"].

-spec clear_line() -> iodata().
clear_line() -> [?CSI, "2K"].

-spec clear_line_from_cursor() -> iodata().
clear_line_from_cursor() -> [?CSI, "K"].

-spec clear_line_to_cursor() -> iodata().
clear_line_to_cursor() -> [?CSI, "1K"].

-spec set_scroll_region(pos_integer(), pos_integer()) -> iodata().
set_scroll_region(Top, Bottom)
        when is_integer(Top), Top > 0, is_integer(Bottom), Bottom > 0 ->
    [?CSI, integer_to_list(Top), ";", integer_to_list(Bottom), "r"].

-spec scroll_up() -> iodata().
scroll_up() -> [?CSI, "S"].

-spec scroll_up(pos_integer()) -> iodata().
scroll_up(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "S"].

-spec scroll_down() -> iodata().
scroll_down() -> [?CSI, "T"].

-spec scroll_down(pos_integer()) -> iodata().
scroll_down(N) when is_integer(N), N > 0 -> [?CSI, integer_to_list(N), "T"].

%% ---------------------------------------------------------------------------
%% Colors
%% ---------------------------------------------------------------------------

-spec foreground(atom()) -> iodata().
foreground(Color) when is_atom(Color) ->
    case maps:find(Color, ?FOREGROUND_CODES) of
        {ok, Code} -> [?CSI, Code, "m"];
        error -> erlang:error({invalid_color, Color})
    end.

-spec background(atom()) -> iodata().
background(Color) when is_atom(Color) ->
    case maps:find(Color, ?BACKGROUND_CODES) of
        {ok, Code} -> [?CSI, Code, "m"];
        error -> erlang:error({invalid_color, Color})
    end.

-spec foreground_256(0..255) -> iodata().
foreground_256(Index) when is_integer(Index), Index >= 0, Index =< 255 ->
    [?CSI, "38;5;", integer_to_list(Index), "m"].

-spec background_256(0..255) -> iodata().
background_256(Index) when is_integer(Index), Index >= 0, Index =< 255 ->
    [?CSI, "48;5;", integer_to_list(Index), "m"].

-spec foreground_rgb(0..255, 0..255, 0..255) -> iodata().
foreground_rgb(R, G, B)
        when is_integer(R), R >= 0, R =< 255,
             is_integer(G), G >= 0, G =< 255,
             is_integer(B), B >= 0, B =< 255 ->
    [?CSI, "38;2;", integer_to_list(R), ";",
     integer_to_list(G), ";", integer_to_list(B), "m"].

-spec background_rgb(0..255, 0..255, 0..255) -> iodata().
background_rgb(R, G, B)
        when is_integer(R), R >= 0, R =< 255,
             is_integer(G), G >= 0, G =< 255,
             is_integer(B), B >= 0, B =< 255 ->
    [?CSI, "48;2;", integer_to_list(R), ";",
     integer_to_list(G), ";", integer_to_list(B), "m"].

%% ---------------------------------------------------------------------------
%% Text attributes
%% ---------------------------------------------------------------------------

-spec bold() -> iodata().
bold() -> [?CSI, "1m"].

-spec dim() -> iodata().
dim() -> [?CSI, "2m"].

-spec italic() -> iodata().
italic() -> [?CSI, "3m"].

-spec underline() -> iodata().
underline() -> [?CSI, "4m"].

-spec blink() -> iodata().
blink() -> [?CSI, "5m"].

-spec reverse() -> iodata().
reverse() -> [?CSI, "7m"].

-spec hidden() -> iodata().
hidden() -> [?CSI, "8m"].

-spec strikethrough() -> iodata().
strikethrough() -> [?CSI, "9m"].

-spec reset() -> iodata().
reset() -> [?CSI, "0m"].

-spec reset_style() -> iodata().
reset_style() -> reset().

-spec format([atom()]) -> iodata().
format([]) -> [];
format(Attrs) when is_list(Attrs) ->
    Codes = lists:map(fun attribute_to_code/1, Attrs),
    [?CSI, lists:join(";", Codes), "m"].

%% ---------------------------------------------------------------------------
%% Special modes
%% ---------------------------------------------------------------------------

-spec enable_bracketed_paste() -> iodata().
enable_bracketed_paste() -> [?CSI, "?2004h"].

-spec disable_bracketed_paste() -> iodata().
disable_bracketed_paste() -> [?CSI, "?2004l"].

-spec enable_focus_events() -> iodata().
enable_focus_events() -> [?CSI, "?1004h"].

-spec disable_focus_events() -> iodata().
disable_focus_events() -> [?CSI, "?1004l"].

-spec enable_app_cursor() -> iodata().
enable_app_cursor() -> [?CSI, "?1h"].

-spec disable_app_cursor() -> iodata().
disable_app_cursor() -> [?CSI, "?1l"].

-spec enable_mouse_tracking(x10 | normal | button | all) -> iodata().
enable_mouse_tracking(x10) -> [?CSI, "?9h"];
enable_mouse_tracking(normal) -> [?CSI, "?1000h"];
enable_mouse_tracking(button) -> [?CSI, "?1002h"];
enable_mouse_tracking(all) -> [?CSI, "?1003h"].

-spec disable_mouse_tracking(x10 | normal | button | all) -> iodata().
disable_mouse_tracking(x10) -> [?CSI, "?9l"];
disable_mouse_tracking(normal) -> [?CSI, "?1000l"];
disable_mouse_tracking(button) -> [?CSI, "?1002l"];
disable_mouse_tracking(all) -> [?CSI, "?1003l"].

-spec enable_sgr_mouse() -> iodata().
enable_sgr_mouse() -> [?CSI, "?1006h"].

-spec disable_sgr_mouse() -> iodata().
disable_sgr_mouse() -> [?CSI, "?1006l"].

-spec enter_alternate_screen() -> iodata().
enter_alternate_screen() -> [?CSI, "?1049h"].

-spec leave_alternate_screen() -> iodata().
leave_alternate_screen() -> [?CSI, "?1049l"].

%% @doc Builds an OSC (Operating System Command) sequence:
%% `ESC ] Params ; Data BEL'. `Params' is a list of binaries/strings, `Data'
%% a binary. Use `set_title/1' or `clipboard/1,2' rather than calling this
%% directly unless you need a custom command.
-spec osc([term()], binary()) -> iodata().
osc(Params, Data) when is_list(Params), is_binary(Data) ->
    [?OSC, lists:join($;, Params), $;, Data, ?BEL].

%% @doc Sets the terminal window title (OSC 0).
-spec set_title(binary()) -> iodata().
set_title(Title) when is_binary(Title) ->
    osc([<<"0">>], Title).

%% @doc Copies `Text' to the system clipboard using OSC 52 on the default
%% (`c') selection. Terminals that support OSC 52 will honour this; others
%% ignore it.
-spec clipboard(binary()) -> iodata().
clipboard(Text) -> clipboard(<<"c">>, Text).

%% @doc Like `clipboard/1' but for an explicit clipboard selection
%% (`<<"c">>' system, `<<"p">>' primary, `<<"s">>' select).
-spec clipboard(binary(), binary()) -> iodata().
clipboard(Selection, Text) when is_binary(Selection), is_binary(Text) ->
    osc([<<"52">>, Selection], base64:encode(Text)).

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec attribute_to_code(atom()) -> string().
attribute_to_code(Attr) ->
    case maps:find(Attr, ?ATTRIBUTE_CODES) of
        {ok, Code} -> Code;
        error -> erlang:error({invalid_attribute, Attr})
    end.
