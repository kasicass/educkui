%% @doc Main entry point for educkui.
%%
%% `run/1' starts the runtime and blocks until it shuts down; `start/1'
%% starts the runtime without blocking.
-module(educkui).

-export([run/1, start/1, size/0, running_mode/0, backend_mode/0]).

%% @doc Starts the runtime and blocks until it shuts down.
-spec run([{atom(), term()}]) -> ok | {error, term()}.
run(Opts) ->
    educkui_runtime:run(Opts).

%% @doc Starts the runtime without blocking.
-spec start([{atom(), term()}]) -> gen_server:start_ret().
start(Opts) ->
    educkui_runtime:start_link(Opts).

%% @doc Detects the current terminal size.
-spec size() -> {ok, {pos_integer(), pos_integer()}}.
size() ->
    educkui_terminal_size:detect().

%% @doc Reports the detected running mode.
-spec running_mode() -> standalone | tty.
running_mode() ->
    case educkui_capabilities:is_tty() of
        true -> standalone;
        false -> tty
    end.

%% @doc Reports the active backend mode.
-spec backend_mode() -> raw | tty | skip | undefined.
backend_mode() ->
    educkui_runtime:backend_mode().
