%% @doc A dialog widget with focusable buttons.
%%
%% Renders a centered bordered box with a title and content text, plus a row
%% of focusable push-button components at the bottom. Each button sends
%% `{parent, {button, Id}}' to the root when activated (Enter/Space), with
%% `Id = {dui_dialog_button, Label}'.
%%
%% Props: `{title, binary()}', `{content, binary()}',
%% `{buttons, [binary()]}', `{width, pos_integer()}', `{height, pos_integer()}',
%% `{style, term()}'.
-module(educkui_widget_dialog).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, Rect) ->
    Title = maps:get(title, Props, <<>>),
    Content = maps:get(content, Props, <<>>),
    Buttons = maps:get(buttons, Props, []),
    Style = style_from_prop(maps:get(style, Props, undefined)),
    BoxW = min(maps:get(width, Props, 40), max(3, Rect#dui_rect.width)),
    BoxH = min(maps:get(height, Props, 8), max(3, Rect#dui_rect.height)),
    {BX, BY} = {max(0, (Rect#dui_rect.width - BoxW) div 2),
                max(0, (Rect#dui_rect.height - BoxH) div 2)},

    Background = fill_background(BX, BY, BoxW, BoxH, Style),
    BorderCells = border_cells(BX, BY, BoxW, BoxH, Style),
    TitleCells = text_cells(Title, BX + 2, BY + 1, BoxW - 4,
                            educkui_style:from([{bold, true}])),
    ContentCells = text_cells(Content, BX + 2, BY + 2, BoxW - 4, undefined),
    BoxCells = Background ++ BorderCells ++ TitleCells ++ ContentCells,

    case Buttons of
        [] ->
            educkui_render_node:cells(BoxCells);
        _ ->
            ButtonNodes = button_nodes(Buttons, BX, BY + BoxH - 2),
            educkui_render_node:overlay(
                [educkui_render_node:cells(BoxCells) | ButtonNodes])
    end.

-spec describe() -> map().
describe() ->
    #{name => <<"Dialog">>, description => <<"A modal dialog widget">>}.

-spec default_props() -> map().
default_props() ->
    #{title => <<>>, content => <<>>, buttons => [<<"OK">>],
      width => 40, height => 8, style => undefined}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec button_nodes([binary()], integer(), integer()) -> [#dui_node{}].
button_nodes(Buttons, BX, BY) ->
    {Nodes, _Offset} = lists:mapfoldl(
        fun(Label, Offset) ->
            X = BX + 2 + Offset,
            Id = {dui_dialog_button, Label},
            Node = educkui_render_node:at(
                X, BY,
                educkui_render_node:component(
                    Id, educkui_widget_push_button,
                    #{label => Label, id => Id})),
            {Node, Offset + string:length(Label) + 4}
        end,
        BX + 2,
        Buttons),
    Nodes.

-spec fill_background(integer(), integer(), non_neg_integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
fill_background(BX, BY, W, H, #dui_style{bg = Bg})
        when Bg =/= undefined, Bg =/= default ->
    Cell = educkui_cell:new(<<" ">>, [{bg, Bg}]),
    [{BX + X, BY + Y, Cell} || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1)];
fill_background(_BX, _BY, _W, _H, _Style) ->
    [].

-spec border_cells(integer(), integer(), non_neg_integer(), non_neg_integer(),
    #dui_style{} | undefined) -> [{integer(), integer(), #dui_cell{}}].
border_cells(BX, BY, W, H, Style) when W >= 2, H >= 2 ->
    Corners = [
        {BX, BY, cell(<<"┌"/utf8>>, Style)},
        {BX + W - 1, BY, cell(<<"┐"/utf8>>, Style)},
        {BX, BY + H - 1, cell(<<"└"/utf8>>, Style)},
        {BX + W - 1, BY + H - 1, cell(<<"┘"/utf8>>, Style)}
    ],
    Top = [{X, BY, cell(<<"─"/utf8>>, Style)} || X <- lists:seq(BX + 1, BX + W - 2)],
    Bottom = [{X, BY + H - 1, cell(<<"─"/utf8>>, Style)}
              || X <- lists:seq(BX + 1, BX + W - 2)],
    Left = [{BX, Y, cell(<<"│"/utf8>>, Style)} || Y <- lists:seq(BY + 1, BY + H - 2)],
    Right = [{BX + W - 1, Y, cell(<<"│"/utf8>>, Style)}
             || Y <- lists:seq(BY + 1, BY + H - 2)],
    Corners ++ Top ++ Bottom ++ Left ++ Right;
border_cells(_BX, _BY, _W, _H, _Style) ->
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
