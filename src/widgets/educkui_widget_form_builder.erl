%% @doc A stateful form widget supporting multiple field types.
%%
%% Implements The Elm Architecture so it can be embedded as a component node
%% (`educkui_render_node:component/3'). The form keeps all field values,
%% focus, validation errors and navigation state internally.
%%
%% Field types:
%% - `text'         - single-line text input
%% - `password'     - masked single-line text input
%% - `checkbox'     - boolean toggle
%% - `radio'        - single selection from options
%% - `select'       - single selection from options
%% - `multi_select' - multiple selection from options
%%
%% Props (passed through `component/3'):
%% - `{fields, [map()]}' (required) - field definitions
%% - `{groups, [map()]}'            - optional group headers
%% - `{values, map()}'              - initial values
%% - `{show_submit_button, boolean()}' (default `true')
%% - `{submit_label, binary()}'     (default `<<"Submit">>')
%% - `{validate_on_blur, boolean()}'(default `true')
%% - `{label_width, pos_integer()}' (default `15')
%% - `{field_width, pos_integer()}' (default `30', reserved)
%% - `{on_submit, fun((map()) -> term())}'
%% - `{on_change, fun((atom(), term()) -> term())}'
%%
%% A field map supports these keys:
%% - `id' (required), `type' (required), `label', `options',
%%   `required', `validators', `visible_when', `group', `placeholder',
%%   `default'.
%%
%% Navigation:
%% - Up/Down move between fields (and to/from the submit button).
%% - Left/Right move the highlighted option on radio/select/multi_select
%%   fields, or move the text cursor in text/password fields.
%% - Home/End move the text cursor in text/password fields.
%% - Space toggles a checkbox, selects a radio/select option, toggles a
%%   multi_select option, or inserts a space in text fields.
%% - Enter selects a radio/select option, otherwise moves to the next field;
%%   on the submit button it validates and submits.
%% - Esc propagates to the parent (so the application can close/quit).
-module(educkui_widget_form_builder).

-behaviour(educkui_elm).

-include("educkui.hrl").

-export([init/1, event_to_msg/2, update/2, view/1]).

%% ---------------------------------------------------------------------------
%% init
%% ---------------------------------------------------------------------------

-spec init([{atom(), term()}]) -> map().
init(Opts) ->
    Fields = normalize_fields(proplists:get_value(fields, Opts, [])),
    Groups = proplists:get_value(groups, Opts, []),
    InitialValues = proplists:get_value(values, Opts, #{}),
    Values = initial_values(Fields, InitialValues),
    FirstField = first_visible_field(Fields, Values),
    #{fields => Fields,
      groups => Groups,
      values => Values,
      errors => #{},
      focused_field => FirstField,
      focused_option => 0,
      submit_focused => false,
      show_submit_button => proplists:get_value(show_submit_button, Opts, true),
      submit_label => proplists:get_value(submit_label, Opts, <<"Submit">>),
      validate_on_blur => proplists:get_value(validate_on_blur, Opts, true),
      label_width => proplists:get_value(label_width, Opts, 15),
      field_width => proplists:get_value(field_width, Opts, 30),
      on_submit => proplists:get_value(on_submit, Opts, undefined),
      on_change => proplists:get_value(on_change, Opts, undefined),
      cursor => 0,
      focused => false}.

-spec normalize_fields([map()]) -> [map()].
normalize_fields(Fields) ->
    [maps:merge(#{required => false,
                  validators => [],
                  visible_when => undefined,
                  group => undefined,
                  placeholder => undefined,
                  default => undefined,
                  options => []},
                F)
     || F <- Fields].

-spec initial_values([map()], map()) -> map().
initial_values(Fields, Initial) ->
    lists:foldl(
        fun(F, Acc) ->
            Id = maps:get(id, F),
            case maps:is_key(Id, Acc) of
                true -> Acc;
                false -> Acc#{Id => default_value(F)}
            end
        end,
        Initial,
        Fields).

-spec default_value(map()) -> term().
default_value(F) ->
    case maps:get(default, F, undefined) of
        undefined -> default_for_type(maps:get(type, F), maps:get(options, F, []));
        D -> D
    end.

-spec default_for_type(atom(), [term()]) -> term().
default_for_type(checkbox, _Opts) -> false;
default_for_type(multi_select, _Opts) -> [];
default_for_type(radio, Opts) -> first_option_value(Opts);
default_for_type(select, Opts) -> first_option_value(Opts);
default_for_type(_Type, _Opts) -> <<>>.

-spec first_option_value([term()]) -> term().
first_option_value([]) -> <<>>;
first_option_value([Opt | _]) -> option_value(Opt).

-spec first_visible_field([map()], map()) -> atom() | undefined.
first_visible_field(Fields, Values) ->
    case [maps:get(id, F) || F <- Fields, field_visible(F, Values)] of
        [Id | _] -> Id;
        [] -> undefined
    end.

-spec field_visible(map(), map()) -> boolean().
field_visible(F, Values) ->
    case maps:get(visible_when, F, undefined) of
        Fun when is_function(Fun, 1) -> Fun(Values) =:= true;
        _ -> true
    end.

%% ---------------------------------------------------------------------------
%% event_to_msg
%% ---------------------------------------------------------------------------

-spec event_to_msg(#dui_event{}, map()) -> {msg, term()} | ignore | propagate.
event_to_msg(#dui_event{type = key, key = esc}, _State) -> propagate;
event_to_msg(#dui_event{type = key, key = up}, _State) -> {msg, up};
event_to_msg(#dui_event{type = key, key = down}, _State) -> {msg, down};
event_to_msg(#dui_event{type = key, key = left}, _State) -> {msg, left};
event_to_msg(#dui_event{type = key, key = right}, _State) -> {msg, right};
event_to_msg(#dui_event{type = key, key = home}, _State) -> {msg, cursor_home};
event_to_msg(#dui_event{type = key, key = 'end'}, _State) -> {msg, cursor_end};
event_to_msg(#dui_event{type = key, key = backspace}, _State) -> {msg, backspace};
event_to_msg(#dui_event{type = key, key = delete}, _State) -> {msg, delete};
event_to_msg(#dui_event{type = key, key = enter}, _State) -> {msg, enter};
event_to_msg(#dui_event{type = key, key = <<" ">>}, _State) -> {msg, space};
event_to_msg(#dui_event{type = key, key = _Key, char = Char}, _State) ->
    case Char of
        undefined -> ignore;
        _ -> {msg, {char, Char}}
    end;
event_to_msg(#dui_event{type = focus, action = gained}, _State) -> {msg, focus_gained};
event_to_msg(#dui_event{type = focus, action = lost}, _State) -> {msg, focus_lost};
event_to_msg(_Event, _State) -> ignore.

%% ---------------------------------------------------------------------------
%% update
%% ---------------------------------------------------------------------------

-spec update(term(), map()) -> {map(), [term()]}.
update({char, Char}, State) ->
    case current_text_field(State) of
        true -> insert_char(State, Char);
        false -> {State, []}
    end;
update(space, State) ->
    handle_space(State);
update(backspace, State) ->
    edit_text(State, backspace);
update(delete, State) ->
    edit_text(State, delete);
update(left, State) ->
    Field = current_field(State),
    case option_field(Field) andalso has_options(Field) of
        true -> {navigate_option(State, -1), []};
        false ->
            case current_text_field(State) of
                true -> cursor_move(State, -1);
                false -> {State, []}
            end
    end;
update(right, State) ->
    Field = current_field(State),
    case option_field(Field) andalso has_options(Field) of
        true -> {navigate_option(State, 1), []};
        false ->
            case current_text_field(State) of
                true -> cursor_move(State, 1);
                false -> {State, []}
            end
    end;
update(cursor_home, State) ->
    case current_text_field(State) of
        true -> {State#{cursor := 0}, []};
        false -> {State, []}
    end;
update(cursor_end, State) ->
    case current_text_field(State) of
        true ->
            Id = maps:get(focused_field, State),
            {State#{cursor := string:length(field_value(State, Id))}, []};
        false ->
            {State, []}
    end;
update(up, State) ->
    navigate_field(State, -1);
update(down, State) ->
    navigate_field(State, 1);
update(enter, State) ->
    handle_enter(State);
update(focus_gained, State) ->
    State1 = State#{focused := true},
    case maps:get(focused_field, State1, undefined) of
        undefined ->
            case focusable_fields(State1) of
                [] -> {State1, []};
                [Id | _] -> move_focus_to(State1, Id)
            end;
        Id ->
            {State1#{cursor := text_cursor(State1, Id)}, []}
    end;
update(focus_lost, State) ->
    {State#{focused := false}, []};
update(_Msg, State) ->
    {State, []}.

-spec handle_space(map()) -> {map(), [term()]}.
handle_space(State) ->
    case maps:get(submit_focused, State) of
        true ->
            submit(State);
        false ->
            case current_field(State) of
                undefined -> {State, []};
                Field ->
                    case maps:get(type, Field) of
                        checkbox -> toggle_checkbox(State, Field);
                        radio -> select_option(State, Field);
                        select -> select_option(State, Field);
                        multi_select -> toggle_multi_select(State, Field);
                        _ -> insert_char(State, <<" ">>)
                    end
            end
    end.

-spec handle_enter(map()) -> {map(), [term()]}.
handle_enter(State) ->
    case maps:get(submit_focused, State) of
        true ->
            submit(State);
        false ->
            case current_field(State) of
                undefined -> {State, []};
                Field ->
                    case maps:get(type, Field) of
                        radio -> select_option(State, Field);
                        select -> select_option(State, Field);
                        _ -> navigate_field(State, 1)
                    end
            end
    end.

%% ---------------------------------------------------------------------------
%% Text editing
%% ---------------------------------------------------------------------------

-spec insert_char(map(), binary()) -> {map(), [term()]}.
insert_char(State, Char) ->
    edit_field(State, fun(LE) -> educkui_lineedit:insert(Char, LE) end).

-spec edit_text(map(), backspace | delete) -> {map(), [term()]}.
edit_text(State, backspace) ->
    case current_text_field(State) of
        false -> {State, []};
        true -> edit_field(State, fun educkui_lineedit:backspace/1)
    end;
edit_text(State, delete) ->
    case current_text_field(State) of
        false -> {State, []};
        true -> edit_field(State, fun educkui_lineedit:delete/1)
    end.

%% @doc Applies a line-edit operation to the focused text field, emitting an
%% `on_change' command only when the value or cursor actually changed.
-spec edit_field(map(), fun((educkui_lineedit:state()) -> educkui_lineedit:state())) ->
    {map(), [term()]}.
