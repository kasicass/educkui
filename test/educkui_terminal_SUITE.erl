%% @doc End-to-end terminal tests driven through tmux.
%%
%% Runs the example applications in a real pseudo-terminal, sends keys via
%% `tmux send-keys`, and asserts on the rendered screen content. This catches
%% regressions that pure EUnit tests cannot (raw mode, focus cycling, dialogs).
-module(educkui_terminal_SUITE).

-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1]).
-export([counter_smoke/1, dashboard_tab_edit/1, dashboard_dialog/1]).

all() ->
    [counter_smoke, dashboard_tab_edit, dashboard_dialog].

-spec init_per_suite(term()) -> term().
init_per_suite(Config) ->
    LibDir = code:lib_dir(educkui),
    Root = filename:dirname(
        filename:dirname(
            filename:dirname(filename:dirname(LibDir)))),
    Ebin = LibDir ++ "/ebin",
    Include = Root ++ "/include",
    Examples = Root ++ "/examples",
    _ = os:cmd("rebar3 compile"),
    _ = file:make_dir("/tmp/dui_ct_examples"),
    _ = os:cmd("erlc -I " ++ Include ++ " -pa " ++ Ebin ++
               " -o /tmp/dui_ct_examples " ++
               Examples ++ "/counter/dui_counter.erl " ++
               Examples ++ "/dashboard/dui_dashboard.erl"),
    ok = write_script("/tmp/dui_ct_counter.sh",
        erl_script(Ebin, [{root, dui_counter}])),
    ok = write_script("/tmp/dui_ct_dashboard.sh",
        erl_script(Ebin, [{root, dui_dashboard},
                          {shortcuts, [{{<<"d">>, [ctrl]}, {msg, toggle_dialog}}]}])),
    Config.

-spec end_per_suite(term()) -> ok.
end_per_suite(_Config) ->
    ok.

%% ---------------------------------------------------------------------------
%% Tests
%% ---------------------------------------------------------------------------

counter_smoke(_Config) ->
    with_tmux("ct_counter", "/tmp/dui_ct_counter.sh", fun() ->
        timer:sleep(2000),
        Screen = capture("ct_counter"),
        ok = assert_contains(Screen, "Counter: 0"),
        keys("ct_counter", "q"),
        timer:sleep(1500)
    end).

dashboard_tab_edit(_Config) ->
    with_tmux("ct_dash", "/tmp/dui_ct_dashboard.sh", fun() ->
        timer:sleep(2000),
        keys("ct_dash", "Tab"),
        keys("ct_dash", "Tab"),
        keys("ct_dash", "k"),
        timer:sleep(800),
        Screen = capture("ct_dash"),
        ok = assert_contains(Screen, "Alicek"),
        keys("ct_dash", "Escape"),
        keys("ct_dash", "Escape"),
        timer:sleep(1500)
    end).

dashboard_dialog(_Config) ->
    with_tmux("ct_dlg", "/tmp/dui_ct_dashboard.sh", fun() ->
        timer:sleep(2000),
        keys("ct_dlg", "C-d"),
        timer:sleep(800),
        Screen1 = capture("ct_dlg"),
        ok = assert_contains(Screen1, "About"),
        ok = assert_contains(Screen1, "[OK]"),
        %% Enter activates the focused OK button and closes the dialog.
        keys("ct_dlg", "Enter"),
        timer:sleep(800),
        Screen2 = capture("ct_dlg"),
        ok = assert_not_contains(Screen2, "About"),
        keys("ct_dlg", "Escape"),
        timer:sleep(1500)
    end).

%% ---------------------------------------------------------------------------
%% Helpers
%% ---------------------------------------------------------------------------

-spec write_script(string(), string()) -> ok.
write_script(Path, Content) ->
    ok = file:write_file(Path, <<"#!/bin/sh\n", (list_to_binary(Content))/binary, "\n">>),
    _ = os:cmd("chmod +x " ++ Path),
    ok.

-spec erl_script(string(), [{atom(), term()}]) -> string().
erl_script(Ebin, Opts) ->
    OptsStr = string:join([format_opt(O) || O <- Opts], ", "),
    "erl -noshell -pa /tmp/dui_ct_examples -pa " ++ Ebin ++
        " -eval 'educkui:run([" ++ OptsStr ++ "]).' -eval 'init:stop().'".

-spec format_opt({atom(), term()}) -> string().
format_opt({shortcuts, Shortcuts}) ->
    "{shortcuts, [" ++
        string:join([format_shortcut(S) || S <- Shortcuts], ",") ++ "]}";
format_opt({root, Mod}) ->
    "{root, " ++ atom_to_list(Mod) ++ "}".

-spec format_shortcut({term(), term()}) -> string().
format_shortcut({{Key, Mods}, Action}) ->
    "{{<<\"" ++ binary_to_list(Key) ++ "\">>, [" ++
        string:join([atom_to_list(M) || M <- Mods], ",") ++
        "]}, " ++ format_action(Action) ++ "}".

-spec format_action(term()) -> string().
format_action({msg, toggle_dialog}) -> "{msg, toggle_dialog}".

-spec with_tmux(string(), string(), fun(() -> term())) -> ok.
with_tmux(Session, Script, Fun) ->
    _ = os:cmd("tmux new-session -d -s " ++ Session ++ " -x 100 -y 30 sh " ++ Script),
    try
        _ = Fun(),
        ok
    after
        _ = os:cmd("tmux kill-session -t " ++ Session ++ " 2>/dev/null || true"),
        ok
    end.

-spec keys(string(), string()) -> string().
keys(Session, Keys) ->
    os:cmd("tmux send-keys -t " ++ Session ++ " " ++ Keys).

-spec capture(string()) -> string().
capture(Session) ->
    os:cmd("tmux capture-pane -t " ++ Session ++ " -p").

-spec assert_contains(string(), string()) -> ok.
assert_contains(Haystack, Needle) ->
    case string:find(Haystack, Needle) of
        nomatch -> ct:fail("expected to find ~p in screen:~n~s",
                           [Needle, Haystack]);
        _ -> ok
    end.

-spec assert_not_contains(string(), string()) -> ok.
assert_not_contains(Haystack, Needle) ->
    case string:find(Haystack, Needle) of
        nomatch -> ok;
        _ -> ct:fail("expected NOT to find ~p in screen:~n~s",
                     [Needle, Haystack])
    end.
