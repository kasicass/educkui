%% @doc Dashboard showcase: composes tabs, split pane, tree view, text input,
%% pick list, gauge, sparkline, bar chart, process monitor, log viewer and a
%% dialog overlay.
%%
%% Run: ./examples/dashboard/run.sh
%% Keys: Tab/Up/Down/Left/Right interact with focused widgets, Ctrl+D toggles
%%       the dialog, Esc quits.
-module(dui_dashboard).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{show_dialog => false}.

event_to_msg(#dui_event{type = key, key = esc}, State) ->
    case maps:get(show_dialog, State) of
        true -> {msg, close_dialog};
        false -> {msg, quit}
    end;
event_to_msg(#dui_event{type = custom, key = shortcut, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(#dui_event{type = custom, key = parent, content = Msg}, _State) ->
    {msg, Msg};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) ->
    {State, [educkui_command:quit()]};
update(open_dialog, State) ->
    {State#{show_dialog := true},
     [{focus, {dui_dialog_button, <<"OK">>}}]};
update(close_dialog, State) ->
    {State#{show_dialog := false}, []};
update(toggle_dialog, State) ->
    case maps:get(show_dialog, State) of
        true -> update(close_dialog, State);
        false -> update(open_dialog, State)
    end;
update({button, {dui_dialog_button, _Label}}, State) ->
    {State#{show_dialog := false}, []};
update(_Msg, State) ->
    {State, []}.

view(State) ->
    Base = base_view(),
    case maps:get(show_dialog, State) of
        true -> educkui_render_node:overlay([Base, dialog_view()]);
        false -> Base
    end.

%% ---------------------------------------------------------------------------
%% Panels
%% ---------------------------------------------------------------------------

base_view() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"educkui Dashboard - Ctrl+D dialog, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:component(tabs, educkui_widget_tabs, #{tabs => [
            {<<"Inputs">>, inputs_panel()},
            {<<"Charts">>, charts_panel()},
            {<<"System">>, system_panel()}
        ]}),
        educkui_render_node:component(split, educkui_widget_split_pane, #{
            direction => vertical,
            split => 8,
            children => [tree_panel(), log_panel()]
        })
    ]).

inputs_panel() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(<<"Name:">>),
        educkui_render_node:component(name, educkui_widget_text_input,
                                      #{value => <<"Alice">>}),
        educkui_render_node:text(<<"Fruit:">>),
        educkui_render_node:component(fruit, educkui_widget_pick_list, #{
            items => [<<"apple">>, <<"banana">>, <<"cherry">>, <<"durian">>],
            prompt => <<>>})
    ]).

charts_panel() ->
    educkui_render_node:stack(vertical, [
        educkui_render_node:widget(educkui_widget_gauge, #{value => 0.6}),
        educkui_render_node:widget(educkui_widget_sparkline,
                                   #{values => [1, 2, 3, 5, 4, 6, 5, 3, 2, 1]}),
        educkui_render_node:widget(educkui_widget_bar_chart,
                                   #{values => [2, 4, 6, 8, 6, 4, 2]})
    ]).

system_panel() ->
    educkui_render_node:widget(educkui_widget_process_monitor,
                               #{rows => educkui_widget_process_monitor:collect()}).

tree_panel() ->
    educkui_render_node:component(tree, educkui_widget_tree_view, #{items => [
        {root, <<"root">>, [
            {w1, <<"worker1">>, []},
            {w2, <<"worker2">>, [{w2a, <<"worker2a">>, []}]}
        ]},
        {other, <<"other">>, []}
    ]}).

log_panel() ->
    educkui_render_node:widget(educkui_widget_log_viewer, #{
        lines => [<<"INFO  startup complete">>,
                  <<"INFO  listening on :8080">>,
                  <<"WARN  high memory usage">>,
                  <<"INFO  request served">>]
    }).

dialog_view() ->
    educkui_render_node:widget(educkui_widget_dialog, #{
        title => <<"About">>,
        content => <<"educkui dashboard showcase">>,
        buttons => [<<"OK">>],
        width => 32,
        height => 6
    }).
