%% @doc A stateless widget for displaying text.
-module(educkui_widget_label).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Text = maps:get(text, Props, <<>>),
    Align = maps:get(align, Props, left),
    Wrap = maps:get(wrap, Props, false),
    Truncate = maps:get(truncate, Props, true),
    Style = style_from_prop(maps:get(style, Props, undefined)),

    Lines = case Wrap of
        true -> wrap_text(Text, Rect#dui_rect.width);
        false -> [Text]
    end,

    Cells = lists:flatmap(
        fun({Line, Y}) when Y < Rect#dui_rect.height ->
            render_line(Line, Y, Rect#dui_rect.width, Align, Truncate, Style);
           (_) -> []
        end,
        lists:zip(Lines, lists:seq(0, Rect#dui_rect.height - 1))),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Label">>, description => <<"A simple text display widget">>}.

-spec default_props() -> map().
default_props() ->
    #{text => <<>>, align => left, wrap => false, truncate => true, style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec render_line(binary(), integer(), non_neg_integer(), atom(), boolean(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
render_line(Text, Y, Width, Align, Truncate, Style) ->
    Display = case Truncate andalso string:length(Text) > Width of
        true -> truncate_ellipsis(Text, Width);
        false -> Text
    end,
    Aligned = align_text(Display, Width, Align),
    [educkui_component_helpers:positioned_cell(X, Y, unicode:characters_to_binary([G]), Style)
     || {X, G} <- lists:zip(lists:seq(0, Width - 1), Aligned)].

-spec align_text(binary(), non_neg_integer(), atom()) -> [char() | [char()]].
align_text(Text, Width, Align) ->
    Graphemes = string:to_graphemes(Text),
    Len = length(Graphemes),
    case Len >= Width of
        true -> lists:sublist(Graphemes, Width);
        false ->
            Padding = Width - Len,
            case Align of
                left -> Graphemes ++ lists:duplicate(Padding, $\s);
                right -> lists:duplicate(Padding, $\s) ++ Graphemes;
                center ->
                    Left = Padding div 2,
                    Right = Padding - Left,
                    lists:duplicate(Left, $\s) ++ Graphemes ++ lists:duplicate(Right, $\s)
            end
    end.

-spec truncate_ellipsis(binary(), non_neg_integer()) -> binary().
truncate_ellipsis(Text, Width) when Width =< 3 ->
    string:slice(Text, 0, Width);
truncate_ellipsis(Text, Width) ->
    <<(string:slice(Text, 0, Width - 3))/binary, "...">>.

-spec wrap_text(binary(), non_neg_integer()) -> [binary()].
wrap_text(Text, Width) when Width > 0 ->
    Graphemes = string:to_graphemes(Text),
    Chunks = chunk(Graphemes, Width),
    [unicode:characters_to_binary(C) || C <- Chunks];
wrap_text(Text, _Width) ->
    [Text].

-spec chunk([term()], pos_integer()) -> [[term()]].
chunk(List, N) ->
    case List of
        [] -> [];
        _ -> [lists:sublist(List, N) | chunk(lists:nthtail(min(N, length(List)), List), N)]
    end.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
