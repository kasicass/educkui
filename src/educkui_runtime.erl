%% @doc Central runtime orchestrator.
%%
%% Implements the Elm Architecture dispatch loop:
%%
%%   1. receive an event (terminal input, command result, ...)
%%   2. route it to the root component
%%   3. call `event_to_msg/2', then `update/2'
%%   4. collect and execute commands
%%   5. on each render tick, call `view/1' and rasterize to the buffer
%%   6. draw changed cells to the backend (double buffering)
-module(educkui_runtime).

-behaviour(gen_server).

-include("educkui.hrl").

-export([
    start_link/1,
    run/1,
    send_event/2,
    send_message/3,
    shutdown/1,
    sync/1,
    get_state/1,
    force_render/1,
    set_props/3,
    get_component_state/2,
    size/1,
    copy_to_clipboard/1,
    logs/1,
    clear_logs/1,
    backend_mode/0,
    capabilities/0
]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% ---------------------------------------------------------------------------
%% Client API
%% ---------------------------------------------------------------------------

%% @doc Starts the runtime process linked to the caller.
-spec start_link([{atom(), term()}]) -> gen_server:start_ret().
start_link(Opts) ->
    gen_server:start_link(?MODULE, Opts, []).

%% @doc Starts the runtime and blocks until it exits.
-spec run([{atom(), term()}]) -> ok | {error, term()}.
run(Opts) ->
    case start_link(Opts) of
        {ok, Pid} ->
            Ref = erlang:monitor(process, Pid),
            receive
                {'DOWN', Ref, process, Pid, _Reason} -> ok
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Injects an event into the runtime.
-spec send_event(pid(), #dui_event{}) -> ok.
send_event(Runtime, Event) ->
    gen_server:cast(Runtime, {event, Event}).

%% @doc Sends a directed message to a component.
-spec send_message(pid(), term(), term()) -> ok.
send_message(Runtime, ComponentId, Message) ->
    gen_server:cast(Runtime, {message, ComponentId, Message}).

%% @doc Asks the runtime to shut down.
-spec shutdown(pid()) -> ok.
shutdown(Runtime) ->
    gen_server:cast(Runtime, shutdown).

%% @doc Synchronously waits for the runtime to process prior requests.
-spec sync(pid()) -> ok.
sync(Runtime) ->
    gen_server:call(Runtime, sync).

%% @doc Returns the runtime state record (for introspection/testing).
-spec get_state(pid()) -> #dui_runtime_state{}.
get_state(Runtime) ->
    gen_server:call(Runtime, get_state).

%% @doc Forces an immediate render.
-spec force_render(pid()) -> ok.
force_render(Runtime) ->
    gen_server:cast(Runtime, force_render).

%% @doc Pushes new props to a mounted component. If the component implements
%% the optional `handle_props/2' callback, it is invoked with the new props;
%% otherwise the props are stored but the state is left unchanged.
-spec set_props(pid(), term(), map()) -> ok.
set_props(Runtime, ComponentId, Props) ->
    gen_server:cast(Runtime, {set_props, ComponentId, Props}).

%% @doc Returns the current state of a mounted component.
-spec get_component_state(pid(), term()) -> {ok, term()} | error.
get_component_state(Runtime, ComponentId) ->
    gen_server:call(Runtime, {get_component_state, ComponentId}).

