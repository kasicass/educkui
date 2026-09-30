%% @doc Terminal size detection with graceful fallback.
%%
%% Primary source is `io:columns/1' and `io:rows/1'; when the device does not
%% support geometry queries (or is not a terminal), falls back to the
%% `COLUMNS'/`LINES' environment variables, then to a 24x80 default.
-module(educkui_terminal_size).

-export([detect/0, detect/1, from_io/2, default/0]).

-spec default() -> {pos_integer(), pos_integer()}.
default() -> {24, 80}.

-spec detect() -> {ok, {pos_integer(), pos_integer()}}.
detect() ->
    detect(user).

-spec detect(io:device()) -> {ok, {pos_integer(), pos_integer()}}.
detect(IoDevice) ->
    case from_io(io:rows(IoDevice), io:columns(IoDevice)) of
        {ok, _Size} = Ok -> Ok;
        error -> {ok, default()}
    end.

%% @doc Combines the results of `io:rows/1' and `io:columns/1' into a size,
%% or returns `error' so the caller can apply fallbacks.
-spec from_io({ok, pos_integer()} | {error, term()},
    {ok, pos_integer()} | {error, term()}) ->
    {ok, {pos_integer(), pos_integer()}} | error.
from_io({ok, Rows}, {ok, Cols}) when Rows > 0, Cols > 0 ->
    {ok, {Rows, Cols}};
from_io(_Rows, _Cols) ->
    env_fallback().

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec env_fallback() -> {ok, {pos_integer(), pos_integer()}} | error.
env_fallback() ->
    Cols = env_int("COLUMNS"),
    Rows = env_int("LINES"),
    case {Rows, Cols} of
        {R, C} when R > 0, C > 0 -> {ok, {R, C}};
        _ -> error
    end.

-spec env_int(string()) -> integer().
env_int(Name) ->
    case os:getenv(Name) of
        false -> 0;
        Value ->
            case string:to_integer(Value) of
                {N, _} when N > 0 -> N;
                _ -> 0
            end
    end.
