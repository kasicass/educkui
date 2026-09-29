%% @doc A single terminal screen cell.
%%
%% A cell holds one grapheme cluster together with its foreground/background
%% colors and style attributes. Cells are immutable records; updates create
%% new cells, which enables reference-based diffing of frames.
-module(educkui_cell).

-include("educkui.hrl").

-export([
    new/1, new/2,
    empty/0,
    wide_placeholder/1,
    width/1,
    is_wide_placeholder/1,
    wide/1,
    equal/2,
    empty/1,
    put_char/2,
    put_fg/2,
    put_bg/2,
    add_attr/2,
    remove_attr/2,
    has_attr/2,
    named_colors/0,
    valid_attributes/0
]).

-define(NAMED_COLORS, [
    black, red, green, yellow, blue, magenta, cyan, white,
    bright_black, bright_red, bright_green, bright_yellow,
    bright_blue, bright_magenta, bright_cyan, bright_white
]).

-define(VALID_ATTRIBUTES, [
    bold, dim, italic, underline, blink, reverse, hidden, strikethrough
]).

-type color() :: default | atom() | 0..255 | {0..255, 0..255, 0..255}.
-type attribute() :: bold | dim | italic | underline | blink
                   | reverse | hidden | strikethrough.
-export_type([color/0, attribute/0]).

%% ---------------------------------------------------------------------------
%% Construction
%% ---------------------------------------------------------------------------

-spec new(binary()) -> #dui_cell{}.
new(Char) -> new(Char, []).

-spec new(binary(), list()) -> #dui_cell{}.
new(Char, Opts) when is_binary(Char), is_list(Opts) ->
    Fg = proplists:get_value(fg, Opts, default),
    Bg = proplists:get_value(bg, Opts, default),
    Attrs = proplists:get_value(attrs, Opts, []),
    Sanitized = sanitize_char(Char),
    #dui_cell{
        char = Sanitized,
        fg = validate_color(Fg),
        bg = validate_color(Bg),
        attrs = ordsets:from_list([validate_attribute(A) || A <- Attrs]),
        width = clamp_width(educkui_display_width:width(Sanitized)),
        placeholder = false
    }.

-spec empty() -> #dui_cell{}.
empty() ->
    #dui_cell{}.

