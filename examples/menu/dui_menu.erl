%% @doc Hierarchical menu showcase.
-module(dui_menu).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{last_action => <<>>}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update({menu_activate, Id}, State) ->
    {State#{last_action := atom_to_binary(Id, utf8)}, []};
update(_Msg, State) -> {State, []}.

view(State) ->
    Last = maps:get(last_action, State),
    ActionText = case Last of
        <<>> -> <<"none">>;
        _ -> Last
    end,
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Menu - Tab to focus, arrows navigate, Enter activate, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"Last action: ", ActionText/binary>>),
        educkui_render_node:text(<<"">>),
        educkui_render_node:component(menu, educkui_widget_menu, #{
            items => [
                {file, <<"File">>, [
                    {new, <<"New">>, []},
                    {open, <<"Open">>, []},
                    {save, <<"Save">>, []}
                ]},
                {edit, <<"Edit">>, [
                    {copy, <<"Copy">>, []},
                    {paste, <<"Paste">>, []}
                ]},
                {help, <<"Help">>, [
                    {about, <<"About">>, []}
                ]}
            ]
        })
    ]).
