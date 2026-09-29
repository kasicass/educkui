%% @doc Mouse geometry helpers.
-module(educkui_mouse).

-include("educkui.hrl").

-export([point_in_rect/3, find_target/3]).

-spec point_in_rect(integer(), integer(), #dui_rect{}) -> boolean().
point_in_rect(X, Y, #dui_rect{x = Rx, y = Ry, width = W, height = H}) ->
    X >= Rx andalso X < Rx + W andalso Y >= Ry andalso Y < Ry + H.

%% @doc Returns the first target whose rect contains the point, together with
%% the matching rect. Targets are searched in reverse order so that later
%% (topmost, e.g. overlay) targets take priority over earlier ones.
-spec find_target(integer(), integer(), [{term(), #dui_rect{}}]) ->
    {ok, term(), #dui_rect{}} | none.
find_target(X, Y, Targets) ->
    find_target_rev(X, Y, lists:reverse(Targets)).

find_target_rev(_X, _Y, []) ->
    none;
find_target_rev(X, Y, [{Id, Rect} | Rest]) ->
    case point_in_rect(X, Y, Rect) of
        true -> {ok, Id, Rect};
        false -> find_target_rev(X, Y, Rest)
    end.