%% @doc Returns the current terminal dimensions `{Rows, Cols}'.
-spec size(pid()) -> {pos_integer(), pos_integer()} | undefined.
size(Runtime) ->
    gen_server:call(Runtime, size).

%% @doc Copies `Text' to the system clipboard via OSC 52. No-op when running
%% with the `skip' backend (headless tests).
-spec copy_to_clipboard(binary()) -> ok.
copy_to_clipboard(Text) when is_binary(Text) ->
    case backend_mode() of
        raw -> educkui_terminal:copy_to_clipboard(Text);
        tty -> educkui_terminal:copy_to_clipboard(Text);
        _ -> ok
    end.

%% @doc Returns the buffered log events (oldest first).
-spec logs(pid()) -> [educkui_log:entry()].
logs(_Runtime) ->
    educkui_log:entries().

%% @doc Clears the log buffer.
-spec clear_logs(pid()) -> ok.
clear_logs(_Runtime) ->
    educkui_log:clear().

%% @doc Returns the active backend mode from the persistent term cache.
-spec backend_mode() -> raw | tty | skip | undefined.
backend_mode() ->
    persistent_term:get({educkui, backend_mode}, undefined).

%% @doc Returns detected terminal capabilities from the persistent term cache.
-spec capabilities() -> map() | undefined.
capabilities() ->
    persistent_term:get({educkui, capabilities}, undefined).

%% ---------------------------------------------------------------------------
%% gen_server callbacks
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> {ok, #dui_runtime_state{}} | {stop, term()}.
init(Opts) ->
    process_flag(trap_exit, true),
    Merged = educkui_config:merge_options(Opts),
    RootModule = proplists:get_value(root, Merged),
    RenderInterval = proplists:get_value(render_interval, Merged, 16),
    SkipTerminal = proplists:get_value(skip_terminal, Merged, false),
    BackendOpt = proplists:get_value(backend, Merged, auto),

    case init_backend(BackendOpt, SkipTerminal, Merged) of
        {error, Reason} ->
            {stop, Reason};
        {ok, BackendMode, Backend, BackendState, Dimensions, TerminalStarted} ->
            init_after_backend(#{
                root_module => RootModule,
                render_interval => RenderInterval,
                skip_terminal => SkipTerminal,
                backend_mode => BackendMode,
                backend => Backend,
                backend_state => BackendState,
                dimensions => Dimensions,
                terminal_started => TerminalStarted,
                merged => Merged
            })
    end.

-spec init_after_backend(map()) -> {ok, #dui_runtime_state{}}.
init_after_backend(#{root_module := RootModule} = Ctx) ->
    #{
        render_interval := RenderInterval,
        backend_mode := BackendMode,
        backend := Backend,
        backend_state := BackendState,
        dimensions := Dimensions,
        terminal_started := TerminalStarted,
        merged := Merged
    } = Ctx,

    {CurrentBuf, PreviousBuf} = create_buffers(Dimensions),
    {Rows, Cols} = Dimensions,

    {ok, Executor} = educkui_command_executor:start_link(),

    InitResult = RootModule:init(proplists:get_value(init_args, Merged, [])),
    {RootState, InitCommands} = educkui_elm:normalize_init_result(InitResult),

    {InputHandler, InputState, InputReader} = init_input(BackendMode),

    Capabilities = case BackendMode of
        skip -> undefined;
        _ -> educkui_capabilities:detect()
    end,

    persistent_term:put({educkui, backend_mode}, BackendMode),
    persistent_term:put({educkui, capabilities}, Capabilities),

    State = #dui_runtime_state{
        root_module = RootModule,
        root_state = RootState,
        render_interval = RenderInterval,
        terminal_started = TerminalStarted,
        current_buffer = CurrentBuf,
        previous_buffer = PreviousBuf,
        dimensions = Dimensions,
        backend_mode = BackendMode,
        backend = Backend,
        backend_state = BackendState,
        input_handler = InputHandler,
        input_state = InputState,
        input_reader = InputReader,
        command_executor = Executor,
        capabilities = Capabilities,
        dirty = true,
        last_render = undefined,
        focus = [root],
        targets = [],
        shortcuts = proplists:get_value(shortcuts, Merged, [])
    },

    State0 = install_log_handler(BackendMode, State),

    _ = case TerminalStarted of
        true -> educkui_signal_handler:install(self());
        false -> ok
    end,

    erlang:send_after(RenderInterval, self(), render_tick),

    State1 = execute_commands(root, InitCommands, State0),
    %% Deliver the initial terminal size to the root component so it can lay
    %% out without waiting for the first resize event.
    State2 = dispatch_root(educkui_event:resize(Cols, Rows), State1),
    {ok, State2}.

handle_call(sync, _From, State) ->
    {reply, ok, State};
handle_call(get_state, _From, State) ->
    {reply, State, State};
handle_call({get_component_state, ComponentId}, _From, State) ->
    Reply = case maps:find(ComponentId, State#dui_runtime_state.components) of
        {ok, Comp} -> {ok, Comp#dui_component.state};
        error -> error
    end,
    {reply, Reply, State};
handle_call(size, _From, State) ->
    {reply, State#dui_runtime_state.dimensions, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast({event, Event}, State) ->
    {noreply, process_event(Event, State)};
handle_cast({message, ComponentId, Message}, State) ->
    {noreply, process_event(educkui_event:custom(message, {ComponentId, Message}), State)};
handle_cast({set_props, ComponentId, Props}, State) ->
    {noreply, set_component_props(ComponentId, Props, State)};
handle_cast(force_render, State) ->
    {noreply, do_render(State)};
handle_cast(shutdown, State) ->
    {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(render_tick, State) ->
    Now = educkui_framerate_limiter:monotonic_ms(),
    ShouldRender =
        State#dui_runtime_state.dirty andalso
        educkui_framerate_limiter:should_render(
            State#dui_runtime_state.last_render, State#dui_runtime_state.render_interval),
    State1 = case ShouldRender of
        true -> do_render(State#dui_runtime_state{last_render = Now});
        false -> State
    end,
    erlang:send_after(State1#dui_runtime_state.render_interval, self(), render_tick),
    {noreply, State1};
handle_info({educkui_input, eof}, State) ->
    {stop, normal, State};
handle_info({educkui_input, Data}, State) when is_binary(Data) ->
    State1 = feed_input(State, Data),
    {noreply, State1};
handle_info(flush_escape, State) ->
    {noreply, flush_escape(State)};
handle_info({educkui_sigwinch}, State) ->
    {noreply, handle_sigwinch(State)};
handle_info({educkui_command, quit}, State) ->
    {stop, normal, State};
handle_info({command_result, ComponentId, Result}, State) ->
    Event = educkui_event:custom(command_result, {ComponentId, Result}),
    {noreply, process_event(Event, State)};
handle_info({educkui_interval, Ref, Msg, Ms}, State) ->
    handle_interval(Ref, Msg, Ms, State);
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    cleanup(State),
    ok.

%% ---------------------------------------------------------------------------
%% Backend setup
%% ---------------------------------------------------------------------------

-spec init_backend(atom(), boolean(), [{atom(), term()}]) ->
    {ok, raw | tty | skip, module() | undefined, term(), {pos_integer(), pos_integer()},
     boolean()} | {error, term()}.
init_backend(_BackendOpt, true, _Merged) ->
    {ok, skip, undefined, undefined, {24, 80}, false};
init_backend(BackendOpt, false, Merged) ->
    {ok, _TermPid} = educkui_terminal:start_link(),
    case educkui_backend_selector:select(BackendOpt) of
        {ok, {Mode, BackendMod}} ->
            BackendOpts = [{size, backend_size(Merged)}],
            case BackendMod:init(BackendOpts) of
                {ok, BState} ->
                    {ok, Dims} = BackendMod:size(BState),
                    {ok, Mode, BackendMod, BState, Dims, true};
                {error, Reason} ->
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec backend_size([{atom(), term()}]) -> {pos_integer(), pos_integer()} | undefined.
backend_size(Merged) ->
    case proplists:get_value(size, Merged, undefined) of
        {Rows, Cols} when Rows > 0, Cols > 0 -> {Rows, Cols};
        _ -> undefined
    end.

-spec init_input(raw | tty | skip) -> {module() | undefined, term(), pid() | undefined}.
init_input(skip) ->
    {undefined, undefined, undefined};
init_input(BackendMode) when BackendMode =:= raw; BackendMode =:= tty ->
    Handler = case BackendMode of
        raw -> educkui_input_raw;
        tty -> educkui_input_tty
    end,
    InputState = Handler:new(),
    Reader = Handler:start_reader(self()),
    {Handler, InputState, Reader}.

%% ---------------------------------------------------------------------------
%% Event processing
%% ---------------------------------------------------------------------------

-spec process_event(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
process_event(#dui_event{type = key} = Event, State) ->
    %% Global shortcuts take precedence over component routing.
    case educkui_shortcut:find(Event, State#dui_runtime_state.shortcuts) of
        {ok, {msg, Msg}} ->
            dispatch_root(educkui_event:custom(shortcut, Msg), State);
        {ok, Command} ->
            execute_commands(root, [Command], State);
        none ->
            process_key_event(Event, State)
    end;
process_event(Event, State) ->
    process_other_event(Event, State).

-spec process_key_event(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
process_key_event(#dui_event{key = tab, modifiers = Mods}, State) ->
    handle_tab(lists:member(shift, Mods), State);
process_key_event(Event, State) ->
    process_other_event(Event, State).

-spec process_other_event(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
process_other_event(#dui_event{type = resize} = Event, State) ->
    handle_resize(Event, State);
process_other_event(#dui_event{type = mouse, action = press, x = X, y = Y} = Event, State) ->
    case educkui_mouse:find_target(X, Y, State#dui_runtime_state.targets) of
        {ok, Id, Rect} ->
            %% Translate screen coordinates to component-local coordinates.
            LocalEvent = Event#dui_event{
                x = X - Rect#dui_rect.x,
                y = Y - Rect#dui_rect.y
            },
            OldFocus = educkui_focus:current(State#dui_runtime_state.focus),
            State1 = State#dui_runtime_state{
                focus = educkui_focus:focus(State#dui_runtime_state.focus, Id)},
            State2 = case OldFocus =:= Id of
                true -> State1;
                false -> dispatch(OldFocus, educkui_event:focus(lost), State1)
            end,
            State3 = dispatch(Id, educkui_event:focus(gained), State2),
            dispatch(Id, LocalEvent, State3);
        none ->
            State
    end;
process_other_event(Event, State) ->
    case educkui_event_router:route(Event, State#dui_runtime_state.focus,
                                    State#dui_runtime_state.targets) of
        ignore -> State;
        {route, Id, RoutedEvent} -> dispatch(Id, RoutedEvent, State)
    end.

-spec dispatch(term(), #dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
dispatch(root, Event, State) ->
    dispatch_root(Event, State);
dispatch(Id, Event, State) ->
    case maps:find(Id, State#dui_runtime_state.components) of
        {ok, Comp} ->
            Module = Comp#dui_component.module,
            case Module:event_to_msg(Event, Comp#dui_component.state) of
                {msg, Msg} ->
                    UpdateResult = Module:update(Msg, Comp#dui_component.state),
                    {NewState, Commands} =
                        educkui_elm:normalize_update_result(
                            UpdateResult, Comp#dui_component.state),
                    Comp1 = Comp#dui_component{state = NewState},
                    State1 = State#dui_runtime_state{
                        components = maps:put(Id, Comp1, State#dui_runtime_state.components),
                        dirty = true},
                    execute_commands(Id, Commands, State1);
                ignore -> State;
                propagate -> dispatch_root(Event, State)
            end;
        error ->
            State
    end.

-spec dispatch_root(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
dispatch_root(Event, State) ->
    RootModule = State#dui_runtime_state.root_module,
    RootState = State#dui_runtime_state.root_state,
    case RootModule:event_to_msg(Event, RootState) of
        {msg, Msg} ->
            UpdateResult = RootModule:update(Msg, RootState),
            {NewState, Commands} = educkui_elm:normalize_update_result(UpdateResult, RootState),
            State1 = State#dui_runtime_state{root_state = NewState, dirty = true},
            execute_commands(root, Commands, State1);
        ignore ->
            State;
        propagate ->
            State
    end.

-spec handle_tab(boolean(), #dui_runtime_state{}) -> #dui_runtime_state{}.
handle_tab(Shift, State) ->
    Order = State#dui_runtime_state.focus_order,
    OldFocus = educkui_focus:current(State#dui_runtime_state.focus),
    case OldFocus of
        undefined ->
            case Order of
                [] -> State;
                [First | _] ->
                    State1 = State#dui_runtime_state{focus = [First]},
                    dispatch(First, educkui_event:focus(gained), State1)
            end;
        _Current ->
            NewFocusStack = case Shift of
                true -> educkui_focus:prev(State#dui_runtime_state.focus, Order);
                false -> educkui_focus:next(State#dui_runtime_state.focus, Order)
            end,
            NewFocus = educkui_focus:current(NewFocusStack),
            case NewFocus =:= OldFocus of
                true -> State;
                false ->
                    State1 = dispatch(OldFocus, educkui_event:focus(lost),
                                      State#dui_runtime_state{focus = NewFocusStack}),
                    dispatch(NewFocus, educkui_event:focus(gained), State1)
            end
    end.

-spec execute_commands(term(), [term()], #dui_runtime_state{}) -> #dui_runtime_state{}.
execute_commands(_ComponentId, [], State) ->
    State;
execute_commands(ComponentId, Commands, State) ->
    {RuntimeCmds, ExecCmds} =
        lists:partition(fun is_runtime_cmd/1, Commands),
    State1 = lists:foldl(
        fun(Cmd, Acc) -> run_runtime_cmd(ComponentId, Cmd, Acc) end,
        State,
        RuntimeCmds),
    case ExecCmds of
        [] ->
            State1;
        _ ->
            educkui_command_executor:execute(
                State1#dui_runtime_state.command_executor,
                ComponentId, ExecCmds, self()),
            State1
    end.

%% @doc Updates a mounted component's state from new props.
-spec set_component_props(term(), map(), #dui_runtime_state{}) -> #dui_runtime_state{}.
set_component_props(ComponentId, Props, State) ->
    case maps:find(ComponentId, State#dui_runtime_state.components) of
        {ok, Comp} ->
            Module = Comp#dui_component.module,
            Comp1 = Comp#dui_component{props = Props},
            State1 = State#dui_runtime_state{
                components = maps:put(ComponentId, Comp1,
                                      State#dui_runtime_state.components),
                dirty = true},
            case erlang:function_exported(Module, handle_props, 2) of
                true ->
                    Result = Module:handle_props(Props, Comp#dui_component.state),
                    apply_props_result(ComponentId, Result, Comp1, State1);
                false ->
                    State1
            end;
        error ->
            State
    end.

-spec apply_props_result(term(), term(), #dui_component{}, #dui_runtime_state{}) ->
    #dui_runtime_state{}.
apply_props_result(_ComponentId, ignore, _Comp, State) ->
    State;
apply_props_result(ComponentId, Result, Comp, State) ->
    {NewState, Commands} =
        educkui_elm:normalize_update_result(Result, Comp#dui_component.state),
    Comp1 = Comp#dui_component{state = NewState},
    State1 = State#dui_runtime_state{
        components = maps:put(ComponentId, Comp1, State#dui_runtime_state.components),
        dirty = true},
    execute_commands(ComponentId, Commands, State1).

-spec is_runtime_cmd(term()) -> boolean().
is_runtime_cmd({focus, _}) -> true;
is_runtime_cmd({parent, _}) -> true;
is_runtime_cmd({interval, _, _, _}) -> true;
is_runtime_cmd({cancel_interval, _}) -> true;
is_runtime_cmd(_) -> false.

-spec run_runtime_cmd(term(), term(), #dui_runtime_state{}) -> #dui_runtime_state{}.
run_runtime_cmd(_ComponentId, {focus, Id}, State) ->
    set_focus(Id, State);
run_runtime_cmd(_ComponentId, {parent, Msg}, State) ->
    dispatch_root(educkui_event:custom(parent, Msg), State);
run_runtime_cmd(_ComponentId, {interval, Ref0, Msg, Ms}, State) ->
    Ref = case Ref0 of
        undefined -> make_ref();
        _ -> Ref0
    end,
    Timer = erlang:send_after(Ms, self(), {educkui_interval, Ref, Msg, Ms}),
    Timers = maps:put(Ref, Timer, State#dui_runtime_state.timers),
    State#dui_runtime_state{timers = Timers};
run_runtime_cmd(_ComponentId, {cancel_interval, Ref}, State) ->
    case maps:take(Ref, State#dui_runtime_state.timers) of
        {Timer, Rest} ->
            _ = erlang:cancel_timer(Timer),
            State#dui_runtime_state{timers = Rest};
        error ->
            State
    end.

%% @doc Handles a fired interval timer, dispatching the message as a `parent'
%% event to the root component and re-arming the timer.
-spec handle_interval(reference(), term(), pos_integer(), #dui_runtime_state{}) ->
    {noreply, #dui_runtime_state{}}.
handle_interval(Ref, Msg, Ms, State) ->
    case maps:is_key(Ref, State#dui_runtime_state.timers) of
        true ->
            State1 = dispatch_root(educkui_event:custom(parent, Msg), State),
            Timer = erlang:send_after(Ms, self(), {educkui_interval, Ref, Msg, Ms}),
            Timers = maps:put(Ref, Timer, State1#dui_runtime_state.timers),
            {noreply, State1#dui_runtime_state{timers = Timers}};
        false ->
            {noreply, State}
    end.

%% @doc Moves focus to `Id', sending focus-lost/gained events as needed.
-spec set_focus(term(), #dui_runtime_state{}) -> #dui_runtime_state{}.
set_focus(Id, State) ->
    OldFocus = educkui_focus:current(State#dui_runtime_state.focus),
    case OldFocus =:= Id of
        true ->
            State;
        false ->
            State1 = State#dui_runtime_state{
                focus = educkui_focus:focus(State#dui_runtime_state.focus, Id)},
            State2 = dispatch(OldFocus, educkui_event:focus(lost), State1),
            dispatch(Id, educkui_event:focus(gained), State2)
    end.

-spec handle_resize(#dui_event{}, #dui_runtime_state{}) -> #dui_runtime_state{}.
handle_resize(#dui_event{width = W, height = H}, State) when W > 0, H > 0 ->
    apply_resize(State, H, W);
handle_resize(_Event, State) ->
    State.

%% @doc Handles a SIGWINCH notification by re-detecting the terminal size.
-spec handle_sigwinch(#dui_runtime_state{}) -> #dui_runtime_state{}.
handle_sigwinch(State) ->
    {ok, {Rows, Cols}} = educkui_terminal_size:detect(),
    case State#dui_runtime_state.dimensions of
        {Rows, Cols} -> State;
        _ -> apply_resize(State, Rows, Cols)
    end.

-spec apply_resize(#dui_runtime_state{}, pos_integer(), pos_integer()) ->
    #dui_runtime_state{}.
apply_resize(State, Rows, Cols) ->
    {ok, NewCur} = educkui_buffer:resize(State#dui_runtime_state.current_buffer, Rows, Cols),
    {ok, NewPrev} = educkui_buffer:resize(State#dui_runtime_state.previous_buffer, Rows, Cols),
    State1 = State#dui_runtime_state{
        dimensions = {Rows, Cols},
        current_buffer = NewCur,
        previous_buffer = NewPrev,
        dirty = true
    },
    %% Notify the root component of the new size.
    dispatch_root(educkui_event:resize(Cols, Rows), State1).

-spec feed_input(#dui_runtime_state{}, binary()) -> #dui_runtime_state{}.
feed_input(#dui_runtime_state{input_handler = Handler, input_state = InputState} = State,
           Data) ->
    case Handler of
        undefined ->
            State;
        _ ->
            State0 = cancel_escape_timer(State),
            {Events, NewInputState} = Handler:feed(InputState, Data),
            State1 = lists:foldl(
                fun(Event, AccState) -> process_event(Event, AccState) end,
                State0#dui_runtime_state{input_state = NewInputState},
                Events),
            schedule_escape_flush(State1)
    end.

%% @doc Flushes a buffered partial escape sequence (lone ESC) into an `esc'
%% key event once the escape timeout has elapsed.
-spec flush_escape(#dui_runtime_state{}) -> #dui_runtime_state{}.
flush_escape(#dui_runtime_state{input_handler = Handler, input_state = InputState} = State) ->
    State0 = State#dui_runtime_state{escape_timer = undefined},
    case Handler of
        undefined -> State0;
        _ ->
            {Events, NewInputState} = Handler:flush_partial(InputState),
            lists:foldl(
                fun(Event, AccState) -> process_event(Event, AccState) end,
                State0#dui_runtime_state{input_state = NewInputState},
                Events)
    end.

-spec schedule_escape_flush(#dui_runtime_state{}) -> #dui_runtime_state{}.
schedule_escape_flush(#dui_runtime_state{input_state = InputState} = State) ->
    Buffer = maps:get(buffer, InputState, <<>>),
    case Buffer of
        <<>> -> State;
        _ ->
            Timer = erlang:send_after(50, self(), flush_escape),
            State#dui_runtime_state{escape_timer = Timer}
    end.

-spec cancel_escape_timer(#dui_runtime_state{}) -> #dui_runtime_state{}.
cancel_escape_timer(#dui_runtime_state{escape_timer = undefined} = State) ->
    State;
cancel_escape_timer(#dui_runtime_state{escape_timer = Timer} = State) ->
    _ = erlang:cancel_timer(Timer),
    State#dui_runtime_state{escape_timer = undefined}.

%% ---------------------------------------------------------------------------
%% Rendering
%% ---------------------------------------------------------------------------

-spec do_render(#dui_runtime_state{}) -> #dui_runtime_state{}.
do_render(#dui_runtime_state{root_module = RootModule, root_state = RootState,
                             dimensions = {Rows, Cols}} = State) ->
    View = RootModule:view(RootState),
    Rect = #dui_rect{width = Cols, height = Rows},
    {Cells, Components, Targets, Order} =
        educkui_render:render(View, Rect, State#dui_runtime_state.components),

    Cur = State#dui_runtime_state.current_buffer,
    Prev = State#dui_runtime_state.previous_buffer,
    educkui_buffer:clear(Cur),
    %% `educkui_render:render/3' returns `{Col, Row, Cell}' (0-based), while
    %% `educkui_buffer:set_cells/2' expects `{Row, Col, Cell}' (1-based).
    educkui_buffer:set_cells(Cur, [{Y + 1, X + 1, Cell} || {X, Y, Cell} <- Cells]),

    State0 = State#dui_runtime_state{
        components = Components,
        targets = Targets,
        focus_order = Order
    },
    State1 = output_changed(State0, changed_cells(Cur, Prev, Rows, Cols)),
    State1#dui_runtime_state{
        current_buffer = Prev,
        previous_buffer = Cur,
        dirty = false
    }.

-spec output_changed(#dui_runtime_state{},
    [{educkui_backend:position(), #dui_cell{}}]) -> #dui_runtime_state{}.
output_changed(#dui_runtime_state{backend = undefined} = State, _Changed) ->
    State;
output_changed(#dui_runtime_state{backend = Backend, backend_state = BState} = State, []) ->
    _ = Backend:flush(BState),
    State;
output_changed(#dui_runtime_state{backend = Backend, backend_state = BState} = State,
               Changed) ->
    {ok, BState1} = Backend:draw_cells(BState, Changed),
    {ok, BState2} = Backend:flush(BState1),
    State#dui_runtime_state{backend_state = BState2}.

-spec changed_cells(#dui_buffer{}, #dui_buffer{}, pos_integer(), pos_integer()) ->
    [{educkui_backend:position(), #dui_cell{}}].
changed_cells(Cur, Prev, Rows, Cols) ->
    lists:flatmap(
        fun(Row) ->
            CurRow = educkui_buffer:get_row(Cur, Row),
            PrevRow = educkui_buffer:get_row(Prev, Row),
            [{ {Row, Col}, Cell}
             || {Col, Cell, PrevCell} <- lists:zip3(lists:seq(1, Cols), CurRow, PrevRow),
                not educkui_cell:equal(Cell, PrevCell)]
        end,
        lists:seq(1, Rows)).

%% ---------------------------------------------------------------------------
%% Helpers / cleanup
%% ---------------------------------------------------------------------------

-spec create_buffers({pos_integer(), pos_integer()}) -> {#dui_buffer{}, #dui_buffer{}}.
create_buffers({Rows, Cols}) ->
    {ok, Cur} = educkui_buffer:new(Rows, Cols),
    {ok, Prev} = educkui_buffer:new(Rows, Cols),
    {Cur, Prev}.

-spec cleanup(#dui_runtime_state{}) -> ok.
cleanup(State) ->
    catch cancel_timers(State),
    catch remove_log_handler(State),
    catch educkui_signal_handler:uninstall(self()),
    catch stop_reader(State#dui_runtime_state.input_reader),
    catch shutdown_backend(State#dui_runtime_state.backend, State#dui_runtime_state.backend_state),
    catch restore_terminal(State#dui_runtime_state.terminal_started),
    catch stop_executor(State#dui_runtime_state.command_executor),
    catch destroy_buffers(State#dui_runtime_state.current_buffer,
                          State#dui_runtime_state.previous_buffer),
    persistent_term:erase({educkui, backend_mode}),
    persistent_term:erase({educkui, capabilities}),
    ok.

%% @doc Cancels all pending interval timers.
-spec cancel_timers(#dui_runtime_state{}) -> ok.
cancel_timers(#dui_runtime_state{timers = Timers}) ->
    maps:foreach(fun(_Ref, Timer) -> _ = erlang:cancel_timer(Timer) end, Timers),
    ok.

%% @doc Installs the in-memory logger handler and silences the terminal
%% handlers while the alternate screen is active. No-op for the skip backend.
-spec install_log_handler(raw | tty | skip, #dui_runtime_state{}) ->
    #dui_runtime_state{}.
install_log_handler(skip, State) ->
    State;
install_log_handler(_Mode, State) ->
    _ = educkui_log:ensure_started(),
    _ = catch logger:add_handler(educkui_log, educkui_log_handler, #{level => all}),
    Existing = [Id || Id <- logger:get_handler_ids(), Id =/= educkui_log],
    lists:foreach(
        fun(Id) ->
            _ = logger:add_handler_filter(Id, educkui_silence,
                                          {fun(_Event, _Extra) -> stop end, #{}})
        end,
        Existing),
    State#dui_runtime_state{logger_handler_config = Existing}.

%% @doc Removes the log handler and restores terminal log handlers.
-spec remove_log_handler(#dui_runtime_state{}) -> ok.
remove_log_handler(#dui_runtime_state{logger_handler_config = undefined}) ->
    ok;
remove_log_handler(#dui_runtime_state{logger_handler_config = Existing}) ->
    lists:foreach(
        fun(Id) -> _ = logger:remove_handler_filter(Id, educkui_silence) end,
        Existing),
    _ = logger:remove_handler(educkui_log),
    ok.

-spec stop_reader(pid() | undefined) -> ok.
stop_reader(undefined) -> ok;
stop_reader(Pid) ->
    exit(Pid, kill),
    ok.

-spec shutdown_backend(module() | undefined, term()) -> ok.
shutdown_backend(undefined, _BState) -> ok;
shutdown_backend(Backend, BState) ->
    _ = Backend:shutdown(BState),
    ok.

-spec restore_terminal(boolean()) -> ok.
restore_terminal(true) ->
    _ = educkui_terminal:restore(),
    catch gen_server:stop(educkui_terminal),
    ok;
restore_terminal(false) ->
    ok.

-spec stop_executor(pid() | undefined) -> ok.
stop_executor(undefined) -> ok;
stop_executor(Pid) ->
    catch gen_server:stop(Pid),
    ok.

-spec destroy_buffers(#dui_buffer{} | undefined, #dui_buffer{} | undefined) -> ok.
destroy_buffers(undefined, _Prev) -> ok;
destroy_buffers(Cur, Prev) ->
    educkui_buffer:destroy(Cur),
    educkui_buffer:destroy(Prev),
    ok.
