%% @doc A stateless distributed-cluster dashboard widget.
%%
%% Props: `{nodes, [{Name :: binary(), Slogan :: binary()}]}`. Renders a header
%% plus one row per node. `collect/0` builds a snapshot from the local node and
%% the currently connected nodes.
-module(educkui_widget_cluster_dashboard).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0, collect/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Nodes = maps:get(nodes, Props, []),
    Header = educkui_render_node:text(<<"Node  Status">>,
        educkui_style:from([{bold, true}])),
    Rows = [educkui_render_node:text(<<Name/binary, "  ", Slogan/binary>>)
            || {Name, Slogan} <- Nodes],
    educkui_render_node:stack(vertical, [Header | Rows]).

-spec describe() -> map().
describe() ->
    #{name => <<"ClusterDashboard">>,
      description => <<"A distributed cluster dashboard">>}.

-spec default_props() -> map().
default_props() ->
    #{nodes => []}.

%% @doc Collects a snapshot of the local node and connected nodes.
-spec collect() -> [{binary(), binary()}].
collect() ->
    Local = {node_to_binary(node()), <<"local">>},
    Others = [{node_to_binary(N), <<"connected">>} || N <- erlang:nodes()],
    [Local | Others].

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec node_to_binary(node()) -> binary().
node_to_binary(Node) ->
    atom_to_binary(Node, utf8).
