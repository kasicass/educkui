%% @doc A simple table widget rendering rows of columns.
-module(educkui_widget_table).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Rows = maps:get(rows, Props, []),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    HeaderStyle = style_from_prop(maps:get(header_style, Props, undefined)),
    Header = maps:get(header, Props, undefined),
    Width = Rect#dui_rect.width,

    HeaderCells = case Header of
        undefined -> [];
        _ -> row_cells(Header, 0, Width, HeaderStyle)
    end,

    BodyCells = lists:flatmap(
        fun({Row, Y}) when Y + 1 < Rect#dui_rect.height ->
            row_cells(Row, Y + 1, Width, Style);
           (_) -> []
        end,
        zip_short(Rows, lists:seq(0, Rect#dui_rect.height - 2))),
    educkui_render_node:cells(HeaderCells ++ BodyCells).

-spec describe() -> map().
describe() ->
    #{name => <<"Table">>, description => <<"A simple table widget">>}.

-spec default_props() -> map().
default_props() ->
    #{rows => [], header => undefined, style => undefined, header_style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec row_cells([binary()], integer(), non_neg_integer(), #dui_style{} | undefined) ->
    [{integer(), integer(), #dui_cell{}}].
row_cells(Columns, Y, Width, Style) ->
    Text = join_binary(Columns, <<" ">>),
    Display = educkui_component_helpers:truncate_text(Text, Width),
    Graphemes = string:to_graphemes(Display),
    [{X, Y, col_cell(unicode:characters_to_binary([G]), Style)}
     || {X, G} <- lists:zip(lists:seq(0, length(Graphemes) - 1), Graphemes)].

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) ->
    zip_short(A, B, []).

-spec zip_short([term()], [term()], [{term(), term()}]) -> [{term(), term()}].
zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).

-spec join_binary([binary()], binary()) -> binary().
join_binary([], _Sep) -> <<>>;
join_binary([H], _Sep) -> H;
join_binary([H | T], Sep) -> <<H/binary, Sep/binary, (join_binary(T, Sep))/binary>>.

-spec col_cell(binary(), #dui_style{} | undefined) -> #dui_cell{}.
col_cell(Char, Style) ->
    {_X, _Y, C} = educkui_component_helpers:positioned_cell(0, 0, Char, Style),
    C.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).
