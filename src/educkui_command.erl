%% @doc Command constructors.
%%
%% Commands are plain terms executed asynchronously by
%% `educkui_command_executor'. `update/2' returns a list of commands to run.
%%
%% Some commands are handled directly by the runtime instead of the executor:
%% `focus/1', `parent/1', `interval/2,3' and `cancel_interval/1'.
-module(educkui_command).

-export([quit/0, noop/0, send_msg/2, exec/1, focus/1, parent/1,
         interval/2, interval/3, cancel_interval/1]).

-type command() :: term().
-export_type([command/0]).

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

%% @doc Schedules `Msg' to be delivered to the root component every `Ms'
%% milliseconds. The runtime generates a private reference for the timer, so
%% this form cannot be cancelled; use `interval/3' when you need to cancel.
-spec interval(term(), pos_integer()) -> command().
interval(Msg, Ms) when is_integer(Ms), Ms > 0 ->
    {interval, undefined, Msg, Ms}.

%% @doc Schedules `Msg' every `Ms' milliseconds with a caller-supplied `Ref'.
%% The reference can later be passed to `cancel_interval/1'. The reference is
%% only meaningful to the runtime; the caller usually stores it in state.
-spec interval(reference(), term(), pos_integer()) -> command().
interval(Ref, Msg, Ms) when is_reference(Ref), is_integer(Ms), Ms > 0 ->
    {interval, Ref, Msg, Ms}.

%% @doc Cancels a previously scheduled `interval/3' timer.
-spec cancel_interval(reference()) -> {cancel_interval, reference()}.
cancel_interval(Ref) when is_reference(Ref) ->
    {cancel_interval, Ref}.
