%% @doc Raw terminal backend.
%%
%% Assumes raw mode has already been activated (by the selector via
%% `educkui_terminal:activate_raw_mode/0'). Performs alternate screen, cursor,
%% mouse and rendering setup, and draws cells using run detection, cursor
%% optimization and style deltas.
-module(educkui_backend_raw).

-behaviour(educkui_backend).

-include("educkui.hrl").

-export([init/1, shutdown/1, size/1, move_cursor/2, hide_cursor/1, show_cursor/1,
         clear/1, draw_cells/2, flush/1, poll_event/2]).

-define(MOUSE_OFF, <<"\e[?1006l\e[?1003l\e[?1002l\e[?1000l">>).

%% ---------------------------------------------------------------------------
%% Lifecycle
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> {ok, map()} | {error, term()}.
init(Opts) ->
    Alternate = proplists:get_value(alternate_screen, Opts, true),
    HideCursor = proplists:get_value(hide_cursor, Opts, true),
    Mouse = proplists:get_value(mouse_tracking, Opts, none),
    Optimize = proplists:get_value(optimize_cursor, Opts, true),
    Size = resolve_size(proplists:get_value(size, Opts, undefined)),

    case Alternate of
        true -> educkui_term_utils:write(educkui_ansi:enter_alternate_screen());
        false -> ok
    end,
    case HideCursor of
        true -> educkui_term_utils:write(educkui_ansi:cursor_hide());
        false -> ok
    end,
    enable_mouse(Mouse),
    educkui_term_utils:write(educkui_ansi:clear_screen()),
    educkui_term_utils:write(educkui_ansi:cursor_position(1, 1)),

    {ok, #{
        size => Size,
        cursor_visible => not HideCursor,
        cursor_position => {1, 1},
        alternate_screen => Alternate,
        mouse_mode => Mouse,
        current_style => undefined,
        optimize_cursor => Optimize,
        input_buffer => <<>>,
        event_queue => []
    }}.

-spec shutdown(map()) -> ok.
shutdown(State) ->
    educkui_term_utils:write(?MOUSE_OFF),
    educkui_term_utils:write(educkui_ansi:cursor_show()),
    educkui_term_utils:write(educkui_ansi:reset()),
    case maps:get(alternate_screen, State) of
        true -> educkui_term_utils:write(educkui_ansi:leave_alternate_screen());
        false -> ok
    end,
    ok.

%% ---------------------------------------------------------------------------
%% Queries
%% ---------------------------------------------------------------------------

-spec size(map()) -> {ok, educkui_backend:size()}.
size(State) ->
    {ok, maps:get(size, State)}.

%% ---------------------------------------------------------------------------
%% Cursor
%% ---------------------------------------------------------------------------

-spec move_cursor(map(), educkui_backend:position()) -> {ok, map()}.
move_cursor(State, {Row, Col}) ->
    educkui_term_utils:write(educkui_ansi:cursor_position(Row, Col)),
    {ok, State#{cursor_position := {Row, Col}}}.

-spec hide_cursor(map()) -> {ok, map()}.
hide_cursor(State) ->
    educkui_term_utils:write(educkui_ansi:cursor_hide()),
    {ok, State#{cursor_visible := false}}.

-spec show_cursor(map()) -> {ok, map()}.
show_cursor(State) ->
    educkui_term_utils:write(educkui_ansi:cursor_show()),
    {ok, State#{cursor_visible := true}}.

%% ---------------------------------------------------------------------------
%% Rendering
%% ---------------------------------------------------------------------------

-spec clear(map()) -> {ok, map()}.
clear(State) ->
    educkui_term_utils:write(educkui_ansi:clear_screen()),
    educkui_term_utils:write(educkui_ansi:cursor_position(1, 1)),
    {ok, State#{cursor_position := {1, 1}}}.

-spec draw_cells(map(), [{educkui_backend:position(), #dui_cell{}}]) -> {ok, map()}.
draw_cells(State, []) ->
    {ok, State};
draw_cells(State, Cells) ->
    Sorted = lists:sort(
        fun({{R1, C1}, _}, {{R2, C2}, _}) -> {R1, C1} =< {R2, C2} end,
        Cells),
    Runs = detect_runs(Sorted),
    Optimize = maps:get(optimize_cursor, State, true),
    {Output, FinalPos, FinalStyle} =
        render_runs(Runs, maps:get(cursor_position, State),
                    maps:get(current_style, State), Optimize),
    educkui_term_utils:write(Output),
    {ok, State#{cursor_position := FinalPos, current_style := FinalStyle}}.

-spec flush(map()) -> {ok, map()}.
flush(State) ->
    {ok, State}.

%% ---------------------------------------------------------------------------
%% Input (stub in phase 3; real input arrives in phase 4)
%% ---------------------------------------------------------------------------

-spec poll_event(map(), non_neg_integer()) -> {timeout, map()}.
poll_event(State, _Timeout) ->
    {timeout, State}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec resolve_size({pos_integer(), pos_integer()} | undefined) ->
    {pos_integer(), pos_integer()}.
resolve_size({Rows, Cols}) when Rows > 0, Cols > 0 ->
    {Rows, Cols};
resolve_size(_) ->
    case educkui_terminal_size:detect() of
        {ok, Size} -> Size
    end.

-spec enable_mouse(none | click | drag | all) -> ok.
enable_mouse(none) -> ok;
enable_mouse(Mode) ->
    AnsiMode = case Mode of
        click -> normal;
        drag -> button;
        all -> all
    end,
    educkui_term_utils:write([
        educkui_ansi:enable_mouse_tracking(AnsiMode),
        educkui_ansi:enable_sgr_mouse()
    ]),
    ok.

%% Detects contiguous runs: same row, consecutive columns.
-spec detect_runs([{educkui_backend:position(), #dui_cell{}}]) ->
    [[{educkui_backend:position(), #dui_cell{}}]].
detect_runs([]) -> [];
detect_runs([First | Rest]) ->
    {CurrentRun, Completed} =
        lists:foldl(
            fun(Cell, {CurRun, CompletedRuns}) ->
                {{PrevRow, PrevCol}, _} = hd(CurRun),
                case Cell of
                    {{Row, Col}, _} when Row =:= PrevRow, Col =:= PrevCol + 1 ->
                        {[Cell | CurRun], CompletedRuns};
                    _ ->
                        {[Cell], [lists:reverse(CurRun) | CompletedRuns]}
                end
            end,
            {[First], []},
            Rest),
    lists:reverse([lists:reverse(CurrentRun) | Completed]).

-spec render_runs([[{educkui_backend:position(), #dui_cell{}}]],
    educkui_backend:position() | undefined, #dui_style{} | undefined, boolean()) ->
    {iodata(), educkui_backend:position(), #dui_style{}}.
render_runs(Runs, InitialPos, InitialStyle, Optimize) ->
    lists:foldl(
        fun(Run, {OutAcc, CurPos, CurStyle}) ->
            {RunOut, EndPos, EndStyle} = render_run(Run, CurPos, CurStyle, Optimize),
            {[OutAcc, RunOut], EndPos, EndStyle}
        end,
        {[], InitialPos, InitialStyle},
        Runs).

-spec render_run([{educkui_backend:position(), #dui_cell{}}],
    educkui_backend:position() | undefined, #dui_style{} | undefined, boolean()) ->
    {iodata(), educkui_backend:position(), #dui_style{}}.
render_run([{{Row, Col}, _} | _] = Run, CurPos, CurStyle, Optimize) ->
    CursorOut = cursor_move_output(CurPos, {Row, Col}, Optimize),
    {CharsOut, EndCol, EndStyle} =
        lists:foldl(
            fun({{_R, _C}, Cell}, {OutAcc, CurCol, Style}) ->
                NewStyle = cell_to_style(Cell),
                StyleOut = style_delta_output(Style, NewStyle),
                {[OutAcc, StyleOut, Cell#dui_cell.char],
                 CurCol + educkui_cell:width(Cell), NewStyle}
            end,
            {[], Col, CurStyle},
            Run),
    {[CursorOut, CharsOut], {Row, EndCol}, EndStyle}.

-spec cursor_move_output(educkui_backend:position() | undefined,
    educkui_backend:position(), boolean()) -> iodata().
cursor_move_output(undefined, {Row, Col}, _Optimize) ->
    educkui_ansi:cursor_position(Row, Col);
cursor_move_output({Row, Col}, {Row, Col}, _Optimize) ->
    [];
cursor_move_output({CurRow, CurCol}, {Row, Col}, true) ->
    Opt = educkui_cursor_optimizer:new(CurRow, CurCol),
    {Seq, _} = educkui_cursor_optimizer:move_to(Opt, Row, Col),
    Seq;
cursor_move_output(_CurPos, {Row, Col}, false) ->
    educkui_ansi:cursor_position(Row, Col).

-spec style_delta_output(#dui_style{} | undefined, #dui_style{}) -> iodata().
style_delta_output(undefined, NewStyle) ->
    build_full_style(NewStyle);
style_delta_output(CurrentStyle, NewStyle) ->
    case educkui_style:equal(CurrentStyle, NewStyle) of
        true ->
            [];
        false ->
            Removed = ordsets:subtract(
                educkui_style:attrs(CurrentStyle), educkui_style:attrs(NewStyle)),
            case Removed of
                [] -> build_style_delta(CurrentStyle, NewStyle);
                _ -> [educkui_ansi:reset(), build_full_style(NewStyle)]
            end
    end.

-spec build_full_style(#dui_style{}) -> iodata().
build_full_style(#dui_style{} = Style) ->
    [
        color_sequence(fg, educkui_style:fg(Style)),
        color_sequence(bg, educkui_style:bg(Style)),
        [educkui_sgr:attr_sequence(A) || A <- educkui_style:attrs(Style)]
    ].

-spec build_style_delta(#dui_style{}, #dui_style{}) -> iodata().
build_style_delta(CurrentStyle, NewStyle) ->
    D0 = [],
    D1 = case educkui_style:fg(NewStyle) =/= educkui_style:fg(CurrentStyle) of
        true -> [color_sequence(fg, educkui_style:fg(NewStyle)) | D0];
        false -> D0
    end,
    D2 = case educkui_style:bg(NewStyle) =/= educkui_style:bg(CurrentStyle) of
        true -> [color_sequence(bg, educkui_style:bg(NewStyle)) | D1];
        false -> D1
    end,
    NewAttrs = ordsets:subtract(
        educkui_style:attrs(NewStyle), educkui_style:attrs(CurrentStyle)),
    lists:foldl(
        fun(A, Acc) -> [educkui_sgr:attr_sequence(A) | Acc] end,
        D2,
        NewAttrs).

-spec color_sequence(fg | bg, term()) -> iodata().
color_sequence(_Type, default) -> [];
color_sequence(Type, Color) -> educkui_sgr:color_sequence(Type, Color).

-spec cell_to_style(#dui_cell{}) -> #dui_style{}.
cell_to_style(#dui_cell{fg = Fg, bg = Bg, attrs = Attrs}) ->
    #dui_style{fg = Fg, bg = Bg, attrs = Attrs}.
