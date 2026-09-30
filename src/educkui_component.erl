%% @doc Base behaviour for components.
%%
%% The only required callback is `render/2'; `describe/0', `default_props/0'
%% and `natural_size/1' are optional. Because Erlang has no `use' macro,
%% components declare `-behaviour(educkui_component).' and call the helper
%% `merge_props/2' explicitly.
%%
%% `natural_size/1' lets a widget report its preferred size from props alone,
%% avoiding the fallback that renders it against a large dummy rect. This
%% matters for widgets that position content relative to the rect (e.g. a
%% centered dialog), where the dummy rect would otherwise yield an enormous
%% natural size and push the widget off-screen.
-module(educkui_component).

-include("educkui.hrl").

-export([merge_props/2]).

-type render_tree() :: term().
-type props() :: map().
-export_type([render_tree/0, props/0]).

-callback render(props(), #dui_rect{}) -> render_tree().
-callback describe() -> map().
-callback default_props() -> props().
-callback natural_size(props()) -> {non_neg_integer(), non_neg_integer()}.

-optional_callbacks([describe/0, default_props/0, natural_size/1]).

%% @doc Merges default props with the props passed to `render/2', with the
%% explicit props taking precedence.
-spec merge_props(props(), props()) -> props().
merge_props(Defaults, Props) when is_map(Defaults), is_map(Props) ->
    maps:merge(Defaults, Props).
