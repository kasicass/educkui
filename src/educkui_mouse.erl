%% @doc Mouse geometry helpers.
-module(educkui_mouse).

-include("educkui.hrl").

-export([point_in_rect/3, find_target/3]).

-spec point_in_rect(integer(), integer(), #dui_rect{}) -> boolean().
point_in_rect(X, Y, #dui_rect{x = Rx, y = Ry, width = W, height = H}) ->
    X >= Rx andalso X < Rx + W andalso Y >= Ry andalso Y < Ry + H.

%% @doc Returns the first target id whose rect contains the point.
%% `Targets` is a list of `{Id, Rect}` tuples.
-spec find_target(integer(), integer(), [{term(), #dui_rect{}}]) ->
    {ok, term()} | none.
find_target(_X, _Y, []) -> none;
find_target(X, Y, [{Id, Rect} | Rest]) ->
    case point_in_rect(X, Y, Rect) of
        true -> {ok, Id};
        false -> find_target(X, Y, Rest)
    end.
