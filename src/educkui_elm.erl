%% @doc The Elm Architecture behaviour for educkui components.
%%
%% Components using the Elm pattern implement `init/1', `event_to_msg/2',
%% `update/2' and `view/1':
%%
%%   1. events arrive from terminal input
%%   2. `event_to_msg/2' converts an event to a component message
%%   3. `update/2' transforms state, returning new state plus commands
%%   4. `view/1' renders the state to a render tree
-module(educkui_elm).

-export([normalize_init_result/1, normalize_update_result/2]).

-type state() :: term().
-type msg() :: term().
-type command() :: term().
-export_type([state/0, msg/0, command/0]).

-callback init([{atom(), term()}]) -> term().
-callback event_to_msg(term(), state()) -> {msg, msg()} | ignore | propagate.
-callback update(msg(), state()) ->
    {state(), [command()]} | {state()} | noreply.
-callback view(state()) -> term().

%% Optional callback invoked by `educkui_runtime:set_props/3' when a parent
%% pushes new props to an already-mounted component.
-callback handle_props(map(), state()) ->
    {state(), [command()]} | {state()} | noreply | ignore.

-optional_callbacks([init/1, handle_props/2]).

%% @doc Normalizes an `init/1' result to `{State, Commands}'.
-spec normalize_init_result(term()) -> {state(), [command()]}.
normalize_init_result({ok, S}) ->
    {S, []};
normalize_init_result({ok, S, Commands}) when is_list(Commands) ->
    {S, Commands};
normalize_init_result({S, Commands}) when is_list(Commands) ->
    {S, Commands};
normalize_init_result(S) ->
    {S, []}.

%% @doc Normalizes an `update/2' result to `{State, Commands}'.
-spec normalize_update_result(term(), state()) -> {state(), [command()]}.
normalize_update_result({S, Commands}, _OldState) when is_list(Commands) ->
    {S, Commands};
normalize_update_result({S}, _OldState) ->
    {S, []};
normalize_update_result(noreply, OldState) ->
    {OldState, []}.
