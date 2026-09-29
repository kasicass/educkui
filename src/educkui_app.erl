%% @doc educkui application callback module.
%%
%% educkui is a library application: it does not start any processes on
%% boot. The top-level supervisor exists so that applications which embed
%% educkui can hang its runtime processes under a well-known tree, but the
%% runtime itself is started on demand via {@link educkui_runtime}.
-module(educkui_app).

-behaviour(application).

-export([start/2, stop/1]).

%% @private
-spec start(application:start_type(), term()) ->
    {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    educkui_sup:start_link().

%% @private
-spec stop(term()) -> ok.
stop(_State) ->
    ok.
