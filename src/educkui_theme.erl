%% @doc Theme management.
%%
%% A theme is a map from style names (atoms) to `#dui_style{}` values. It also
%% provides the named-color to RGB conversion table used by color degradation
%% and by components that need to reason about colors.
-module(educkui_theme).

-include("educkui.hrl").

-export([
    new/0,
    put/3,
    get/2, get/3,
    merge/2,
    color_rgb/1,
    named_colors/0
]).

-define(COLOR_RGB, #{
    black => {0, 0, 0},
    red => {128, 0, 0},
    green => {0, 128, 0},
    yellow => {128, 128, 0},
    blue => {0, 0, 128},
    magenta => {128, 0, 128},
    cyan => {0, 128, 128},
    white => {192, 192, 192},
    bright_black => {128, 128, 128},
    bright_red => {255, 0, 0},
    bright_green => {0, 255, 0},
    bright_yellow => {255, 255, 0},
    bright_blue => {0, 0, 255},
    bright_magenta => {255, 0, 255},
    bright_cyan => {0, 255, 255},
    bright_white => {255, 255, 255}
}).

-spec new() -> map().
new() -> #{}.

-spec put(map(), atom(), #dui_style{}) -> map().
put(Theme, Name, Style) ->
    Theme#{Name => Style}.

-spec get(map(), atom()) -> #dui_style{} | undefined.
get(Theme, Name) ->
    maps:get(Name, Theme, undefined).

-spec get(map(), atom(), #dui_style{} | undefined) -> #dui_style{} | undefined.
get(Theme, Name, Default) ->
    maps:get(Name, Theme, Default).

-spec merge(map(), map()) -> map().
merge(Base, Override) ->
    maps:merge(Base, Override).

-spec color_rgb(atom()) -> {0..255, 0..255, 0..255}.
color_rgb(Color) ->
    maps:get(Color, ?COLOR_RGB).

-spec named_colors() -> [atom()].
named_colors() ->
    maps:keys(?COLOR_RGB).