edit_field(State, Fun) ->
    Id = maps:get(focused_field, State),
    Value0 = field_value(State, Id),
    Cursor0 = maps:get(cursor, State),
    LE1 = Fun(educkui_lineedit:new(Value0, Cursor0)),
    Value1 = educkui_lineedit:value(LE1),
    Cursor1 = educkui_lineedit:cursor(LE1),
    case Value1 =:= Value0 andalso Cursor1 =:= Cursor0 of
        true ->
            {State, []};
        false ->
            {State1, Cmds} = set_value(State, Id, Value1),
            {State1#{cursor := Cursor1}, Cmds}
    end.

-spec cursor_move(map(), integer()) -> {map(), [term()]}.
cursor_move(State, Delta) ->
    Id = maps:get(focused_field, State),
    Max = string:length(field_value(State, Id)),
    Cursor = clamp(0, Max, maps:get(cursor, State) + Delta),
    {State#{cursor := Cursor}, []}.

-spec set_value(map(), atom(), term()) -> {map(), [term()]}.
set_value(State, Id, Value) ->
    Values = maps:get(values, State),
    {State#{values := Values#{Id => Value}}, change_cmds(State, Id, Value)}.

-spec change_cmds(map(), atom(), term()) -> [term()].
change_cmds(State, Id, Value) ->
    case maps:get(on_change, State, undefined) of
        Fun when is_function(Fun, 2) -> [{exec, fun() -> Fun(Id, Value) end}];
        _ -> []
    end.

%% ---------------------------------------------------------------------------
%% Option fields
%% ---------------------------------------------------------------------------

-spec toggle_checkbox(map(), map()) -> {map(), [term()]}.
toggle_checkbox(State, Field) ->
    Id = maps:get(id, Field),
    Value = maps:get(Id, maps:get(values, State), false),
    set_value(State, Id, not Value).

-spec toggle_multi_select(map(), map()) -> {map(), [term()]}.
toggle_multi_select(State, Field) ->
    Id = maps:get(id, Field),
    Opts = maps:get(options, Field, []),
    case Opts of
        [] ->
            {State, []};
        _ ->
            Idx = maps:get(focused_option, State),
            Value = option_value(lists:nth(min(length(Opts), Idx + 1), Opts)),
            Current = maps:get(Id, maps:get(values, State), []),
            New = case lists:member(Value, Current) of
                true -> lists:delete(Value, Current);
                false -> [Value | Current]
            end,
            set_value(State, Id, New)
    end.

-spec select_option(map(), map()) -> {map(), [term()]}.
select_option(State, Field) ->
    Opts = maps:get(options, Field, []),
    case Opts of
        [] ->
            {State, []};
        _ ->
            Idx = maps:get(focused_option, State),
            Value = option_value(lists:nth(min(length(Opts), Idx + 1), Opts)),
            Id = maps:get(id, Field),
            {State1, Cmds} = set_value(State, Id, Value),
            State2 = State1#{focused_option := 0},
            case maps:get(type, Field) of
                radio ->
                    {State3, Cmds2} = navigate_field(State2, 1),
                    {State3, Cmds ++ Cmds2};
                select ->
                    {State2, Cmds}
            end
    end.

-spec navigate_option(map(), integer()) -> map().
navigate_option(State, Dir) ->
    Field = current_field(State),
    Opts = maps:get(options, Field, []),
    N = length(Opts),
    case N of
        0 ->
            State;
        _ ->
            Cur = maps:get(focused_option, State),
            State#{focused_option := (Cur + Dir + N) rem N}
    end.

%% ---------------------------------------------------------------------------
%% Navigation
%% ---------------------------------------------------------------------------

-spec navigate_field(map(), integer()) -> {map(), [term()]}.
navigate_field(State, Dir) ->
    State1 = validate_on_blur(State),
    Ids = focusable_ids(State1),
    N = length(Ids),
    case N of
        0 ->
            {State1, []};
        _ ->
            Current = current_focus_id(State1),
            Idx = index_of(Current, Ids),
            NewIdx = (Idx + Dir + N) rem N,
            NewId = lists:nth(NewIdx + 1, Ids),
            move_focus_to(State1, NewId)
    end.

-spec move_focus_to(map(), atom()) -> {map(), [term()]}.
move_focus_to(State, submit) ->
    {State#{submit_focused := true, focused_field := undefined, cursor := 0}, []};
move_focus_to(State, Id) ->
    {State#{submit_focused := false, focused_field := Id,
            cursor := text_cursor(State, Id)}, []}.

-spec current_focus_id(map()) -> atom() | undefined.
current_focus_id(State) ->
    case maps:get(submit_focused, State, false) of
        true -> submit;
        false -> maps:get(focused_field, State, undefined)
    end.

-spec focusable_fields(map()) -> [atom()].
focusable_fields(State) ->
    [maps:get(id, F) || F <- visible_fields(State)].

-spec focusable_ids(map()) -> [atom()].
focusable_ids(State) ->
    Ids = focusable_fields(State),
    case maps:get(show_submit_button, State, true) of
        true -> Ids ++ [submit];
        false -> Ids
    end.

-spec validate_on_blur(map()) -> map().
validate_on_blur(State) ->
    case maps:get(validate_on_blur, State, true) andalso
         not maps:get(submit_focused, State, false) of
        true ->
            case maps:get(focused_field, State, undefined) of
                undefined -> State;
                Id -> validate_and_store(State, Id)
            end;
        false ->
            State
    end.

-spec validate_and_store(map(), atom()) -> map().
validate_and_store(State, Id) ->
    case get_field(State, Id) of
        undefined ->
            State;
        Field ->
            Errors = validate_field(Field, maps:get(values, State)),
            Errs = maps:get(errors, State),
            Errs1 = case Errors of
                [] -> maps:remove(Id, Errs);
                _ -> Errs#{Id => Errors}
            end,
            State#{errors := Errs1}
    end.

%% ---------------------------------------------------------------------------
%% Validation and submission
%% ---------------------------------------------------------------------------

-spec submit(map()) -> {map(), [term()]}.
submit(State) ->
    {State1, Errors} = validate_all(State),
    case maps:size(Errors) of
        0 ->
            Values = maps:get(values, State1),
            Cmds = case maps:get(on_submit, State1, undefined) of
                Fun when is_function(Fun, 1) -> [{exec, fun() -> Fun(Values) end}];
                _ -> [{parent, {form_submit, Values}}]
            end,
            {State1, Cmds};
        _ ->
            {State1#{errors := Errors}, []}
    end.

-spec validate_all(map()) -> {map(), map()}.
validate_all(State) ->
    Values = maps:get(values, State),
    lists:foldl(
        fun(F, {St, Errs}) ->
            Id = maps:get(id, F),
            case validate_field(F, Values) of
                [] -> {St, Errs};
                FieldErrors -> {St, Errs#{Id => FieldErrors}}
            end
        end,
        {State, #{}},
        visible_fields(State)).

-spec validate_field(map(), map()) -> [binary()].
validate_field(F, Values) ->
    Id = maps:get(id, F),
    Value = maps:get(Id, Values, undefined),
    Required = case maps:get(required, F, false) andalso empty_value(Value) of
        true -> [<<"This field is required">>];
        false -> []
    end,
    Validators = maps:get(validators, F, []),
    ValidatorErrors = lists:flatmap(
        fun(V) ->
            case V(Value) of
                ok -> [];
                {error, Msg} when is_binary(Msg) -> [Msg];
                {error, Msg} -> [to_bin(Msg)]
            end
        end,
        Validators),
    Required ++ ValidatorErrors.

-spec empty_value(term()) -> boolean().
empty_value(undefined) -> true;
empty_value(<<>>) -> true;
empty_value([]) -> true;
empty_value(_) -> false.

%% ---------------------------------------------------------------------------
%% view
%% ---------------------------------------------------------------------------

-spec view(map()) -> #dui_node{}.
view(State) ->
    FieldNodes = render_fields(State),
    SubmitNodes = case maps:get(show_submit_button, State, true) of
        true -> [render_submit(State)];
        false -> []
    end,
    educkui_render_node:stack(vertical, FieldNodes ++ SubmitNodes).

-spec render_fields(map()) -> [#dui_node{}].
render_fields(State) ->
    Fields = visible_fields(State),
    {_LastGroup, Nodes} =
        lists:foldl(
            fun(F, {LastGroup, Acc}) ->
                Group = maps:get(group, F, undefined),
                Acc1 = case Group =/= undefined andalso Group =/= LastGroup of
                    true -> Acc ++ [render_group_header(Group, State)];
                    false -> Acc
                end,
                {Group, Acc1 ++ [render_field(F, State)]}
            end,
            {undefined, []},
            Fields),
    Nodes.

-spec render_group_header(atom(), map()) -> #dui_node{}.
render_group_header(GroupId, State) ->
    Groups = maps:get(groups, State, []),
    Label = case [G || G <- Groups, maps:get(id, G, undefined) =:= GroupId] of
        [G | _] -> to_bin(maps:get(label, G, GroupId));
        [] -> to_bin(GroupId)
    end,
    educkui_render_node:text(Label, educkui_style:from([{bold, true}])).

-spec render_field(map(), map()) -> #dui_node{}.
render_field(F, State) ->
    Id = maps:get(id, F),
    Label = pad_display(to_bin(maps:get(label, F, Id)),
                        maps:get(label_width, State, 15)),
    Focused = maps:get(focused, State) andalso
              maps:get(focused_field, State, undefined) =:= Id,
    Value = field_value(State, Id),
    Body = render_field_body(F, Value, Focused, State),
    Row = educkui_render_node:stack(horizontal,
                                    [educkui_render_node:text(Label), Body]),
    case render_errors(maps:get(Id, maps:get(errors, State, #{}), [])) of
        #dui_node{type = empty} -> Row;
        ErrorNode -> educkui_render_node:stack(vertical, [Row, ErrorNode])
    end.

-spec render_field_body(map(), term(), boolean(), map()) -> #dui_node{}.
render_field_body(F, Value, Focused, State) ->
    case maps:get(type, F) of
        text -> render_text_field(Value, Focused, State);
        password -> render_text_field(mask(Value), Focused, State);
        checkbox -> educkui_render_node:text(checkbox_label(Value),
                                             focus_style(Focused));
        radio -> render_option_field(radio, F, Value, Focused, State);
        select -> render_option_field(select, F, Value, Focused, State);
        multi_select -> render_multi_select(F, Value, Focused, State)
    end.

-spec render_text_field(binary(), boolean(), map()) -> #dui_node{}.
render_text_field(Value, Focused, State) ->
    Graphemes = string:to_graphemes(Value),
    Cursor = maps:get(cursor, State),
    {Cells, _} =
        lists:foldl(
            fun(G, {Acc, I}) ->
                Char = unicode:characters_to_binary([G]),
                Cell = case Focused andalso I =:= Cursor of
                    true -> educkui_cell:new(Char, [{attrs, [reverse]}]);
                    false -> educkui_cell:new(Char)
                end,
                {[{I, 0, Cell} | Acc], I + 1}
            end,
            {[], 0},
            Graphemes),
    Cells1 = lists:reverse(Cells),
    Cells2 = case Focused andalso Cursor >= length(Graphemes) of
        true -> Cells1 ++ [{Cursor, 0, educkui_cell:new(<<" ">>, [{attrs, [reverse]}])}];
        false -> Cells1
    end,
    Final = case Cells2 of
        [] -> [{0, 0, educkui_cell:new(<<" ">>)}];
        _ -> Cells2
    end,
    educkui_render_node:cells(Final).

-spec render_option_field(atom(), map(), term(), boolean(), map()) -> #dui_node{}.
render_option_field(Type, F, Value, Focused, State) ->
    Opts = maps:get(options, F, []),
    Idx = find_option_index(Value, Opts),
    ValueText = case Opts of
        [] -> <<>>;
        _ -> option_label(lists:nth(min(length(Opts), Idx + 1), Opts))
    end,
    Highlight = maps:get(focused_option, State),
    Display = case Focused andalso Opts =/= [] of
        true -> option_label(lists:nth(min(length(Opts), Highlight + 1), Opts));
        false -> ValueText
    end,
    Marker = case Type of
        radio -> <<"( )">>;
        _ -> <<"[ ]">>
    end,
    educkui_render_node:text(<<Marker/binary, " ", Display/binary>>,
                             focus_style(Focused)).

-spec render_multi_select(map(), [term()], boolean(), map()) -> #dui_node{}.
render_multi_select(F, Value, Focused, State) ->
    Opts = maps:get(options, F, []),
    Labels = [option_label(O) || O <- Opts, lists:member(option_value(O), Value)],
    Body = case Labels of
        [] -> <<"[]">>;
        _ -> <<"[", (join(Labels, <<", ">>))/binary, "]">>
    end,
    Hint = case Focused andalso Opts =/= [] of
        true ->
            Highlight = maps:get(focused_option, State),
            O = lists:nth(min(length(Opts), Highlight + 1), Opts),
            <<"  (", (option_label(O))/binary, ")">>;
        false ->
            <<>>
    end,
    educkui_render_node:text(<<Body/binary, Hint/binary>>, focus_style(Focused)).

-spec render_submit(map()) -> #dui_node{}.
render_submit(State) ->
    Label = maps:get(submit_label, State, <<"Submit">>),
    Focused = maps:get(focused, State) andalso maps:get(submit_focused, State, false),
    educkui_render_node:text(Label, focus_style(Focused)).

-spec render_errors([binary()]) -> #dui_node{}.
render_errors([]) ->
    educkui_render_node:empty();
render_errors(Errors) ->
    educkui_render_node:text(join(Errors, <<"; ">>),
                             educkui_style:from([{fg, red}])).

-spec focus_style(boolean()) -> #dui_style{} | undefined.
focus_style(true) -> educkui_style:from([{reverse, true}]);
focus_style(false) -> undefined.

-spec checkbox_label(term()) -> binary().
checkbox_label(true) -> <<"[x]">>;
checkbox_label(_) -> <<"[ ]">>.

-spec mask(binary()) -> binary().
mask(Value) ->
    binary:copy(<<"*">>, string:length(Value)).

%% ---------------------------------------------------------------------------
%% Internal helpers
%% ---------------------------------------------------------------------------

-spec current_field(map()) -> map() | undefined.
current_field(State) ->
    case maps:get(submit_focused, State, false) of
        true ->
            undefined;
        false ->
            case maps:get(focused_field, State, undefined) of
                undefined -> undefined;
                Id -> get_field(State, Id)
            end
    end.

-spec current_text_field(map()) -> boolean().
current_text_field(State) ->
    case current_field(State) of
        undefined -> false;
        F -> lists:member(maps:get(type, F), [text, password])
    end.

-spec text_cursor(map(), atom()) -> non_neg_integer().
text_cursor(State, Id) ->
    case get_field(State, Id) of
        undefined -> 0;
        F ->
            case lists:member(maps:get(type, F), [text, password]) of
                true -> string:length(field_value(State, Id));
                false -> 0
            end
    end.

-spec get_field(map(), atom()) -> map() | undefined.
get_field(State, Id) ->
    Fields = maps:get(fields, State),
    case [F || F <- Fields, maps:get(id, F) =:= Id] of
        [F | _] -> F;
        [] -> undefined
    end.

-spec visible_fields(map()) -> [map()].
visible_fields(State) ->
    Values = maps:get(values, State),
    [F || F <- maps:get(fields, State), field_visible(F, Values)].

-spec field_value(map(), atom()) -> term().
field_value(State, Id) ->
    maps:get(Id, maps:get(values, State), <<>>).

-spec option_field(map() | undefined) -> boolean().
option_field(undefined) -> false;
option_field(F) ->
    lists:member(maps:get(type, F), [radio, select, multi_select]).

-spec has_options(map() | undefined) -> boolean().
has_options(undefined) -> false;
has_options(F) ->
    maps:get(options, F, []) =/= [].

-spec option_value(term()) -> term().
option_value({V, _L}) -> V;
option_value(V) -> V.

-spec option_label(term()) -> binary().
option_label({_V, L}) -> to_bin(L);
option_label(V) -> to_bin(V).

-spec find_option_index(term(), [term()]) -> non_neg_integer().
find_option_index(Value, Opts) ->
    find_option_index(Value, Opts, 0).

-spec find_option_index(term(), [term()], non_neg_integer()) -> non_neg_integer().
find_option_index(_Value, [], _I) ->
    0;
find_option_index(Value, [O | T], I) ->
    case option_value(O) =:= Value of
        true -> I;
        false -> find_option_index(Value, T, I + 1)
    end.

-spec pad_display(binary(), non_neg_integer()) -> binary().
pad_display(Bin, W) ->
    Cur = educkui_display_width:string_width(Bin),
    case Cur >= W of
        true -> Bin;
        false -> <<Bin/binary, (binary:copy(<<" ">>, W - Cur))/binary>>
    end.

-spec join([binary()], binary()) -> binary().
join([], _Sep) -> <<>>;
join([H | T], Sep) ->
    lists:foldl(fun(X, Acc) -> <<Acc/binary, Sep/binary, X/binary>> end, H, T).

-spec clamp(integer(), integer(), integer()) -> integer().
clamp(Min, _Max, V) when V < Min -> Min;
clamp(_Min, Max, V) when V > Max -> Max;
clamp(_Min, _Max, V) -> V.

-spec index_of(term(), [term()]) -> non_neg_integer().
index_of(X, List) ->
    case index_of(X, List, 0) of
        not_found -> 0;
        I -> I
    end.

-spec index_of(term(), [term()], non_neg_integer()) -> non_neg_integer() | not_found.
index_of(_X, [], _I) -> not_found;
index_of(X, [H | T], I) ->
    case X =:= H of
        true -> I;
        false -> index_of(X, T, I + 1)
    end.

-spec to_bin(term()) -> binary().
to_bin(B) when is_binary(B) -> B;
to_bin(A) when is_atom(A) -> atom_to_binary(A, utf8);
to_bin(I) when is_integer(I) -> integer_to_binary(I);
to_bin(T) -> unicode:characters_to_binary(io_lib:format("~p", [T])).
