%% @doc Command palette showcase with type-ahead filtering.
-module(dui_command_palette).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{last => <<>>}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update({command, Payload}, State) ->
    case Payload of
        quit -> {State, [educkui_command:quit()]};
        _ -> {State#{last := atom_to_binary(Payload, utf8)}, []}
    end;
update(_Msg, State) -> {State, []}.

view(State) ->
    Last = maps:get(last, State),
    LastText = case Last of
        <<>> -> <<"none">>;
        _ -> Last
    end,
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Command palette - Tab to focus, type to filter, Enter execute, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"Last command: ", LastText/binary>>),
        educkui_render_node:text(<<"">>),
        educkui_render_node:component(palette, educkui_widget_command_palette, #{
            commands => [
                {<<"Open file">>, open_file},
                {<<"Save file">>, save_file},
                {<<"Build project">>, build},
                {<<"Run tests">>, run_tests},
                {<<"Quit">>, quit}
            ]
        })
    ]).
