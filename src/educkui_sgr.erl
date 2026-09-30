%% @doc SGR (Select Graphic Rendition) parameter and sequence generation.
%%
%% Provides two modes of operation:
%% - Parameter mode (`color_param/2', `attr_param/1', ...) returns plain
%%   strings for combining into a single `ESC[...m' sequence.
%% - Sequence mode (`color_sequence/2', `attr_sequence/1', ...) returns
%%   complete iolists.
-module(educkui_sgr).

-export([
    color_param/2,
    attr_param/1,
    attr_off_param/1,
    build_sequence/1,
    color_sequence/2,
    attr_sequence/1,
    reset/0,
    named_colors/0,
    supported_attrs/0
]).

-define(CSI, "\e[").

-define(NAMED_COLORS, [
    black, red, green, yellow, blue, magenta, cyan, white,
    bright_black, bright_red, bright_green, bright_yellow,
    bright_blue, bright_magenta, bright_cyan, bright_white
]).

-define(SUPPORTED_ATTRS, [
    bold, dim, italic, underline, blink, reverse, hidden, strikethrough
]).

%% ---------------------------------------------------------------------------
%% Parameter mode
%% ---------------------------------------------------------------------------

-spec color_param(fg | bg, term()) -> string() | undefined.
color_param(fg, default) -> "39";
color_param(bg, default) -> "49";
color_param(fg, black) -> "30";
color_param(fg, red) -> "31";
color_param(fg, green) -> "32";
color_param(fg, yellow) -> "33";
color_param(fg, blue) -> "34";
color_param(fg, magenta) -> "35";
color_param(fg, cyan) -> "36";
color_param(fg, white) -> "37";
color_param(fg, bright_black) -> "90";
color_param(fg, bright_red) -> "91";
color_param(fg, bright_green) -> "92";
color_param(fg, bright_yellow) -> "93";
color_param(fg, bright_blue) -> "94";
color_param(fg, bright_magenta) -> "95";
color_param(fg, bright_cyan) -> "96";
color_param(fg, bright_white) -> "97";
color_param(bg, black) -> "40";
color_param(bg, red) -> "41";
color_param(bg, green) -> "42";
color_param(bg, yellow) -> "43";
color_param(bg, blue) -> "44";
color_param(bg, magenta) -> "45";
color_param(bg, cyan) -> "46";
color_param(bg, white) -> "47";
color_param(bg, bright_black) -> "100";
color_param(bg, bright_red) -> "101";
color_param(bg, bright_green) -> "102";
color_param(bg, bright_yellow) -> "103";
color_param(bg, bright_blue) -> "104";
color_param(bg, bright_magenta) -> "105";
color_param(bg, bright_cyan) -> "106";
color_param(bg, bright_white) -> "107";
color_param(fg, N) when is_integer(N), N >= 0, N =< 255 ->
    "38;5;" ++ integer_to_list(N);
color_param(bg, N) when is_integer(N), N >= 0, N =< 255 ->
    "48;5;" ++ integer_to_list(N);
color_param(fg, {R, G, B})
        when is_integer(R), R >= 0, R =< 255,
             is_integer(G), G >= 0, G =< 255,
             is_integer(B), B >= 0, B =< 255 ->
    lists:flatten(io_lib:format("38;2;~b;~b;~b", [R, G, B]));
color_param(bg, {R, G, B})
        when is_integer(R), R >= 0, R =< 255,
             is_integer(G), G >= 0, G =< 255,
             is_integer(B), B >= 0, B =< 255 ->
    lists:flatten(io_lib:format("48;2;~b;~b;~b", [R, G, B]));
color_param(_Type, _Unknown) -> undefined.

-spec attr_param(atom()) -> string() | undefined.
attr_param(bold) -> "1";
attr_param(dim) -> "2";
attr_param(italic) -> "3";
attr_param(underline) -> "4";
attr_param(blink) -> "5";
attr_param(reverse) -> "7";
attr_param(hidden) -> "8";
attr_param(strikethrough) -> "9";
attr_param(_Unknown) -> undefined.

-spec attr_off_param(atom()) -> string() | undefined.
attr_off_param(bold) -> "22";
attr_off_param(dim) -> "22";
attr_off_param(italic) -> "23";
attr_off_param(underline) -> "24";
attr_off_param(blink) -> "25";
attr_off_param(reverse) -> "27";
attr_off_param(hidden) -> "28";
attr_off_param(strikethrough) -> "29";
attr_off_param(_Unknown) -> undefined.

-spec build_sequence([string()]) -> iodata().
build_sequence([]) -> [];
build_sequence(Params) when is_list(Params) ->
    Filtered = [P || P <- Params, P =/= undefined],
    case Filtered of
        [] -> [];
        _ -> [?CSI, lists:join(";", Filtered), "m"]
    end.

%% ---------------------------------------------------------------------------
%% Sequence mode
%% ---------------------------------------------------------------------------

-spec color_sequence(fg | bg, term()) -> iodata().
color_sequence(Type, Color) ->
    case color_param(Type, Color) of
        undefined -> [];
        Param -> [?CSI, Param, "m"]
    end.

-spec attr_sequence(atom()) -> iodata().
attr_sequence(Attr) ->
    case attr_param(Attr) of
        undefined -> [];
        Param -> [?CSI, Param, "m"]
    end.

-spec reset() -> iodata().
reset() -> [?CSI, "0m"].

%% ---------------------------------------------------------------------------
%% Introspection
%% ---------------------------------------------------------------------------

-spec named_colors() -> [atom()].
named_colors() -> ?NAMED_COLORS.

-spec supported_attrs() -> [atom()].
supported_attrs() -> ?SUPPORTED_ATTRS.
