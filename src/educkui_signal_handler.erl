%% @doc Forwards SIGWINCH (terminal resize) to the runtime process.
%%
%% Installed as a handler on the kernel's `erl_signal_server` gen_event
%% process (the same mechanism `prim_tty` uses). On `sigwinch`, sends
%% `{educkui_sigwinch}` to the runtime so it can re-detect and re-render.
-module(educkui_signal_handler).

-behaviour(gen_event).

-export([install/1, uninstall/1]).
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

-spec install(pid()) -> ok | {error, term()}.
install(RuntimePid) when is_pid(RuntimePid) ->
    _ = os:set_signal(sigwinch, handle),
    gen_event:add_handler(erl_signal_server, ?MODULE, RuntimePid).

-spec uninstall(pid()) -> ok | {error, term()}.
uninstall(RuntimePid) ->
    gen_event:delete_handler(erl_signal_server, ?MODULE, [RuntimePid]).

%% ---------------------------------------------------------------------------
%% gen_event callbacks
%% ---------------------------------------------------------------------------

-spec init(pid()) -> {ok, pid()}.
init(RuntimePid) ->
    {ok, RuntimePid}.

-spec handle_event(term(), pid()) -> {ok, pid()}.
handle_event(sigwinch, RuntimePid) ->
    RuntimePid ! {educkui_sigwinch},
    {ok, RuntimePid};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(_Request, State) ->
    {ok, ok, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Arg, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
