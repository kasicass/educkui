%% @doc Command constructors.
%%
%% Commands are plain terms executed asynchronously by
%% `educkui_command_executor`. `update/2` returns a list of commands to run.
-module(educkui_command).

-export([quit/0, noop/0, send_msg/2, exec/1]).

-spec quit() -> {quit}.
quit() -> {quit}.

-spec noop() -> {noop}.
noop() -> {noop}.

-spec send_msg(pid(), term()) -> {send, pid(), term()}.
send_msg(Pid, Msg) -> {send, Pid, Msg}.

-spec exec(fun(() -> term())) -> {exec, fun(() -> term())}.
exec(Fun) when is_function(Fun, 0) -> {exec, Fun}.
