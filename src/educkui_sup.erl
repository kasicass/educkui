%% @doc Default top-level supervisor for educkui.
%%
%% The supervisor is intentionally empty in the library application. Runtime
%% processes (terminal, command executor, runtime) are started on demand and
%% are meant to be placed under the embedding application's own supervision
%% tree. This module provides a stable anchor and a place to add shared
%% processes later if needed.
-module(educkui_sup).

-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

%% @doc Starts the supervisor.
-spec start_link() -> supervisor:startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @private
-spec init([]) -> {ok, {supervisor:sup_flags(), [supervisor:child_spec()]}}.
init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },
    {ok, {SupFlags, []}}.
