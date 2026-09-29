%% @doc Main entry point for educkui.
%%
%% `run/1` starts the runtime and blocks until it shuts down; `start/1`
%% starts the runtime without blocking.
-module(educkui).

-export([run/1, start/1, size/0, running_mode/0, backend_mode/0]).

-spec run([{atom(), term()}]) -> ok | {error, term()}.
run(Opts) ->
    educkui_runtime:run(Opts).

-spec start([{atom(), term()}]) -> gen_server:start_ret().
start(Opts) ->
    educkui_runtime:start_link(Opts).

-spec size() -> {ok, {pos_integer(), pos_integer()}}.
size() ->
    educkui_terminal_size:detect().

-spec running_mode() -> standalone | tty.
running_mode() ->
    case educkui_capabilities:is_tty() of
        true -> standalone;
        false -> tty
    end.

-spec backend_mode() -> raw | tty | skip | undefined.
backend_mode() ->
    educkui_runtime:backend_mode().
