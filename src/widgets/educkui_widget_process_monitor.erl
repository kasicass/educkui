%% @doc A stateless process monitor widget.
%%
%% Props: `{rows, [{Name :: binary(), Memory :: binary(), Reductions :: binary()}]}`.
%% Renders a header plus one row per process. `collect/0` builds a snapshot
%% from the local node's processes.
-module(educkui_widget_process_monitor).

-behaviour(educkui_component).

-include("educkui.hrl").

-export([render/2, describe/0, default_props/0, collect/0]).

-spec render(map(), #dui_rect{}) -> #dui_node{}.
render(Props, _Rect) ->
    Rows = maps:get(rows, Props, []),
    Header = educkui_render_node:text(<<"Pid  Name  Memory  Reductions">>,
                                      educkui_style:from([{bold, true}])),
    RowNodes = [educkui_render_node:text(format_row(Row)) || Row <- Rows],
    educkui_render_node:stack(vertical, [Header | RowNodes]).

-spec describe() -> map().
describe() ->
    #{name => <<"ProcessMonitor">>,
      description => <<"A BEAM process monitor widget">>}.

-spec default_props() -> map().
default_props() ->
    #{rows => []}.

%% @doc Collects a snapshot of the local node's processes.
-spec collect() -> [{binary(), binary(), binary()}].
collect() ->
    Processes = processes(),
    [process_row(Pid) || Pid <- Processes].

%% ---------------------------------------------------------------------------
%% Internal
%% ---------------------------------------------------------------------------

-spec format_row({binary(), binary(), binary()}) -> binary().
format_row({Pid, Name, Reds}) ->
    Name2 = case Name of <<>> -> <<"(unnamed)">>; _ -> Name end,
    iolist_to_binary([Pid, <<"  ">>, Name2, <<"  ">>, Reds]).

-spec process_row(pid()) -> {binary(), binary(), binary()}.
process_row(Pid) ->
    Name = case process_info(Pid, registered_name) of
        {registered_name, Reg} -> atom_to_binary(Reg, utf8);
        _ -> <<>>
    end,
    Reds = case process_info(Pid, reductions) of
        {reductions, N} -> integer_to_binary(N);
        _ -> <<"0">>
    end,
    {pid_to_binary(Pid), Name, Reds}.

-spec pid_to_binary(pid()) -> binary().
pid_to_binary(Pid) ->
    list_to_binary(pid_to_list(Pid)).
