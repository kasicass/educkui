%% @doc Helper functions for building components and render trees.
%%
%% Provides `text/box/stack/styled/empty` delegates, props validation,
%% style merging, and text/geometry helpers.
-module(educkui_component_helpers).

-include("educkui.hrl").

-export([
    text/1, text/2,
    box/1, box/2,
    stack/2, stack/3,
    styled/2,
    overlay/1, overlay/2,
    component/2, component/3,
    empty/0,
    props/2,
    merge_styles/1,
    compute_size/1,
    compute_node_size/1,
    fits_in_rect/2,
    truncate_text/2,
    positioned_cell/3, positioned_cell/4
]).

%% ---------------------------------------------------------------------------
%% Render tree builders (delegate to educkui_render_node)
%% ---------------------------------------------------------------------------

-spec text(binary()) -> #dui_node{}.
text(Content) -> educkui_render_node:text(Content).

-spec text(binary(), #dui_style{} | undefined) -> #dui_node{}.
text(Content, Style) -> educkui_render_node:text(Content, Style).

-spec box([#dui_node{}]) -> #dui_node{}.
box(Children) -> educkui_render_node:box(Children).

-spec box([#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
box(Children, Opts) -> educkui_render_node:box(Children, Opts).

-spec stack(vertical | horizontal, [#dui_node{}]) -> #dui_node{}.
stack(Direction, Children) -> educkui_render_node:stack(Direction, Children).

-spec stack(vertical | horizontal, [#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
stack(Direction, Children, Opts) -> educkui_render_node:stack(Direction, Children, Opts).

-spec styled(#dui_node{}, #dui_style{}) -> #dui_node{}.
styled(Node, Style) -> educkui_render_node:styled(Node, Style).

-spec overlay([#dui_node{}]) -> #dui_node{}.
overlay(Children) -> educkui_render_node:overlay(Children).

-spec overlay([#dui_node{}], [{atom(), term()}]) -> #dui_node{}.
overlay(Children, Opts) -> educkui_render_node:overlay(Children, Opts).

-spec component(term(), module()) -> #dui_node{}.
component(Id, Module) -> educkui_render_node:component(Id, Module).

-spec component(term(), module(), map()) -> #dui_node{}.
component(Id, Module, Props) -> educkui_render_node:component(Id, Module, Props).

-spec empty() -> #dui_node{}.
empty() -> educkui_render_node:empty().

%% ---------------------------------------------------------------------------
%% Props validation
%% ---------------------------------------------------------------------------

%% @doc Validates and extracts props with type checking and defaults.
%%
%% Specs are `{Name, Type, Opts}` tuples. Types: `string`, `integer`,
%% `boolean`, `atom`, `any`, `style`. Options: `required`, `default`.
-spec props(map(), [{atom(), atom(), [{atom(), term()}]}]) -> map().
props(Props, Specs) when is_map(Props), is_list(Specs) ->
    lists:foldl(
        fun({Name, Type, Opts}, Acc) ->
            Required = proplists:get_value(required, Opts, false),
            Default = proplists:get_value(default, Opts),
            Value = extract_prop(Props, Name, Type, Required, Default),
            maps:put(Name, Value, Acc)
        end,
        #{},
        Specs).

%% ---------------------------------------------------------------------------
%% Style helpers
%% ---------------------------------------------------------------------------

-spec merge_styles([#dui_style{} | undefined]) -> #dui_style{}.
merge_styles(Styles) when is_list(Styles) ->
    lists:foldl(
        fun(Style, Acc) ->
            case Style of
                undefined -> Acc;
                #dui_style{} -> educkui_style:merge(Acc, Style)
            end
        end,
        educkui_style:new(),
        Styles).

%% ---------------------------------------------------------------------------
%% Text / geometry helpers
%% ---------------------------------------------------------------------------

-spec compute_size(binary()) -> {non_neg_integer(), non_neg_integer()}.
compute_size(Text) when is_binary(Text) ->
    Lines = binary:split(Text, <<"\n">>, [global]),
    Height = length(Lines),
    Width = lists:max([string:length(L) || L <- Lines] ++ [0]),
    {Width, Height}.

-spec compute_node_size(#dui_node{}) ->
    {non_neg_integer() | auto, non_neg_integer() | auto}.
compute_node_size(#dui_node{type = text, content = Content}) ->
    compute_size(Content);
compute_node_size(#dui_node{type = empty}) ->
    {0, 0};
compute_node_size(#dui_node{width = W, height = H}) ->
    {default(W, auto), default(H, auto)}.

-spec fits_in_rect({non_neg_integer(), non_neg_integer()}, #dui_rect{}) -> boolean().
fits_in_rect({Width, Height}, #dui_rect{width = MaxW, height = MaxH}) ->
    Width =< MaxW andalso Height =< MaxH.

-spec truncate_text(binary(), non_neg_integer()) -> binary().
truncate_text(Text, MaxWidth) when is_binary(Text), is_integer(MaxWidth), MaxWidth >= 0 ->
    case string:length(Text) =< MaxWidth of
        true -> Text;
        false -> string:slice(Text, 0, MaxWidth)
    end.

%% ---------------------------------------------------------------------------
%% Positioned cells
%% ---------------------------------------------------------------------------

-spec positioned_cell(non_neg_integer(), non_neg_integer(), binary()) ->
    {non_neg_integer(), non_neg_integer(), #dui_cell{}}.
positioned_cell(X, Y, Char) -> positioned_cell(X, Y, Char, undefined).

-spec positioned_cell(non_neg_integer(), non_neg_integer(), binary(),
    #dui_style{} | undefined) -> {non_neg_integer(), non_neg_integer(), #dui_cell{}}.
positioned_cell(X, Y, Char, Style) when is_binary(Char) ->
    Cell0 = educkui_cell:new(Char),
    Cell = apply_style(Cell0, Style),
    {X, Y, Cell}.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec extract_prop(map(), atom(), atom(), boolean(), term()) -> term().
extract_prop(Props, Name, Type, Required, Default) ->
    case maps:find(Name, Props) of
        {ok, Value} ->
            validate_prop_type(Name, Value, Type),
            Value;
        error ->
            case Required of
                true -> erlang:error({missing_required_prop, Name});
                false -> Default
            end
    end.

-spec validate_prop_type(atom(), term(), atom()) -> ok.
validate_prop_type(_Name, _Value, any) -> ok;
validate_prop_type(Name, Value, string) ->
    case is_binary(Value) of
        true -> ok;
        false -> erlang:error({invalid_prop, Name, string, Value})
    end;
validate_prop_type(Name, Value, integer) ->
    case is_integer(Value) of
        true -> ok;
        false -> erlang:error({invalid_prop, Name, integer, Value})
    end;
validate_prop_type(Name, Value, boolean) ->
    case is_boolean(Value) of
        true -> ok;
        false -> erlang:error({invalid_prop, Name, boolean, Value})
    end;
validate_prop_type(Name, Value, atom) ->
    case is_atom(Value) of
        true -> ok;
        false -> erlang:error({invalid_prop, Name, atom, Value})
    end;
validate_prop_type(Name, Value, style) ->
    case Value of
        #dui_style{} -> ok;
        _ -> erlang:error({invalid_prop, Name, style, Value})
    end.

-spec default(term(), term()) -> term().
default(undefined, Default) -> Default;
default(Value, _Default) -> Value.

-spec apply_style(#dui_cell{}, #dui_style{} | undefined) -> #dui_cell{}.
apply_style(Cell, undefined) -> Cell;
apply_style(Cell, #dui_style{fg = Fg, bg = Bg, attrs = Attrs}) ->
    C1 = case Fg of
        undefined -> Cell;
        _ -> educkui_cell:put_fg(Cell, Fg)
    end,
    C2 = case Bg of
        undefined -> C1;
        _ -> educkui_cell:put_bg(C1, Bg)
    end,
    lists:foldl(fun(A, C) -> educkui_cell:add_attr(C, A) end, C2, Attrs).
