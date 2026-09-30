%% @doc Behaviour defining the contract for terminal backends.
%%
%% A backend owns terminal state and performs all terminal I/O (cursor,
%% screen, rendering, input). Two implementations are provided:
%% - `educkui_backend_raw' - full terminal control (raw mode)
%% - `educkui_backend_tty' - fallback for constrained environments
-module(educkui_backend).

-export_type([position/0, size/0, color/0, cell/0, event/0, state/0]).

-type position() :: {pos_integer(), pos_integer()}.
-type size() :: {pos_integer(), pos_integer()}.
-type color() :: default | atom() | 0..255 | {0..255, 0..255, 0..255}.
-type cell() :: tuple().
-type event() :: term().
-type state() :: term().

-callback init([{atom(), term()}]) -> {ok, state()} | {error, term()}.
-callback shutdown(state()) -> ok.
-callback size(state()) -> {ok, size()} | {error, enotsup}.
-callback move_cursor(state(), position()) -> {ok, state()}.
-callback hide_cursor(state()) -> {ok, state()}.
-callback show_cursor(state()) -> {ok, state()}.
-callback clear(state()) -> {ok, state()}.
-callback draw_cells(state(), [{position(), cell()}]) -> {ok, state()}.
-callback flush(state()) -> {ok, state()}.
-callback poll_event(state(), non_neg_integer()) ->
    {ok, event(), state()} | {timeout, state()} | {error, term(), state()}.
