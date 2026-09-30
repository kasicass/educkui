%% @doc A stateless toast notification widget.
%%
%% Renders a short message inside a small bordered box near the bottom of the
%% widget's rect. Props: `{message, binary()}', `{style, term()}'.
-module(educkui_widget_toast).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0, natural_size/1]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Message = maps:get(message, Props, <<>>),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    BoxW = min(Rect#dui_rect.width, max(4, string:length(Message) + 4)),
    BX = max(0, (Rect#dui_rect.width - BoxW) div 2),
    BY = max(0, Rect#dui_rect.height - 3),
    Background = fill_background(BX, BY, BoxW, 3, Style),
    Border = border_cells(BX, BY, BoxW, Style),
    Text = text_cells(Message, BX + 2, BY + 1, BoxW - 4, undefined),
    educkui_render_node:cells(Background ++ Border ++ Text).

-spec describe() -> map().
describe() ->
    #{name => <<"Toast">>, description => <<"A toast notification widget">>}.

-spec default_props() -> map().
default_props() ->
    #{message => <<>>, style => undefined}.

%% @doc The toast is a 3-row box sized to its message. Declaring it keeps
%% `nat_size' from measuring the centered box against a dummy rect.
-spec natural_size(map()) -> {pos_integer(), pos_integer()}.
natural_size(Props) ->
    Message = maps:get(message, Props, <<>>),
    {max(4, string:length(Message) + 4), 3}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec fill_background(integer(), integer(), non_neg_integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
fill_background(BX, BY, W, H, #dui_style{bg = Bg})
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{BX + X, BY + Y, Cell} || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1)];
fill_background(_BX, _BY, _W, _H, _Style) ->
    [].

-spec border_cells(integer(), integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
border_cells(BX, BY, W, Style) when W >= 2 ->
    Corners = [
        {BX, BY, cell(<<"┌"/utf8>>, Style)},
        {BX + W - 1, BY, cell(<<"┐"/utf8>>, Style)},
        {BX, BY + 2, cell(<<"└"/utf8>>, Style)},
        {BX + W - 1, BY + 2, cell(<<"┘"/utf8>>, Style)}
    ],
    Top = [{X, BY, cell(<<"─"/utf8>>, Style)} || X <- lists:seq(BX + 1, BX + W - 2)],
    Bottom = [{X, BY + 2, cell(<<"─"/utf8>>, Style)}
              || X <- lists:seq(BX + 1, BX + W - 2)],
    Left = [{BX, BY + 1, cell(<<"│"/utf8>>, Style)}],
    Right = [{BX + W - 1, BY + 1, cell(<<"│"/utf8>>, Style)}],
    Corners ++ Top ++ Bottom ++ Left ++ Right;
border_cells(_BX, _BY, _W, _Style) ->
    [].

-spec text_cells(binary(), integer(), integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
text_cells(Text, X, Y, MaxW, Style) ->
    Display = educkui_component_helpers:truncate_text(Text, MaxW),
    Graphemes = string:to_graphemes(Display),
    [{X + I, Y, cell(unicode:characters_to_binary([G]), Style)}
     || {I, G} <- zip_short(lists:seq(0, MaxW - 1), Graphemes)].

-spec cell(binary(), #dui_style{} | undefined) -> #dui_cell{}.
cell(Char, Style) ->
    {_X, _Y, C} = educkui_component_helpers:positioned_cell(0, 0, Char, Style),
    C.

-spec style_from_prop(term()) -> #dui_style{} | undefined.
style_from_prop(undefined) -> undefined;
style_from_prop(#dui_style{} = Style) -> Style;
style_from_prop(StyleMap) when is_map(StyleMap) -> educkui_style:from(StyleMap).

-spec zip_short([term()], [term()]) -> [{term(), term()}].
zip_short(A, B) -> zip_short(A, B, []).

zip_short([], _B, Acc) -> lists:reverse(Acc);
zip_short(_A, [], Acc) -> lists:reverse(Acc);
zip_short([A | As], [B | Bs], Acc) -> zip_short(As, Bs, [{A, B} | Acc]).
