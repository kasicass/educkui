%% @doc Command constructors.
%%
%% Commands are plain terms executed asynchronously by
%% `educkui_command_executor'. `update/2' returns a list of commands to run.
-module(educkui_command).

-export([quit/0, noop/0, send_msg/2, exec/1, focus/1, parent/1]).

%% @doc Returns a command that stops the runtime.
-spec quit() -> {quit}.
quit() -> {quit}.

%% @doc Returns a no-op command.
-spec noop() -> {noop}.
noop() -> {noop}.

%% @doc Returns a command that sends `Msg' to `Pid'.
-spec send_msg(pid(), term()) -> {send, pid(), term()}.
send_msg(Pid, Msg) -> {send, Pid, Msg}.

%% @doc Returns a command that runs `Fun/0' asynchronously.
-spec exec(fun(() -> term())) -> {exec, fun(() -> term())}.
exec(Fun) when is_function(Fun, 0) -> {exec, Fun}.

%% @doc Moves focus to the component with the given id. Handled directly by
%% the runtime (not the command executor).
-spec focus(term()) -> {focus, term()}.
focus(Id) -> {focus, Id}.

%% @doc Sends a message to the root component (bubbling to the parent).
%% Handled directly by the runtime.
-spec parent(term()) -> {parent, term()}.
parent(Msg) -> {parent, Msg}.
