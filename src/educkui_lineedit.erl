%% @doc A pure, grapheme-aware single-line editor.
%%
%% This module implements the editing model shared by `educkui_widget_text_input',
%% `educkui_widget_form_builder' and any application that wants a text field
%% without embedding a stateful widget. It is intentionally free of processes,
%% rendering and terminal concerns: it only tracks a value and a cursor
%% position, both measured in grapheme clusters.
%%
%% All operations are total (no exceptions) and return a new state.
%%
%% Example:
%%
%% ```
%% LE0 = educkui_lineedit:new(<<"ab">>),        %% cursor at end (2)
%% LE1 = educkui_lineedit:move(LE0, left),      %% cursor 1
%% LE2 = educkui_lineedit:insert(LE1, <<"X">>), %% value <<"aXb">>
%% <<"aXb">> = educkui_lineedit:value(LE2).
%% '''
-module(educkui_lineedit).

-export([
    new/0, new/1, new/2,
    value/1,
    cursor/1,
    length/1,
    set_value/2,
    set_cursor/2,
    insert/2,
    backspace/1,
    delete/1,
    move/2,
    home/1,
    'end'/1
]).

-record(lineedit, {
    value = <<>> :: binary(),
    cursor = 0 :: non_neg_integer()
}).

-opaque state() :: #lineedit{}.
-export_type([state/0]).

%% ---------------------------------------------------------------------------
%% Construction / accessors
%% ---------------------------------------------------------------------------

%% @doc Returns an empty editor.
-spec new() -> state().
new() -> #lineedit{}.

%% @doc Returns an editor with `Value' and the cursor at the end.
-spec new(binary()) -> state().
new(Value) when is_binary(Value) ->
    #lineedit{value = Value, cursor = string:length(Value)}.

%% @doc Returns an editor with `Value' and the cursor clamped to `Cursor'.
-spec new(binary(), non_neg_integer()) -> state().
new(Value, Cursor) when is_binary(Value), is_integer(Cursor), Cursor >= 0 ->
    set_cursor(Cursor, #lineedit{value = Value, cursor = 0}).

%% @doc Returns the current value.
-spec value(state()) -> binary().
value(#lineedit{value = Value}) -> Value.

%% @doc Returns the cursor position in grapheme clusters.
-spec cursor(state()) -> non_neg_integer().
cursor(#lineedit{cursor = Cursor}) -> Cursor.

%% @doc Returns the value length in grapheme clusters.
-spec length(state()) -> non_neg_integer().
length(#lineedit{value = Value}) -> string:length(Value).

%% @doc Replaces the value, clamping the cursor to the new length.
-spec set_value(binary(), state()) -> state().
set_value(Value, #lineedit{} = S) when is_binary(Value) ->
    set_cursor(S#lineedit.cursor, S#lineedit{value = Value}).

%% @doc Moves the cursor to `Cursor' (clamped to `[0, length]').
-spec set_cursor(non_neg_integer(), state()) -> state().
set_cursor(Cursor, #lineedit{value = Value} = S)
        when is_integer(Cursor), Cursor >= 0 ->
    Max = string:length(Value),
    S#lineedit{cursor = min(Max, Cursor)}.

%% ---------------------------------------------------------------------------
%% Editing
%% ---------------------------------------------------------------------------

%% @doc Inserts `Text' (one or more grapheme clusters) at the cursor.
-spec insert(binary(), state()) -> state().
insert(Text, #lineedit{value = Value, cursor = Cursor} = S) when is_binary(Text) ->
    {Left, Right} = split_at(Value, Cursor),
    N = string:length(Text),
    S#lineedit{value = <<Left/binary, Text/binary, Right/binary>>,
               cursor = Cursor + N}.

%% @doc Deletes the grapheme cluster before the cursor (no-op at start).
-spec backspace(state()) -> state().
backspace(#lineedit{cursor = 0} = S) ->
    S;
backspace(#lineedit{value = Value, cursor = Cursor} = S) ->
    {Left, Right} = split_at(Value, Cursor),
    Left2 = string:slice(Left, 0, string:length(Left) - 1),
    S#lineedit{value = <<Left2/binary, Right/binary>>, cursor = Cursor - 1}.

%% @doc Deletes the grapheme cluster at the cursor (no-op at end).
-spec delete(state()) -> state().
delete(#lineedit{value = Value, cursor = Cursor} = S) ->
    case Cursor < string:length(Value) of
        true ->
            {Left, Right} = split_at(Value, Cursor),
            Right2 = string:slice(Right, 1),
            S#lineedit{value = <<Left/binary, Right2/binary>>};
        false ->
            S
    end.

%% @doc Moves the cursor one grapheme left or right.
-spec move(left | right, state()) -> state().
move(left, #lineedit{cursor = Cursor} = S) ->
    S#lineedit{cursor = max(0, Cursor - 1)};
move(right, #lineedit{value = Value, cursor = Cursor} = S) ->
    S#lineedit{cursor = min(string:length(Value), Cursor + 1)}.

%% @doc Moves the cursor to the start of the value.
-spec home(state()) -> state().
home(#lineedit{} = S) -> S#lineedit{cursor = 0}.

%% @doc Moves the cursor to the end of the value.
-spec 'end'(state()) -> state().
'end'(#lineedit{value = Value} = S) ->
    S#lineedit{cursor = string:length(Value)}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

%% @doc Splits `Bin' at grapheme index `N'.
-spec split_at(binary(), non_neg_integer()) -> {binary(), binary()}.
split_at(Bin, N) ->
    {string:slice(Bin, 0, N), string:slice(Bin, N)}.