%% @doc Creates the second-column placeholder for a wide character. The
%% placeholder inherits styling but renders as empty (width 0).
-spec wide_placeholder(#dui_cell{}) -> #dui_cell{}.
wide_placeholder(#dui_cell{fg = Fg, bg = Bg, attrs = Attrs}) ->
    #dui_cell{
        char = <<>>,
        fg = Fg,
        bg = Bg,
        attrs = Attrs,
        width = 0,
        placeholder = true
    }.

%% ---------------------------------------------------------------------------
%% Queries
%% ---------------------------------------------------------------------------

-spec width(#dui_cell{}) -> non_neg_integer().
width(#dui_cell{width = W}) -> W.

-spec is_wide_placeholder(#dui_cell{}) -> boolean().
is_wide_placeholder(#dui_cell{placeholder = P}) -> P.

-spec wide(#dui_cell{}) -> boolean().
wide(#dui_cell{width = 2}) -> true;
wide(#dui_cell{}) -> false.

-spec equal(#dui_cell{}, #dui_cell{}) -> boolean().
equal(#dui_cell{char = C1, fg = F1, bg = B1, attrs = A1, width = W1, placeholder = P1},
      #dui_cell{char = C2, fg = F2, bg = B2, attrs = A2, width = W2, placeholder = P2}) ->
    C1 =:= C2 andalso F1 =:= F2 andalso B1 =:= B2 andalso
    A1 =:= A2 andalso W1 =:= W2 andalso P1 =:= P2.

-spec empty(#dui_cell{}) -> boolean().
empty(#dui_cell{char = <<" ">>, fg = default, bg = default, attrs = []}) -> true;
empty(#dui_cell{}) -> false.

%% ---------------------------------------------------------------------------
%% Updates
%% ---------------------------------------------------------------------------

-spec put_char(#dui_cell{}, binary()) -> #dui_cell{}.
put_char(#dui_cell{} = Cell, Char) when is_binary(Char) ->
    Sanitized = sanitize_char(Char),
    Cell#dui_cell{
        char = Sanitized,
        width = clamp_width(educkui_display_width:width(Sanitized))
    }.

-spec put_fg(#dui_cell{}, color()) -> #dui_cell{}.
put_fg(#dui_cell{} = Cell, Color) ->
    Cell#dui_cell{fg = validate_color(Color)}.

-spec put_bg(#dui_cell{}, color()) -> #dui_cell{}.
put_bg(#dui_cell{} = Cell, Color) ->
    Cell#dui_cell{bg = validate_color(Color)}.

-spec add_attr(#dui_cell{}, attribute()) -> #dui_cell{}.
add_attr(#dui_cell{attrs = Attrs} = Cell, Attr) ->
    Cell#dui_cell{attrs = ordsets:add_element(validate_attribute(Attr), Attrs)}.

-spec remove_attr(#dui_cell{}, attribute()) -> #dui_cell{}.
remove_attr(#dui_cell{attrs = Attrs} = Cell, Attr) ->
    Cell#dui_cell{attrs = ordsets:del_element(validate_attribute(Attr), Attrs)}.

-spec has_attr(#dui_cell{}, attribute()) -> boolean().
has_attr(#dui_cell{attrs = Attrs}, Attr) ->
    ordsets:is_element(Attr, Attrs).

%% ---------------------------------------------------------------------------
%% Introspection
%% ---------------------------------------------------------------------------

-spec named_colors() -> [atom()].
named_colors() -> ?NAMED_COLORS.

-spec valid_attributes() -> [attribute()].
valid_attributes() -> ?VALID_ATTRIBUTES.

%% ---------------------------------------------------------------------------
%% Validation / sanitization
%% ---------------------------------------------------------------------------

-spec validate_color(term()) -> color().
validate_color(default) -> default;
validate_color(C) when is_atom(C) ->
    case lists:member(C, ?NAMED_COLORS) of
        true -> C;
        false -> erlang:error({invalid_color, C})
    end;
validate_color(C) when is_integer(C), C >= 0, C =< 255 -> C;
validate_color({R, G, B} = C)
        when is_integer(R), R >= 0, R =< 255,
             is_integer(G), G >= 0, G =< 255,
             is_integer(B), B >= 0, B =< 255 -> C;
validate_color(C) -> erlang:error({invalid_color, C}).

-spec validate_attribute(term()) -> attribute().
validate_attribute(A) ->
    case lists:member(A, ?VALID_ATTRIBUTES) of
        true -> A;
        false -> erlang:error({invalid_attribute, A})
    end.

-spec clamp_width(non_neg_integer()) -> 1 | 2.
clamp_width(W) when W >= 2 -> 2;
clamp_width(_) -> 1.

%% @doc Sanitizes a character/grapheme to prevent terminal escape injection
%% and to remove unsafe control/bidi characters.
-spec sanitize_char(binary()) -> binary().
sanitize_char(Char) when is_binary(Char) ->
    Stripped = strip_escape_sequences(Char),
    Filtered = filter_unsafe(Stripped),
    case Filtered of
        <<>> -> <<" ">>;
        _ -> Filtered
    end.

-spec strip_escape_sequences(binary()) -> binary().
strip_escape_sequences(Bin) ->
    unicode:characters_to_binary(strip_esc(to_codepoints(Bin), [])).

-spec strip_esc([char()], [char()]) -> [char()].
strip_esc([], Acc) -> lists:reverse(Acc);
strip_esc([$\e, $[ | Rest], Acc) -> strip_csi(Rest, Acc);
strip_esc([$\e, $] | Rest], Acc) -> strip_osc(Rest, Acc);
strip_esc([$\e, _C | Rest], Acc) -> strip_esc(Rest, Acc);
strip_esc([C | Rest], Acc) -> strip_esc(Rest, [C | Acc]).

%% CSI: skip parameter/intermediate bytes (0x20-0x3F), then the final byte
%% (0x40-0x7E) is consumed and parsing resumes.
-spec strip_csi([char()], [char()]) -> [char()].
strip_csi([], Acc) -> lists:reverse(Acc);
strip_csi([C | Rest], Acc) when C >= 16#20, C =< 16#3F ->
    strip_csi(Rest, Acc);
strip_csi([C | Rest], Acc) when C >= 16#40, C =< 16#7E ->
    strip_esc(Rest, Acc);
strip_csi([C | Rest], Acc) ->
    %% Malformed sequence: resume normal scanning.
    strip_esc([C | Rest], Acc).

%% OSC: skip until BEL (0x07) or ST (ESC backslash).
-spec strip_osc([char()], [char()]) -> [char()].
strip_osc([], Acc) -> lists:reverse(Acc);
strip_osc([$\a | Rest], Acc) -> strip_esc(Rest, Acc);
strip_osc([$\e, $\\ | Rest], Acc) -> strip_esc(Rest, Acc);
strip_osc([_ | Rest], Acc) -> strip_osc(Rest, Acc).

-spec filter_unsafe(binary()) -> binary().
filter_unsafe(Bin) ->
    Kept = [C || C <- to_codepoints(Bin), safe_codepoint(C)],
    unicode:characters_to_binary(Kept).

%% Printable ASCII and most Unicode; blocks C0/C1 controls, DEL, bidi
%% formatting characters and Unicode non-characters.
-spec safe_codepoint(char()) -> boolean().
safe_codepoint(C) when C >= 16#20, C =< 16#7E -> true;
safe_codepoint(C) when C >= 16#202A, C =< 16#202E -> false;
safe_codepoint(C) when C >= 16#2066, C =< 16#2069 -> false;
safe_codepoint(16#FFFE) -> false;
safe_codepoint(16#FFFF) -> false;
safe_codepoint(C) when C >= 16#FDD0, C =< 16#FDEF -> false;
safe_codepoint(C) when C >= 16#A0 -> true;
safe_codepoint(_) -> false.

-spec to_codepoints(binary()) -> [char()].
to_codepoints(Bin) ->
    case unicode:characters_to_list(Bin) of
        L when is_list(L) -> L;
        {error, L, _Rest} -> L;
        {incomplete, L, _Rest} -> L
    end.
