%% @doc Global keyboard shortcut matching.
%%
%% A shortcut spec is `{KeySpec, Modifiers}' where `KeySpec' is an atom
%% (`enter', `up', ...) or a binary (`<<"q">>') and `Modifiers' is a list of
%% modifier atoms (`ctrl', `shift', `alt', `meta'). Matching is exact on both
%% key and modifier set.
-module(educkui_shortcut).

-include("educkui.hrl").

-export([match/2, find/2]).

-spec match(#dui_event{}, term()) -> boolean().
match(#dui_event{type = key, key = Key, modifiers = Mods}, {KeySpec, ModsSpec}) ->
    Key =:= KeySpec andalso
    ordsets:from_list(Mods) =:= ordsets:from_list(ModsSpec);
match(_Event, _Spec) ->
    false.

%% @doc Finds the first shortcut command matching the event.
-spec find(#dui_event{}, [{term(), term()}]) -> {ok, term()} | none.
find(Event, Shortcuts) when is_list(Shortcuts) ->
    case [Command || {Spec, Command} <- Shortcuts, match(Event, Spec)] of
        [Command | _] -> {ok, Command};
        [] -> none
    end.
