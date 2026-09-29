%% @doc Immutable style type and operations.
%%
%% Styles define foreground/background colors and text attributes. A style's
%% `fg`/`bg` fields are `undefined` when unset so that `merge/2` and
%% `inherit/2` can tell "not specified" apart from the explicit terminal
%% default color `default`.
%%
%% Attributes are stored as an ordset (sorted unique list) - the OTP
%% Efficiency Guide favours plain lists for tiny sets; an ordset gives us
%% set semantics for equality without a map-backed `sets` record.
-module(educkui_style).

-include("educkui.hrl").

-export([
    new/0,
    from/1,
    fg/2, bg/2,
    fg/1, bg/1, attrs/1,
    bold/1, dim/1, italic/1, underline/1, blink/1,
    reverse/1, hidden/1, strikethrough/1,
    add_attr/2, remove_attr/2, clear_attrs/1, has_attr/2,
    merge/2, inherit/2, reset/1,
    get_variant/2, create_variant/2,
    equal/2
]).

-type color() :: default | atom() | 0..255 | {0..255, 0..255, 0..255}.
-type attr() :: bold | dim | italic | underline | blink
              | reverse | hidden | strikethrough.
-export_type([color/0, attr/0]).

%% ---------------------------------------------------------------------------
%% Construction
%% ---------------------------------------------------------------------------

-spec new() -> #dui_style{}.
new() ->
    #dui_style{}.

-spec from(list() | map()) -> #dui_style{}.
from(Opts) when is_list(Opts) ->
    lists:foldl(fun apply_opt/2, new(), Opts);
from(Opts) when is_map(Opts) ->
    from(maps:to_list(Opts)).

-spec apply_opt(term(), #dui_style{}) -> #dui_style{}.
apply_opt({fg, C}, S) -> fg(S, C);
apply_opt({bg, C}, S) -> bg(S, C);
apply_opt({bold, true}, S) -> bold(S);
apply_opt({dim, true}, S) -> dim(S);
apply_opt({italic, true}, S) -> italic(S);
apply_opt({underline, true}, S) -> underline(S);
apply_opt({blink, true}, S) -> blink(S);
apply_opt({reverse, true}, S) -> reverse(S);
apply_opt({hidden, true}, S) -> hidden(S);
apply_opt({strikethrough, true}, S) -> strikethrough(S);
apply_opt({attrs, Attrs}, S) when is_list(Attrs) ->
    S#dui_style{attrs = ordsets:from_list(Attrs)};
apply_opt(_, S) -> S.

%% ---------------------------------------------------------------------------
%% Getters / color setters
%% ---------------------------------------------------------------------------

-spec fg(#dui_style{}) -> term().
fg(#dui_style{fg = Fg}) -> Fg.

-spec bg(#dui_style{}) -> term().
bg(#dui_style{bg = Bg}) -> Bg.

-spec attrs(#dui_style{}) -> [attr()].
attrs(#dui_style{attrs = Attrs}) -> Attrs.

-spec fg(#dui_style{}, color()) -> #dui_style{}.
fg(S, C) -> S#dui_style{fg = C}.

-spec bg(#dui_style{}, color()) -> #dui_style{}.
bg(S, C) -> S#dui_style{bg = C}.

%% ---------------------------------------------------------------------------
%% Attribute setters
%% ---------------------------------------------------------------------------

-spec bold(#dui_style{}) -> #dui_style{}.
bold(S) -> add_attr(S, bold).

-spec dim(#dui_style{}) -> #dui_style{}.
dim(S) -> add_attr(S, dim).

-spec italic(#dui_style{}) -> #dui_style{}.
italic(S) -> add_attr(S, italic).

-spec underline(#dui_style{}) -> #dui_style{}.
underline(S) -> add_attr(S, underline).

-spec blink(#dui_style{}) -> #dui_style{}.
blink(S) -> add_attr(S, blink).

-spec reverse(#dui_style{}) -> #dui_style{}.
reverse(S) -> add_attr(S, reverse).

-spec hidden(#dui_style{}) -> #dui_style{}.
hidden(S) -> add_attr(S, hidden).

-spec strikethrough(#dui_style{}) -> #dui_style{}.
strikethrough(S) -> add_attr(S, strikethrough).

-spec add_attr(#dui_style{}, attr()) -> #dui_style{}.
add_attr(#dui_style{attrs = Attrs} = S, A) ->
    S#dui_style{attrs = ordsets:add_element(A, Attrs)}.

-spec remove_attr(#dui_style{}, attr()) -> #dui_style{}.
remove_attr(#dui_style{attrs = Attrs} = S, A) ->
    S#dui_style{attrs = ordsets:del_element(A, Attrs)}.

-spec clear_attrs(#dui_style{}) -> #dui_style{}.
clear_attrs(S) ->
    S#dui_style{attrs = []}.

-spec has_attr(#dui_style{}, attr()) -> boolean().
has_attr(#dui_style{attrs = Attrs}, A) ->
    ordsets:is_element(A, Attrs).

%% ---------------------------------------------------------------------------
%% Merge / inheritance / variants
%% ---------------------------------------------------------------------------

-spec merge(#dui_style{}, #dui_style{}) -> #dui_style{}.
merge(#dui_style{} = Base, #dui_style{} = Override) ->
    #dui_style{
        fg = pick(Override#dui_style.fg, Base#dui_style.fg),
        bg = pick(Override#dui_style.bg, Base#dui_style.bg),
        attrs = ordsets:union(Base#dui_style.attrs, Override#dui_style.attrs)
    }.

-spec inherit(#dui_style{}, #dui_style{}) -> #dui_style{}.
inherit(#dui_style{} = Child, #dui_style{} = Parent) ->
    #dui_style{
        fg = pick(Child#dui_style.fg, Parent#dui_style.fg),
        bg = pick(Child#dui_style.bg, Parent#dui_style.bg),
        attrs = case Child#dui_style.attrs of
                    [] -> Parent#dui_style.attrs;
                    As -> As
                end
    }.

-spec reset(#dui_style{}) -> #dui_style{}.
reset(_S) ->
    new().

-spec get_variant(map(), atom()) -> #dui_style{}.
get_variant(Variants, State) when is_map(Variants) ->
    case maps:find(State, Variants) of
        {ok, V} -> V;
        error -> maps:get(normal, Variants, new())
    end.

-spec create_variant(#dui_style{}, #dui_style{}) -> #dui_style{}.
create_variant(Normal, Variant) ->
    merge(Normal, Variant).

-spec equal(#dui_style{}, #dui_style{}) -> boolean().
equal(#dui_style{} = A, #dui_style{} = B) ->
    A =:= B.

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec pick(term(), term()) -> term().
pick(undefined, Base) -> Base;
pick(Value, _Base) -> Value.
