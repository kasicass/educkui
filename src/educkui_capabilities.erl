%% @doc Terminal capability detection.
%%
%% Detects color depth, Unicode support and whether stdout is a terminal.
%% Detection is best-effort and used to degrade gracefully (true color ->
%% 256 -> 16 -> monochrome; unicode -> ASCII fallback; mouse -> keyboard).
-module(educkui_capabilities).

-export([detect/0, color_depth/0, unicode_support/0, is_tty/0]).

-spec detect() -> map().
detect() ->
    #{colors => color_depth(),
      unicode => unicode_support(),
      terminal => is_tty()}.

%% ---------------------------------------------------------------------------
%% Detection
%% ---------------------------------------------------------------------------

-spec color_depth() -> true_color | color_256 | color_16 | monochrome.
color_depth() ->
    case string:lowercase(os_getenv("COLORTERM")) of
        "truecolor" -> true_color;
        "24bit" -> true_color;
        _ ->
            Term = string:lowercase(os_getenv("TERM")),
            case string:find(Term, "256color") of
                nomatch -> color_16;
                _ -> color_256
            end
    end.

-spec unicode_support() -> boolean().
unicode_support() ->
    case io:getopts(user) of
        Opts when is_list(Opts) ->
            case proplists:get_value(encoding, Opts) of
                unicode -> true;
                latin1 -> false;
                _ -> term_unicode()
            end;
        _ ->
            term_unicode()
    end.

-spec is_tty() -> boolean().
is_tty() ->
    case io:getopts(user) of
        Opts when is_list(Opts) -> proplists:get_value(terminal, Opts, false);
        _ -> false
    end.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec term_unicode() -> boolean().
term_unicode() ->
    %% The Linux virtual console is the common ASCII-only terminal; all
    %% modern xterm-compatible terminals speak UTF-8.
    string:lowercase(os_getenv("TERM")) =/= "linux".

-spec os_getenv(string()) -> string().
os_getenv(Name) ->
    case os:getenv(Name) of
        false -> "";
        Value -> Value
    end.
