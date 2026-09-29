%% @doc Display width calculation for grapheme clusters and strings.
%%
%% Display width determines how many terminal columns a character occupies:
%% - Most characters are single-width (1 column)
%% - East Asian and wide/emoji presentation characters are double-width (2)
%% - Combining characters and control characters are zero-width (0)
%%
%% The implementation uses `unicode_util:is_wide/1` (OTP 28) for accurate
%% wide-character detection, augmented with combining/control ranges.
-module(educkui_display_width).

-export([
    width/1,
    string_width/1,
    double_width/1,
    zero_width/1,
    truncate/2
]).

%% ---------------------------------------------------------------------------
%% Public API
%% ---------------------------------------------------------------------------

-spec width(binary()) -> non_neg_integer().
width(Grapheme) when is_binary(Grapheme) ->
    lists:sum([char_width(C) || C <- to_codepoints(Grapheme)]).

-spec string_width(binary()) -> non_neg_integer().
string_width(String) when is_binary(String) ->
    lists:sum([width(grapheme_to_binary(G)) || G <- string:to_graphemes(String)]).

-spec double_width(binary()) -> boolean().
double_width(Grapheme) when is_binary(Grapheme) ->
    width(Grapheme) =:= 2.

-spec zero_width(binary()) -> boolean().
zero_width(Grapheme) when is_binary(Grapheme) ->
    width(Grapheme) =:= 0.

%% @doc Truncates a string to at most `MaxWidth` display columns.
%%
%% Returns `{TruncatedString, ActualWidth}`. Truncation is performed on
%% grapheme boundaries so that no combining sequence is split.
-spec truncate(binary(), non_neg_integer()) -> {binary(), non_neg_integer()}.
truncate(String, MaxWidth) when is_binary(String), is_integer(MaxWidth), MaxWidth >= 0 ->
    truncate_graphemes(string:to_graphemes(String), MaxWidth, [], 0).

-spec truncate_graphemes([char() | [char()]], non_neg_integer(),
    [char() | [char()]], non_neg_integer()) -> {binary(), non_neg_integer()}.
truncate_graphemes([G | Rest], MaxWidth, Acc, CurrentWidth) ->
    NewWidth = CurrentWidth + width(grapheme_to_binary(G)),
    case NewWidth =< MaxWidth of
        true -> truncate_graphemes(Rest, MaxWidth, [G | Acc], NewWidth);
        false -> {unicode:characters_to_binary(lists:reverse(Acc)), CurrentWidth}
    end;
truncate_graphemes([], _MaxWidth, Acc, CurrentWidth) ->
    {unicode:characters_to_binary(lists:reverse(Acc)), CurrentWidth}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec char_width(char()) -> 0 | 1 | 2.
%% Control characters and NULL.
char_width(C) when C < 32 -> 0;
char_width(127) -> 0;
%% DEL through C1 control characters.
char_width(C) when C >= 16#7F, C =< 16#9F -> 0;
%% Combining Diacritical Marks.
char_width(C) when C >= 16#0300, C =< 16#036F -> 0;
%% Combining Diacritical Marks Extended.
char_width(C) when C >= 16#1AB0, C =< 16#1AFF -> 0;
%% Combining Diacritical Marks Supplement.
char_width(C) when C >= 16#1DC0, C =< 16#1DFF -> 0;
%% Combining Diacritical Marks for Symbols.
char_width(C) when C >= 16#20D0, C =< 16#20FF -> 0;
%% Combining Half Marks.
char_width(C) when C >= 16#FE20, C =< 16#FE2F -> 0;
%% Zero-width characters.
char_width(C) when C =:= 16#200B; C =:= 16#200C; C =:= 16#200D -> 0;
char_width(16#2060) -> 0;
char_width(16#FEFF) -> 0;
%% Wide characters (East Asian W/F, emoji presentation).
char_width(C) ->
    case unicode_util:is_wide(C) of
        true -> 2;
        false -> 1
    end.

-spec to_codepoints(binary()) -> [char()].
to_codepoints(Bin) ->
    case unicode:characters_to_list(Bin) of
        L when is_list(L) -> L;
        {error, L, _Rest} -> L;
        {incomplete, L, _Rest} -> L
    end.

%% `string:to_graphemes/1` returns each grapheme as `char() | [char()]`;
%% convert it back to a binary for `width/1`.
-spec grapheme_to_binary(char() | [char()]) -> binary().
grapheme_to_binary(G) ->
    unicode:characters_to_binary([G]).
