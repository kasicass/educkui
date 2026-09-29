%% @doc Form builder showcase.
%%
%% Demonstrates a multi-field form: text, password, checkbox, conditional
%% radio group, select and multi_select, with validation and submission.
%%
%% Controls:
%% - Tab/Shift+Tab: focus the form (and other components)
%% - Up/Down: move between fields and the submit button
%% - Left/Right: move the highlighted option (radio/select/multi_select)
%% - Home/End/Left/Right: move the text cursor in text fields
%% - Space: toggle checkbox/option, or insert a space in text fields
%% - Enter: select option / next field / submit
%% - Esc: quit
-module(dui_form_builder).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

init(_Opts) ->
    #{submitted => undefined, message => <<>>}.

event_to_msg(#dui_event{type = key, key = esc}, _State) -> {msg, quit};
event_to_msg(#dui_event{type = custom, key = parent,
                        content = {form_submit, Values}}, _State) ->
    {msg, {form_submit, Values}};
event_to_msg(#dui_event{type = custom, key = parent,
                        content = {form_change, Id, Value}}, _State) ->
    {msg, {form_change, Id, Value}};
event_to_msg(_Event, _State) -> ignore.

update(quit, State) -> {State, [educkui_command:quit()]};
update({form_submit, Values}, State) ->
    {State#{submitted := Values, message := format_values(Values)}, []};
update({form_change, Id, Value}, State) ->
    {State#{message := <<"changed ", (atom_to_binary(Id, utf8))/binary, ": ",
                        (to_bin(Value))/binary>>}, []};
update(_Msg, State) ->
    {State, []}.

view(State) ->
    Form = educkui_render_node:component(form, educkui_widget_form_builder,
                                         form_props()),
    Result = case maps:get(submitted, State) of
        undefined -> educkui_render_node:text(<<"">>);
        _ -> educkui_render_node:text(
                 <<"Submitted: ", (maps:get(message, State))/binary>>,
                 educkui_style:from([{fg, green}, {bold, true}]))
    end,
    educkui_render_node:stack(vertical, [
        educkui_render_node:text(
            <<"Form builder - Up/Down move, Space/Enter edit, Esc quit">>,
            educkui_style:from([{fg, cyan}, {bold, true}])),
        educkui_render_node:text(<<"">>),
        Form,
        educkui_render_node:text(<<"">>),
        Result
    ]).

form_props() ->
    #{fields => [
        #{id => username, type => text, label => <<"Username">>,
          required => true, placeholder => <<"Enter username">>},
        #{id => password, type => password, label => <<"Password">>,
          required => true,
          validators => [fun validate_password/1]},
        #{id => email, type => text, label => <<"Email">>,
          validators => [fun validate_email/1]},
        #{id => newsletter, type => checkbox, label => <<"Subscribe">>},
        #{id => frequency, type => radio, label => <<"Frequency">>,
          visible_when => fun(Values) -> maps:get(newsletter, Values) =:= true end,
          options => [{daily, <<"Daily">>}, {weekly, <<"Weekly">>},
                      {monthly, <<"Monthly">>}]},
        #{id => country, type => select, label => <<"Country">>,
          options => [{us, <<"United States">>}, {uk, <<"United Kingdom">>},
                      {ca, <<"Canada">>}, {au, <<"Australia">>},
                      {de, <<"Germany">>}]},
        #{id => interests, type => multi_select, label => <<"Interests">>,
          options => [{tech, <<"Technology">>}, {sports, <<"Sports">>},
                      {music, <<"Music">>}, {art, <<"Art">>},
                      {travel, <<"Travel">>}]}
      ],
      submit_label => <<"Register">>,
      label_width => 18}.

validate_password(Value) ->
    case string:length(Value) >= 6 of
        false -> {error, <<"Password must be at least 6 characters">>};
        true -> ok
    end.

validate_email(Value) ->
    case Value =:= <<>> orelse binary:match(Value, <<"@">>) =/= nomatch of
        true -> ok;
        false -> {error, <<"Please enter a valid email address">>}
    end.

format_values(Values) ->
    Pairs = lists:map(
        fun({K, V}) -> <<(atom_to_binary(K, utf8))/binary, "=",
                         (to_bin(V))/binary>> end,
        lists:sort(maps:to_list(Values))),
    join(Pairs, <<", ">>).

to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(true) -> <<"true">>;
to_bin(false) -> <<"false">>;
to_bin(L) when is_list(L) ->
    Items = [to_bin(X) || X <- L],
    <<"[", (join(Items, <<", ">>))/binary, "]">>;
to_bin(T) -> unicode:characters_to_binary(io_lib:format("~p", [T])).

join([], _Sep) -> <<>>;
join([H | T], Sep) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, Sep/binary, X/binary>> end, H, T).
