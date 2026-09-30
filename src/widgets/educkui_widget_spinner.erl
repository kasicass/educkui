%% @doc A stateless spinner widget.
%%
%% The caller advances the animation by passing `{frame, N}' (typically via
%% `educkui_command:interval/2' or a render tick). Props:
%% - `{frame, non_neg_integer()}' — animation frame index (default 0)
%% - `{frames, [binary()]}'       — override the default braille frames
%% - `{style, style()}'           — span style
%% - `{suffix, binary()}'         — optional text after the spinner
-module(educkui_widget_spinner).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0, frames/0]).

-define(FRAMES, [<<"⠋"/utf8>>, <<"⠙"/utf8>>, <<"⠹"/utf8>>, <<"⠸"/utf8>>,
                 <<"⠼"/utf8>>, <<"⠴"/utf8>>, <<"⠦"/utf8>>, <<"⠧"/utf8>>,
                 <<"⠇"/utf8>>, <<"⠏"/utf8>>]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Frames = maps:get(frames, Props, ?FRAMES),
    Frame = maps:get(frame, Props, 0),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    Index = case length(Frames) of
        0 -> 0;
        N -> Frame rem N
    end,
    Glyph = case Frames of
        [] -> <<>>;
        _ -> lists:nth(Index + 1, Frames)
    end,
    Suffix = maps:get(suffix, Props, <<>>),
    Text = <<Glyph/binary, Suffix/binary>>,
    educkui_render_node:height(
        educkui_render_node:width(
            educkui_render_node:text(Text, Style), Rect#dui_rect.width),
        1).

-spec describe() -> map().
describe() ->
    #{name => <<"Spinner">>, description => <<"An animated activity indicator">>}.

-spec default_props() -> map().
default_props() ->
    #{frame => 0, frames => ?FRAMES, style => undefined, suffix => <<>>}.

%% @doc Returns the default braille spinner frames.
-spec frames() -> [binary()].
frames() -> ?FRAMES.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
