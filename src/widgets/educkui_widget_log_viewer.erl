%% @doc A stateless log viewer widget.
%%
%% Props: `{lines, [binary()]}`. Shows the last `height` lines (the widget's
%% rect height), newest at the bottom.
-module(educkui_widget_log_viewer).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Lines = maps:get(lines, Props, []),
    Visible = last_n(Lines, Rect#dui_rect.height),
    Nodes = [educkui_render_node:text(Line) || Line <- Visible],
    educkui_render_node:stack(vertical, Nodes).

-spec describe() -> map().
describe() ->
    #{name => <<"LogViewer">>, description => <<"A log viewer widget">>}.

-spec default_props() -> map().
default_props() ->
    #{lines => []}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec last_n([term()], non_neg_integer()) -> [term()].
last_n(List, N) ->
    Len = length(List),
    lists:nthtail(max(0, Len - N), List).
