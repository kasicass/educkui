%% @doc Parses terminal input bytes into `#dui_event{}` records.
%%
%% Handles control characters, printable ASCII, UTF-8 multi-byte characters,
%% CSI/SS3 escape sequences (arrows, function keys, Home/End/Insert/Delete/
%% PageUp/PageDown, modified keys), SGR mouse sequences and bracketed paste.
%%
%% The parser is stateless: `parse/1` returns `{Events, Remaining}`, where
%% `Remaining` holds bytes that form a partial sequence and must be buffered
%% by the caller.
-module(educkui_escape_parser).

-include("educkui.hrl").

-export([parse/1, partial_sequence/1]).

-define(ESC, 27).
-define(DELETE, 127).
-define(MAX_MOUSE_COORD, 9999).
-define(MAX_PASTE_BUFFER, (8 * 1024 * 1024)).

%% ---------------------------------------------------------------------------
%% Public API
%% ---------------------------------------------------------------------------

-spec parse(binary()) -> {[#dui_event{}], binary()}.
parse(<<>>) ->
    {[], <<>>};
parse(Input) when is_binary(Input) ->
    parse_bytes(Input, []).

%% @doc Returns true if the given bytes look like the start of an escape
%% sequence that needs more input.
-spec partial_sequence(binary()) -> boolean().
partial_sequence(<<?ESC>>) -> true;
partial_sequence(<<?ESC, $[>>) -> true;
partial_sequence(<<?ESC, "[200~", _/binary>>) -> true;
partial_sequence(<<?ESC, $[, Rest/binary>>) -> partial_csi(Rest);
partial_sequence(<<?ESC, $O>>) -> true;
partial_sequence(_) -> false.

%% ---------------------------------------------------------------------------
%% Byte-level parsing
%% ---------------------------------------------------------------------------

-spec parse_bytes(binary(), [#dui_event{}]) -> {[#dui_event{}], binary()}.
parse_bytes(<<>>, Events) ->
    {lists:reverse(Events), <<>>};
parse_bytes(<<?ESC, Rest/binary>>, Events) ->
    case parse_escape_sequence(Rest) of
        {ok, Event, Remaining} -> parse_bytes(Remaining, [Event | Events]);
        incomplete -> {lists:reverse(Events), <<?ESC, Rest/binary>>}
    end;
parse_bytes(<<8, Rest/binary>>, Events) ->
    parse_bytes(Rest, [educkui_event:key(backspace) | Events]);
parse_bytes(<<9, Rest/binary>>, Events) ->
    parse_bytes(Rest, [educkui_event:key(tab) | Events]);
parse_bytes(<<13, Rest/binary>>, Events) ->
    parse_bytes(Rest, [educkui_event:key(enter) | Events]);
parse_bytes(<<Char, Rest/binary>>, Events) when Char >= 1, Char =< 26 ->
    Key = <<(Char + 96)>>,
    Event = educkui_event:key(Key, [{char, Key}, {modifiers, [ctrl]}]),
    parse_bytes(Rest, [Event | Events]);
parse_bytes(<<?DELETE, Rest/binary>>, Events) ->
    parse_bytes(Rest, [educkui_event:key(backspace) | Events]);
parse_bytes(<<Char, Rest/binary>>, Events) when Char >= 32, Char =< 126 ->
    Key = <<Char>>,
    parse_bytes(Rest, [educkui_event:key(Key, [{char, Key}]) | Events]);
parse_bytes(<<Char, Rest/binary>>, Events) when Char < 32 ->
    %% Remaining C0 control characters are ignored.
    parse_bytes(Rest, Events);
parse_bytes(<<Char/utf8, Rest/binary>>, Events) when Char > 127 ->
    Key = <<Char/utf8>>,
    parse_bytes(Rest, [educkui_event:key(Key, [{char, Key}]) | Events]);
parse_bytes(<<_Byte, Rest/binary>>, Events) ->
    parse_bytes(Rest, Events).

%% ---------------------------------------------------------------------------
%% Escape sequences
%% ---------------------------------------------------------------------------

-spec parse_escape_sequence(binary()) ->
    {ok, #dui_event{}, binary()} | incomplete.
parse_escape_sequence(<<>>) ->
    incomplete;
parse_escape_sequence(<<$[, Rest/binary>>) ->
    parse_csi(Rest);
parse_escape_sequence(<<$O, Rest/binary>>) ->
    parse_ss3(Rest);
parse_escape_sequence(<<Char, Rest/binary>>) when Char >= 32, Char =< 126 ->
    Key = <<Char>>,
    {ok, educkui_event:key(Key, [{char, Key}, {modifiers, [alt]}]), Rest};
parse_escape_sequence(_) ->
    incomplete.

%% ---------------------------------------------------------------------------
%% CSI sequences
%% ---------------------------------------------------------------------------

-spec parse_csi(binary()) -> {ok, #dui_event{}, binary()} | incomplete.
parse_csi(<<>>) -> incomplete;
parse_csi(<<"A", Rest/binary>>) -> {ok, educkui_event:key(up), Rest};
parse_csi(<<"B", Rest/binary>>) -> {ok, educkui_event:key(down), Rest};
parse_csi(<<"C", Rest/binary>>) -> {ok, educkui_event:key(right), Rest};
parse_csi(<<"D", Rest/binary>>) -> {ok, educkui_event:key(left), Rest};
parse_csi(<<"Z", Rest/binary>>) ->
    {ok, educkui_event:key(tab, [{modifiers, [shift]}]), Rest};
parse_csi(<<"H", Rest/binary>>) -> {ok, educkui_event:key(home), Rest};
parse_csi(<<"F", Rest/binary>>) -> {ok, educkui_event:key('end'), Rest};
parse_csi(<<"1~", Rest/binary>>) -> {ok, educkui_event:key(home), Rest};
parse_csi(<<"2~", Rest/binary>>) -> {ok, educkui_event:key(insert), Rest};
parse_csi(<<"3~", Rest/binary>>) -> {ok, educkui_event:key(delete), Rest};
parse_csi(<<"4~", Rest/binary>>) -> {ok, educkui_event:key('end'), Rest};
parse_csi(<<"5~", Rest/binary>>) -> {ok, educkui_event:key(page_up), Rest};
parse_csi(<<"6~", Rest/binary>>) -> {ok, educkui_event:key(page_down), Rest};
parse_csi(<<"200~", Rest/binary>>) -> parse_paste(Rest);
parse_csi(<<"201~", Rest/binary>>) -> {ok, educkui_event:key(unknown), Rest};
parse_csi(<<"11~", Rest/binary>>) -> {ok, educkui_event:key(f1), Rest};
parse_csi(<<"12~", Rest/binary>>) -> {ok, educkui_event:key(f2), Rest};
parse_csi(<<"13~", Rest/binary>>) -> {ok, educkui_event:key(f3), Rest};
parse_csi(<<"14~", Rest/binary>>) -> {ok, educkui_event:key(f4), Rest};
parse_csi(<<"15~", Rest/binary>>) -> {ok, educkui_event:key(f5), Rest};
parse_csi(<<"17~", Rest/binary>>) -> {ok, educkui_event:key(f6), Rest};
parse_csi(<<"18~", Rest/binary>>) -> {ok, educkui_event:key(f7), Rest};
parse_csi(<<"19~", Rest/binary>>) -> {ok, educkui_event:key(f8), Rest};
parse_csi(<<"20~", Rest/binary>>) -> {ok, educkui_event:key(f9), Rest};
parse_csi(<<"21~", Rest/binary>>) -> {ok, educkui_event:key(f10), Rest};
parse_csi(<<"23~", Rest/binary>>) -> {ok, educkui_event:key(f11), Rest};
parse_csi(<<"24~", Rest/binary>>) -> {ok, educkui_event:key(f12), Rest};
parse_csi(<<"1;", Modifier, Dir, Rest/binary>>)
        when Dir =:= $A; Dir =:= $B; Dir =:= $C; Dir =:= $D ->
    Key = case Dir of
        $A -> up;
        $B -> down;
        $C -> right;
        $D -> left
    end,
    Mods = decode_modifier(Modifier - $0),
    {ok, educkui_event:key(Key, [{modifiers, Mods}]), Rest};
parse_csi(<<"1;", Modifier, "Z", Rest/binary>>)
        when Modifier >= $0, Modifier =< $9 ->
    Mods = decode_modifier(Modifier - $0),
    {ok, educkui_event:key(tab, [{modifiers, Mods}]), Rest};
parse_csi(<<"<", Rest/binary>>) ->
    parse_sgr_mouse(Rest);
parse_csi(Input) ->
    case partial_csi(Input) of
        true -> incomplete;
        false -> {ok, educkui_event:key(unknown), Input}
    end.

%% ---------------------------------------------------------------------------
%% SS3 sequences (ESC O)
%% ---------------------------------------------------------------------------

-spec parse_ss3(binary()) -> {ok, #dui_event{}, binary()} | incomplete.
parse_ss3(<<>>) -> incomplete;
parse_ss3(<<"P", Rest/binary>>) -> {ok, educkui_event:key(f1), Rest};
parse_ss3(<<"Q", Rest/binary>>) -> {ok, educkui_event:key(f2), Rest};
parse_ss3(<<"R", Rest/binary>>) -> {ok, educkui_event:key(f3), Rest};
parse_ss3(<<"S", Rest/binary>>) -> {ok, educkui_event:key(f4), Rest};
parse_ss3(<<"A", Rest/binary>>) -> {ok, educkui_event:key(up), Rest};
parse_ss3(<<"B", Rest/binary>>) -> {ok, educkui_event:key(down), Rest};
parse_ss3(<<"C", Rest/binary>>) -> {ok, educkui_event:key(right), Rest};
parse_ss3(<<"D", Rest/binary>>) -> {ok, educkui_event:key(left), Rest};
parse_ss3(<<"H", Rest/binary>>) -> {ok, educkui_event:key(home), Rest};
parse_ss3(<<"F", Rest/binary>>) -> {ok, educkui_event:key('end'), Rest};
parse_ss3(_) -> incomplete.

%% ---------------------------------------------------------------------------
%% Bracketed paste
%% ---------------------------------------------------------------------------

-spec parse_paste(binary()) -> {ok, #dui_event{}, binary()} | incomplete.
parse_paste(Rest) ->
    Marker = <<?ESC, "[201~">>,
    case binary:match(Rest, Marker) of
        {Pos, _Len} ->
            Content = binary:part(Rest, 0, Pos),
            TailStart = Pos + byte_size(Marker),
            Tail = binary:part(Rest, TailStart, byte_size(Rest) - TailStart),
            {ok, educkui_event:paste(Content), Tail};
        nomatch when byte_size(Rest) > ?MAX_PASTE_BUFFER ->
            {ok, educkui_event:paste(Rest), <<>>};
        nomatch ->
            incomplete
    end.

%% ---------------------------------------------------------------------------
%% SGR mouse
%% ---------------------------------------------------------------------------

-spec parse_sgr_mouse(binary()) -> {ok, #dui_event{}, binary()} | incomplete.
parse_sgr_mouse(Input) ->
    case find_mouse_terminator(Input, <<>>) of
        {ok, Params, Terminator, Rest} ->
            case parse_mouse_params(Params) of
                {ok, Cb, Cx, Cy} ->
                    {ok, decode_mouse_event(Cb, Cx, Cy, Terminator), Rest};
                error ->
                    {ok, educkui_event:key(unknown), Input}
            end;
        incomplete ->
            incomplete
    end.

-spec find_mouse_terminator(binary(), binary()) ->
    {ok, binary(), press | release, binary()} | incomplete.
find_mouse_terminator(<<>>, _Acc) -> incomplete;
find_mouse_terminator(<<"M", Rest/binary>>, Acc) -> {ok, Acc, press, Rest};
find_mouse_terminator(<<"m", Rest/binary>>, Acc) -> {ok, Acc, release, Rest};
find_mouse_terminator(<<Char, Rest/binary>>, Acc)
        when (Char >= $0 andalso Char =< $9); Char =:= $; ->
    find_mouse_terminator(Rest, <<Acc/binary, Char>>);
find_mouse_terminator(_Input, _Acc) -> incomplete.

-spec parse_mouse_params(binary()) -> {ok, 0..255, 0..9999, 0..9999} | error.
parse_mouse_params(Params) ->
    case binary:split(Params, <<";">>, [global]) of
        [CbS, CxS, CyS] ->
            case {to_int(CbS), to_int(CxS), to_int(CyS)} of
                {{ok, Cb}, {ok, Cx}, {ok, Cy}}
                        when Cb >= 0, Cb =< 255,
                             Cx >= 0, Cx =< ?MAX_MOUSE_COORD,
                             Cy >= 0, Cy =< ?MAX_MOUSE_COORD ->
                    {ok, Cb, Cx, Cy};
                _ ->
                    error
            end;
        _ ->
            error
    end.

-spec to_int(binary()) -> {ok, integer()} | error.
to_int(Bin) ->
    case string:to_integer(Bin) of
        {N, <<>>} -> {ok, N};
        _ -> error
    end.

-spec decode_mouse_event(0..255, 0..9999, 0..9999, press | release) -> #dui_event{}.
decode_mouse_event(Cb, Cx, Cy, Terminator) ->
    ButtonCode = Cb band 2#11,
    {Action, Button} = determine_mouse_action(Cb, ButtonCode, Terminator),
    Modifiers = extract_mouse_modifiers(Cb),
    educkui_event:mouse(Action, Button, Cx - 1, Cy - 1, [{modifiers, Modifiers}]).

-spec determine_mouse_action(0..255, 0..3, press | release) ->
    {atom(), atom() | undefined}.
determine_mouse_action(Cb, ButtonCode, Terminator) ->
    IsScroll = (Cb band 64) =/= 0,
    IsMotion = (Cb band 32) =/= 0,
    if
        IsScroll andalso ButtonCode =:= 0 -> {scroll_up, undefined};
        IsScroll andalso ButtonCode =:= 1 -> {scroll_down, undefined};
        IsMotion andalso Terminator =:= press -> {drag, decode_button(ButtonCode)};
        Terminator =:= release -> {release, left};
        true -> {press, decode_button(ButtonCode)}
    end.

-spec extract_mouse_modifiers(0..255) -> [atom()].
extract_mouse_modifiers(Cb) ->
    [Mod || {Bit, Mod} <- [{4, shift}, {8, alt}, {16, ctrl}],
            Cb band Bit =/= 0].

-spec decode_button(0..3) -> atom() | undefined.
decode_button(0) -> left;
decode_button(1) -> middle;
decode_button(2) -> right;
decode_button(_) -> undefined.

%% ---------------------------------------------------------------------------
%% Helpers
%% ---------------------------------------------------------------------------

-spec partial_csi(binary()) -> boolean().
partial_csi(<<>>) -> true;
partial_csi(<<"<", Rest/binary>>) -> digits_and_semis(Rest);
partial_csi(Input) -> digits_and_semis(Input).

-spec digits_and_semis(binary()) -> boolean().
digits_and_semis(<<>>) -> true;
digits_and_semis(<<Char, Rest/binary>>)
        when (Char >= $0 andalso Char =< $9); Char =:= $; ->
    digits_and_semis(Rest);
digits_and_semis(_) -> false.

-spec decode_modifier(non_neg_integer()) -> [atom()].
decode_modifier(N) ->
    M = N - 1,
    [Mod || {Bit, Mod} <- [{1, shift}, {2, alt}, {4, ctrl}],
            M band Bit =/= 0].
