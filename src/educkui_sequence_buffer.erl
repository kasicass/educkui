%% @doc Batches escape sequences for efficient terminal output.
%%
%% Accumulates escape sequences and text in a deep iolist (never flattened,
%% per the OTP Efficiency Guide), flushes when a size threshold is reached,
%% and tracks SGR state so that only style deltas are emitted.
%%
%% The buffer is pure: flushed data is returned to the caller, who owns the
%% actual terminal write.
-module(educkui_sequence_buffer).

-include("educkui.hrl").

-export([
    new/0, new/1,
    append/2,
    append_style/2,
    flush/1,
    size/1,
    is_empty/1,
    stats/1,
    to_iodata/1,
    reset_style/1,
    clear/1
]).

%% ---------------------------------------------------------------------------
%% Construction
%% ---------------------------------------------------------------------------

-spec new() -> #dui_seqbuf{}.
new() -> #dui_seqbuf{}.

-spec new(list()) -> #dui_seqbuf{}.
new(Opts) when is_list(Opts) ->
    Threshold = proplists:get_value(threshold, Opts, 4096),
    #dui_seqbuf{threshold = Threshold}.

%% ---------------------------------------------------------------------------
%% Appending
%% ---------------------------------------------------------------------------

%% @doc Appends data. Returns `{ok, Buf}' normally or
%% `{flush, Data, Buf}' if the threshold was exceeded (caller must write
%% `Data').
-spec append(#dui_seqbuf{}, iodata()) ->
    {ok, #dui_seqbuf{}} | {flush, iodata(), #dui_seqbuf{}}.
append(#dui_seqbuf{buffer = Buf, size = Size, threshold = Threshold} = S, Data) ->
    DataSize = iolist_size(Data),
    NewSize = Size + DataSize,
    NewBuf = S#dui_seqbuf{buffer = [Data | Buf], size = NewSize},
    case NewSize >= Threshold of
        true ->
            {Flushed, Reset} = flush(NewBuf),
            {flush, Flushed, Reset};
        false ->
            {ok, NewBuf}
    end.

%% @doc Appends a style, emitting an SGR sequence with only the parameters
%% that changed since the previous style.
-spec append_style(#dui_seqbuf{}, #dui_style{}) ->
    {ok, #dui_seqbuf{}} | {flush, iodata(), #dui_seqbuf{}}.
append_style(#dui_seqbuf{last_style = Last} = S, #dui_style{} = Style) ->
    Params = style_to_sgr_params(Style, Last),
    case Params of
        [] ->
            {ok, S};
        _ ->
            Seq = educkui_sgr:build_sequence(Params),
            case append(S, Seq) of
                {ok, S2} -> {ok, S2#dui_seqbuf{last_style = Style}};
                {flush, Data, S2} -> {flush, Data, S2#dui_seqbuf{last_style = Style}}
            end
    end.

%% ---------------------------------------------------------------------------
%% Flush / queries
%% ---------------------------------------------------------------------------

-spec flush(#dui_seqbuf{}) -> {iodata(), #dui_seqbuf{}}.
flush(#dui_seqbuf{buffer = Buf, size = Size, total_bytes = Total, flush_count = Count} = S) ->
    New = S#dui_seqbuf{
        buffer = [],
        size = 0,
        total_bytes = Total + Size,
        flush_count = Count + 1
    },
    {lists:reverse(Buf), New}.

-spec size(#dui_seqbuf{}) -> non_neg_integer().
size(#dui_seqbuf{size = Size}) -> Size.

-spec is_empty(#dui_seqbuf{}) -> boolean().
is_empty(#dui_seqbuf{size = 0}) -> true;
is_empty(#dui_seqbuf{}) -> false.

-spec stats(#dui_seqbuf{}) -> {non_neg_integer(), non_neg_integer()}.
stats(#dui_seqbuf{total_bytes = Bytes, flush_count = Count}) ->
    {Bytes, Count}.

-spec to_iodata(#dui_seqbuf{}) -> iolist().
to_iodata(#dui_seqbuf{buffer = Buf}) ->
    lists:reverse(Buf).

-spec reset_style(#dui_seqbuf{}) -> #dui_seqbuf{}.
reset_style(S) ->
    S#dui_seqbuf{last_style = undefined}.

-spec clear(#dui_seqbuf{}) -> #dui_seqbuf{}.
clear(S) ->
    S#dui_seqbuf{buffer = [], size = 0}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec style_to_sgr_params(#dui_style{}, #dui_style{} | undefined) -> [string()].
style_to_sgr_params(#dui_style{} = Style, undefined) ->
    build_full_sgr_params(Style);
style_to_sgr_params(#dui_style{} = Style, #dui_style{} = Last) ->
    Fg0 = [],
    Fg1 = case educkui_style:fg(Style) =/= educkui_style:fg(Last) of
        true -> [educkui_sgr:color_param(fg, pick_default(educkui_style:fg(Style))) | Fg0];
        false -> Fg0
    end,
    Bg1 = case educkui_style:bg(Style) =/= educkui_style:bg(Last) of
        true -> [educkui_sgr:color_param(bg, pick_default(educkui_style:bg(Style))) | Fg1];
        false -> Fg1
    end,
    NewAttrs = ordsets:subtract(educkui_style:attrs(Style), educkui_style:attrs(Last)),
    WithNew = lists:foldl(
        fun(A, Acc) -> [educkui_sgr:attr_param(A) | Acc] end,
        Bg1,
        NewAttrs),
    RemovedAttrs = ordsets:subtract(educkui_style:attrs(Last), educkui_style:attrs(Style)),
    WithRemoved = lists:foldl(
        fun(A, Acc) -> [educkui_sgr:attr_off_param(A) | Acc] end,
        WithNew,
        RemovedAttrs),
    [P || P <- lists:reverse(WithRemoved), P =/= undefined].

-spec build_full_sgr_params(#dui_style{}) -> [string()].
build_full_sgr_params(#dui_style{} = Style) ->
    Fg = educkui_style:fg(Style),
    Bg = educkui_style:bg(Style),
    P0 = [],
    P1 = case Fg =/= undefined andalso Fg =/= default of
        true -> [educkui_sgr:color_param(fg, Fg) | P0];
        false -> P0
    end,
    P2 = case Bg =/= undefined andalso Bg =/= default of
        true -> [educkui_sgr:color_param(bg, Bg) | P1];
        false -> P1
    end,
    P3 = lists:foldl(
        fun(A, Acc) -> [educkui_sgr:attr_param(A) | Acc] end,
        P2,
        educkui_style:attrs(Style)),
    [P || P <- lists:reverse(P3), P =/= undefined].

-spec pick_default(term()) -> term().
pick_default(undefined) -> default;
pick_default(C) -> C.
