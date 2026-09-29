%% @doc Small terminal I/O helpers shared by backends and the terminal server.
-module(educkui_term_utils).

-export([write/1, write/2, mouse_off/0]).

-spec write(iodata()) -> ok.
write(Data) ->
    write(user, Data).

-spec write(io:device(), iodata()) -> ok.
write(IoDevice, Data) ->
    _ = io:put_chars(IoDevice, Data),
    ok.

%% @doc Disables all mouse reporting modes defensively. This is used in
%% cleanup paths where the exact active mode may be unknown.
-spec mouse_off() -> binary().
mouse_off() ->
    <<"\e[?1006l\e[?1003l\e[?1002l\e[?1000l">>.
