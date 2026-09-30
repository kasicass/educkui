%% @doc Terminal management server.
%%
%% Owns terminal state (raw mode, alternate screen, cursor visibility, mouse
%% tracking) and performs all terminal I/O on behalf of the runtime and
%% backends. Uses OTP 28's `shell:start_interactive({noshell, raw})' for raw
%% mode and `io:put_chars/2' for output.
-module(educkui_terminal).

-behaviour(gen_server).

-export([
    start_link/0, start_link/1,
    activate_raw_mode/0, deactivate_raw_mode/0,
    enter_alternate_screen/0, leave_alternate_screen/0,
    hide_cursor/0, show_cursor/0,
    get_terminal_size/0,
    enable_mouse_tracking/1, disable_mouse_tracking/0,
    restore/0, raw_mode/0, get_state/0
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% `shell:start_interactive({noshell, raw})' may return `{error, enotsup}' at
%% runtime on non-tty devices even though the OTP spec only lists
%% `ok | {error, already_started}'. Suppress the resulting dead-clause
%% warning for the defensive error clause.
-dialyzer({nowarn_function, do_activate_raw/0}).

-define(MOUSE_OFF, <<"\e[?1006l\e[?1003l\e[?1002l\e[?1000l">>).

%% ---------------------------------------------------------------------------
%% Client API
%% ---------------------------------------------------------------------------

-spec start_link() -> gen_server:start_ret().
start_link() -> start_link([]).

-spec start_link([{atom(), term()}]) -> gen_server:start_ret().
start_link(Opts) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Opts, []).

-spec activate_raw_mode() -> ok | {error, term()}.
activate_raw_mode() -> gen_server:call(?MODULE, activate_raw_mode).

-spec deactivate_raw_mode() -> ok.
deactivate_raw_mode() -> gen_server:call(?MODULE, deactivate_raw_mode).

-spec enter_alternate_screen() -> ok.
enter_alternate_screen() -> gen_server:call(?MODULE, enter_alternate_screen).

-spec leave_alternate_screen() -> ok.
leave_alternate_screen() -> gen_server:call(?MODULE, leave_alternate_screen).

-spec hide_cursor() -> ok.
hide_cursor() -> gen_server:call(?MODULE, hide_cursor).

-spec show_cursor() -> ok.
show_cursor() -> gen_server:call(?MODULE, show_cursor).

-spec get_terminal_size() -> {ok, {pos_integer(), pos_integer()}}.
get_terminal_size() -> gen_server:call(?MODULE, get_terminal_size).

-spec enable_mouse_tracking(click | drag | all) -> ok.
enable_mouse_tracking(Mode) when Mode =:= click; Mode =:= drag; Mode =:= all ->
    gen_server:call(?MODULE, {enable_mouse_tracking, Mode}).

-spec disable_mouse_tracking() -> ok.
disable_mouse_tracking() -> gen_server:call(?MODULE, disable_mouse_tracking).

-spec restore() -> ok.
restore() -> gen_server:call(?MODULE, restore).

-spec raw_mode() -> boolean().
raw_mode() -> gen_server:call(?MODULE, raw_mode).

-spec get_state() -> map().
get_state() -> gen_server:call(?MODULE, get_state).

%% ---------------------------------------------------------------------------
%% gen_server callbacks
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> {ok, map()}.
init(_Opts) ->
    process_flag(trap_exit, true),
    {ok, #{
        raw_mode_active => false,
        alternate_screen_active => false,
        cursor_visible => true
    }}.

handle_call(activate_raw_mode, _From, State) ->
    case maps:get(raw_mode_active, State) of
        true ->
            {reply, ok, State};
        false ->
            case do_activate_raw() of
                ok -> {reply, ok, State#{raw_mode_active := true}};
                {error, _Reason} = Error -> {reply, Error, State}
            end
    end;

handle_call(deactivate_raw_mode, _From, State) ->
    do_deactivate_raw(),
    {reply, ok, State#{raw_mode_active := false}};

handle_call(enter_alternate_screen, _From, State) ->
    case maps:get(alternate_screen_active, State) of
        true ->
            {reply, ok, State};
        false ->
            educkui_term_utils:write(educkui_ansi:enter_alternate_screen()),
            {reply, ok, State#{alternate_screen_active := true}}
    end;

handle_call(leave_alternate_screen, _From, State) ->
    case maps:get(alternate_screen_active, State) of
        true ->
            educkui_term_utils:write(educkui_ansi:leave_alternate_screen()),
            {reply, ok, State#{alternate_screen_active := false}};
        false ->
            {reply, ok, State}
    end;

handle_call(hide_cursor, _From, State) ->
    educkui_term_utils:write(educkui_ansi:cursor_hide()),
    {reply, ok, State#{cursor_visible := false}};

handle_call(show_cursor, _From, State) ->
    educkui_term_utils:write(educkui_ansi:cursor_show()),
    {reply, ok, State#{cursor_visible := true}};

handle_call(get_terminal_size, _From, State) ->
    {reply, educkui_terminal_size:detect(), State};

handle_call({enable_mouse_tracking, Mode}, _From, State) ->
    AnsiMode = case Mode of
        click -> normal;
        drag -> button;
        all -> all
    end,
    educkui_term_utils:write([
        educkui_ansi:enable_mouse_tracking(AnsiMode),
        educkui_ansi:enable_sgr_mouse()
    ]),
    {reply, ok, State};

handle_call(disable_mouse_tracking, _From, State) ->
    educkui_term_utils:write(?MOUSE_OFF),
    {reply, ok, State};

handle_call(restore, _From, State) ->
    do_restore(State),
    {reply, ok, #{
        raw_mode_active => false,
        alternate_screen_active => false,
        cursor_visible => true
    }};

handle_call(raw_mode, _From, State) ->
    {reply, maps:get(raw_mode_active, State), State};

handle_call(get_state, _From, State) ->
    {reply, State, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec do_activate_raw() -> ok | {error, term()}.
do_activate_raw() ->
    try
        case shell:start_interactive({noshell, raw}) of
            ok ->
                set_raw_opts(),
                ok;
            {error, already_started} ->
                set_raw_opts(),
                ok;
            {error, Reason} ->
                {error, Reason}
        end
    catch
        _:_ -> {error, enotsup}
    end.

-spec set_raw_opts() -> ok.
set_raw_opts() ->
    _ = io:setopts(user, [{echo, false}, {binary, true}]),
    ok.

-spec do_deactivate_raw() -> ok.
do_deactivate_raw() ->
    _ = io:setopts(user, [{echo, true}]),
    _ = shell:start_interactive({noshell, cooked}),
    ok.

-spec do_restore(map()) -> ok.
do_restore(State) ->
    educkui_term_utils:write(educkui_ansi:cursor_show()),
    case maps:get(alternate_screen_active, State) of
        true -> educkui_term_utils:write(educkui_ansi:leave_alternate_screen());
        false -> ok
    end,
    educkui_term_utils:write(?MOUSE_OFF),
    educkui_term_utils:write(educkui_ansi:reset()),
    do_deactivate_raw().
