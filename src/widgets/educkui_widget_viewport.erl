%% @doc A stateless scrollable viewport.
%%
%% Renders a child render tree (`content`) shifted up by `scroll_y` rows, so
%% only the visible window lands inside this component's rect. Cells outside
%% the window are dropped by the screen buffer.
%%
%% Props: `{content, #dui_node{}}` (render tree), `{scroll_y, non_neg_integer()}`,
%% `{content_height, pos_integer()}` (total height of the content in rows).
-module(educkui_widget_viewport).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Content = maps:get(content, Props, educkui_render_node:empty()),
    ScrollY = maps:get(scroll_y, Props, 0),
    ContentHeight = maps:get(content_height, Props, Rect#dui_rect.height),
    Cells = educkui_render:render(
        Content,
        #dui_rect{x = 0, y = -ScrollY, width = Rect#dui_rect.width,
                  height = ContentHeight}),
    educkui_render_node:cells(Cells).

-spec describe() -> map().
describe() ->
    #{name => <<"Viewport">>, description => <<"A scrollable viewport widget">>}.

-spec default_props() -> map().
default_props() ->
    #{content => educkui_render_node:empty(), scroll_y => 0, content_height => 1}.
