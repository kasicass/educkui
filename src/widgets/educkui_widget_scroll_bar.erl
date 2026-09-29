%% @doc A stateless scrollbar widget.
%%
%% Props: `{total, pos_integer()}` (total items/lines), `{offset,
%% non_neg_integer()}`, `{viewport, pos_integer()}` (visible items/lines),
%% `{vertical, boolean()}` (default true). Renders a track with a thumb whose
%% size and position are proportional to viewport/total and offset/total.
-module(educkui_widget_scroll_bar).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    case maps:get(vertical, Props, true) of
        true -> educkui_render_node:cells(vertical_bar(Props, Rect));
        false -> educkui_render_node:cells(horizontal_bar(Props, Rect))
    end.

-spec describe() -> map().
describe() ->
    #{name => <<"ScrollBar">>, description => <<"A scrollbar widget">>}.

-spec default_props() -> map().
default_props() ->
    #{total => 0, offset => 0, viewport => 1, vertical => true}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec vertical_bar(map(), #dui_rect{}) -> [{integer(), integer(), #dui_cell{}}].
vertical_bar(Props, Rect) ->
    Total = max(1, maps:get(total, Props, 0)),
    Viewport = max(1, maps:get(viewport, Props, 1)),
    Offset = maps:get(offset, Props, 0),
    H = Rect#dui_rect.height,
    ThumbSize = max(1, round(Viewport / Total * H)),
    MaxOffset = max(0, Total - Viewport),
    ThumbPos = case MaxOffset of
        0 -> 0;
        _ -> round(Offset / MaxOffset * (H - ThumbSize))
    end,
    [{0, Y, bar_cell(Y >= ThumbPos andalso Y < ThumbPos + ThumbSize)}
     || Y <- lists:seq(0, H - 1)].

-spec horizontal_bar(map(), #dui_rect{}) -> [{integer(), integer(), #dui_cell{}}].
horizontal_bar(Props, Rect) ->
    Total = max(1, maps:get(total, Props, 0)),
    Viewport = max(1, maps:get(viewport, Props, 1)),
    Offset = maps:get(offset, Props, 0),
    W = Rect#dui_rect.width,
    ThumbSize = max(1, round(Viewport / Total * W)),
    MaxOffset = max(0, Total - Viewport),
    ThumbPos = case MaxOffset of
        0 -> 0;
        _ -> round(Offset / MaxOffset * (W - ThumbSize))
    end,
    [{X, 0, bar_cell(X >= ThumbPos andalso X < ThumbPos + ThumbSize)}
     || X <- lists:seq(0, W - 1)].

-spec bar_cell(boolean()) -> #dui_cell{}.
bar_cell(true) -> educkui_cell:new(<<"█"/utf8>>);
bar_cell(false) -> educkui_cell:new(<<"│"/utf8>>).
