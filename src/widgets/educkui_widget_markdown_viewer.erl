%% @doc A minimal Markdown viewer widget.
%%
%% Renders a subset of Markdown as a render tree: `#'/`##' headings (bold),
%% `-' bullet lists, `**bold**' and `*italic*' inline spans, and plain
%% paragraphs. Props: `{text, binary()}'.
-module(educkui_widget_markdown_viewer).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Text = maps:get(text, Props, <<>>),
    Lines = binary:split(Text, <<"\n">>, [global]),
    Nodes = [render_line(Line) || Line <- Lines],
    educkui_render_node:stack(vertical, Nodes).

-spec describe() -> map().
describe() ->
    #{name => <<"MarkdownViewer">>, description => <<"A minimal markdown viewer">>}.

-spec default_props() -> map().
default_props() ->
    #{text => <<>>}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec render_line(binary()) -> #dui_node{}.
render_line(<<"# ", Rest/binary>>) ->
    educkui_render_node:text(Rest, educkui_style:from([{bold, true}]));
render_line(<<"## ", Rest/binary>>) ->
    educkui_render_node:text(Rest, educkui_style:from([{bold, true}]));
render_line(<<"### ", Rest/binary>>) ->
    educkui_render_node:text(Rest, educkui_style:from([{bold, true}]));
render_line(<<"- ", Rest/binary>>) ->
    educkui_render_node:stack(horizontal, [
        educkui_render_node:text(<<"  * ">>),
        inline(Rest)
    ]);
render_line(Line) ->
    inline(Line).

-spec inline(binary()) -> #dui_node{}.
inline(Text) ->
    Nodes = [inline_node(S) || S <- split_inline(Text)],
    educkui_render_node:stack(horizontal, Nodes).

-spec inline_node({plain | bold | italic, binary()}) -> #dui_node{}.
inline_node({plain, T}) -> educkui_render_node:text(T);
inline_node({bold, T}) ->
    educkui_render_node:text(T, educkui_style:from([{bold, true}]));
inline_node({italic, T}) ->
    educkui_render_node:text(T, educkui_style:from([{italic, true}])).

%% Splits a line into {Style, Text} segments. Bold `**...**' takes priority
%% over italic `*...*'; spans are non-nested.
-spec split_inline(binary()) -> [{plain | bold | italic, binary()}].
split_inline(Text) ->
    split_inline(Text, []).

split_inline(<<>>, Acc) ->
    lists:reverse(Acc);
split_inline(Text, Acc) ->
    case binary:match(Text, <<"**">>) of
        {Pos, 2} ->
            {Before, After0} = split_at(Text, Pos),
            Rest = binary:part(After0, 2, byte_size(After0) - 2),
            case binary:match(Rest, <<"**">>) of
                {Pos2, 2} ->
                    Inside = binary:part(Rest, 0, Pos2),
                    After = binary:part(Rest, Pos2 + 2,
                                        byte_size(Rest) - Pos2 - 2),
                    split_inline(After,
                        [{bold, Inside}, {plain, Before} | Acc]);
                nomatch ->
                    lists:reverse([{plain, Text} | Acc])
            end;
        nomatch ->
            case binary:match(Text, <<"*">>) of
                {Pos, 1} ->
                    {Before, After0} = split_at(Text, Pos),
                    Rest = binary:part(After0, 1, byte_size(After0) - 1),
                    case binary:match(Rest, <<"*">>) of
                        {Pos2, 1} ->
                            Inside = binary:part(Rest, 0, Pos2),
                            After = binary:part(Rest, Pos2 + 1,
                                                byte_size(Rest) - Pos2 - 1),
                            split_inline(After,
                                [{italic, Inside}, {plain, Before} | Acc]);
                        nomatch ->
                            lists:reverse([{plain, Text} | Acc])
                    end;
                nomatch ->
                    lists:reverse([{plain, Text} | Acc])
            end
    end.

-spec split_at(binary(), non_neg_integer()) -> {binary(), binary()}.
split_at(Bin, Pos) ->
    {binary:part(Bin, 0, Pos),
     binary:part(Bin, Pos, byte_size(Bin) - Pos)}.
