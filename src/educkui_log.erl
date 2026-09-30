%% @doc Bounded in-memory log buffer.
%%
%% A small gen_server that keeps the most recent log events so an application
%% can render them in a log viewer (e.g. dui-redis' Logs screen). The runtime
%% installs a `logger' handler (`educkui_log_handler') that feeds this server
%% while the alternate screen is active, so stray log output does not corrupt
%% the TUI.
%%
%% The server is started on demand with `ensure_started/0' and is intentionally
%% not linked to the runtime, so it survives runtime restarts.
-module(educkui_log).

-behaviour(gen_server).

-export([ensure_started/0, add/1, entries/0, entries/1, clear/0, max_entries/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(DEFAULT_MAX, 1000).

-type entry() :: logger:log_event().
-export_type([entry/0]).

%% @doc Starts the log server if it is not already running.
-spec ensure_started() -> {ok, pid()} | {error, term()}.
ensure_started() ->
    case whereis(?SERVER) of
        undefined ->
            case gen_server:start({local, ?SERVER}, ?MODULE, [], []) of
                {ok, Pid} -> {ok, Pid};
                {error, {already_started, Pid}} -> {ok, Pid};
                Other -> Other
            end;
        Pid ->
            {ok, Pid}
    end.

%% @doc Appends a log event. No-op if the server is not running.
-spec add(entry()) -> ok.
add(Event) ->
    gen_server:cast(?SERVER, {add, Event}).

%% @doc Returns the buffered entries, oldest first.
-spec entries() -> [entry()].
entries() ->
    entries(max_entries()).

%% @doc Returns at most `N' buffered entries, oldest first.
-spec entries(non_neg_integer()) -> [entry()].
entries(N) when is_integer(N), N >= 0 ->
    case whereis(?SERVER) of
        undefined -> [];
        _ -> gen_server:call(?SERVER, {entries, N})
    end.

%% @doc Clears the buffer.
-spec clear() -> ok.
clear() ->
    case whereis(?SERVER) of
        undefined -> ok;
        _ -> gen_server:call(?SERVER, clear)
    end.

%% @doc Maximum number of buffered entries.
-spec max_entries() -> pos_integer().
max_entries() -> ?DEFAULT_MAX.

%% ---------------------------------------------------------------------------
%% gen_server callbacks
%% ---------------------------------------------------------------------------

-spec init([]) -> {ok, map()}.
init([]) ->
    {ok, #{entries => [], size => 0, max => ?DEFAULT_MAX}}.

handle_call({entries, N}, _From, #{entries := Entries} = State) ->
    {reply, lists:sublist(lists:reverse(Entries), N), State};
handle_call(clear, _From, State) ->
    {reply, ok, State#{entries := [], size := 0}};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({add, Event}, #{entries := Entries, size := Size, max := Max} = State) ->
    Entries1 = [Event | Entries],
    case Size + 1 > Max of
        true ->
            Entries2 = lists:sublist(Entries1, Max),
            {noreply, State#{entries := Entries2, size := Max}};
        false ->
            {noreply, State#{entries := Entries1, size := Size + 1}}
    end;
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
