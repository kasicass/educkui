%% @doc Asynchronous command executor.
%%
%% Commands returned by component `update/2` are executed here so that side
%% effects stay out of the component and runtime processes. Results are sent
%% back to the runtime process.
-module(educkui_command_executor).

-behaviour(gen_server).

-export([start_link/0, execute/4]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% ---------------------------------------------------------------------------
%% Client API
%% ---------------------------------------------------------------------------

-spec start_link() -> gen_server:start_ret().
start_link() ->
    gen_server:start_link(?MODULE, [], []).

%% @doc Executes `Commands` for `ComponentId`, sending results to `Runtime`.
-spec execute(pid(), term(), [term()], pid()) -> ok.
execute(Executor, ComponentId, Commands, Runtime)
        when is_pid(Executor), is_list(Commands), is_pid(Runtime) ->
    gen_server:cast(Executor, {execute, ComponentId, Commands, Runtime}).

%% ---------------------------------------------------------------------------
%% gen_server callbacks
%% ---------------------------------------------------------------------------

-spec init([]) -> {ok, map()}.
init([]) ->
    {ok, #{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({execute, ComponentId, Commands, Runtime}, State) ->
    lists:foreach(fun(Cmd) -> run_command(ComponentId, Cmd, Runtime) end, Commands),
    {noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec run_command(term(), term(), pid()) -> ok.
run_command(_ComponentId, {quit}, Runtime) ->
    Runtime ! {educkui_command, quit},
    ok;
run_command(_ComponentId, {noop}, _Runtime) ->
    ok;
run_command(_ComponentId, {send, Pid, Msg}, _Runtime) when is_pid(Pid) ->
    Pid ! Msg,
    ok;
run_command(ComponentId, {exec, Fun}, Runtime) when is_function(Fun, 0) ->
    _ = spawn(fun() ->
        Result = try Fun() of
            V -> V
        catch
            _:_ -> {error, command_failed}
        end,
        Runtime ! {command_result, ComponentId, Result}
    end),
    ok;
run_command(_ComponentId, _Unknown, _Runtime) ->
    ok.
