%% @doc TTY fallback backend for constrained environments.
%%
%% Unlike the raw backend, the TTY backend does not activate raw mode or the
%% alternate screen. It performs simple full redraws using absolute cursor
%% positioning, which works over pipes, SSH sessions and remote consoles.
-module(educkui_backend_tty).

-behaviour(educkui_backend).

-include("educkui.hrl").

-export([init/1, shutdown/1, size/1, move_cursor/2, hide_cursor/1, show_cursor/1,
         clear/1, draw_cells/2, flush/1, poll_event/2]).

%% ---------------------------------------------------------------------------
%% Lifecycle
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> {ok, map()}.
init(Opts) ->
    Size = case proplists:get_value(size, Opts, undefined) of
        {Rows, Cols} when Rows > 0, Cols > 0 -> {Rows, Cols};
        _ ->
            case educkui_terminal_size:detect() of
                {ok, S} -> S
            end
    end,
    {ok, #{size => Size, cursor_position => {1, 1}}}.

-spec shutdown(map()) -> ok.
shutdown(_State) -> ok.

%% ---------------------------------------------------------------------------
%% Queries / cursor
%% ---------------------------------------------------------------------------

-spec size(map()) -> {ok, educkui_backend:size()}.
size(State) -> {ok, maps:get(size, State)}.

-spec move_cursor(map(), educkui_backend:position()) -> {ok, map()}.
move_cursor(State, {Row, Col}) ->
    educkui_term_utils:write(educkui_ansi:cursor_position(Row, Col)),
    {ok, State#{cursor_position := {Row, Col}}}.

-spec hide_cursor(map()) -> {ok, map()}.
hide_cursor(State) ->
    educkui_term_utils:write(educkui_ansi:cursor_hide()),
    {ok, State}.

-spec show_cursor(map()) -> {ok, map()}.
show_cursor(State) ->
    educkui_term_utils:write(educkui_ansi:cursor_show()),
    {ok, State}.

%% ---------------------------------------------------------------------------
%% Rendering (full redraw)
%% ---------------------------------------------------------------------------

-spec clear(map()) -> {ok, map()}.
clear(State) ->
    educkui_term_utils:write(educkui_ansi:clear_screen()),
    {ok, State#{cursor_position := {1, 1}}}.

-spec draw_cells(map(), [{educkui_backend:position(), #dui_cell{}}]) -> {ok, map()}.
draw_cells(State, Cells) ->
    educkui_term_utils:write(educkui_ansi:clear_screen()),
    Sorted = lists:sort(
        fun({{R1, C1}, _}, {{R2, C2}, _}) -> {R1, C1} =< {R2, C2} end,
        Cells),
    lists:foreach(
        fun({{Row, Col}, Cell}) ->
            Out = [
                educkui_ansi:cursor_position(Row, Col),
                color_sequence(fg, Cell#dui_cell.fg),
                color_sequence(bg, Cell#dui_cell.bg),
                [educkui_sgr:attr_sequence(A) || A <- Cell#dui_cell.attrs],
                Cell#dui_cell.char
            ],
            educkui_term_utils:write(Out)
        end,
        Sorted),
    {ok, State}.

-spec flush(map()) -> {ok, map()}.
flush(State) -> {ok, State}.

%% ---------------------------------------------------------------------------
%% Input (stub in phase 3)
%% ---------------------------------------------------------------------------

-spec poll_event(map(), non_neg_integer()) -> {timeout, map()}.
poll_event(State, _Timeout) -> {timeout, State}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec color_sequence(fg | bg, term()) -> iodata().
color_sequence(_Type, default) -> [];
color_sequence(Type, Color) -> educkui_sgr:color_sequence(Type, Color).
