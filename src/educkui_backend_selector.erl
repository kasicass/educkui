%% @doc Backend selection.
%%
%% Strategy: "try raw mode first". `auto' attempts raw mode and falls back to
%% TTY when raw mode is unavailable (no tty, pipes, remote consoles).
%% `raw' forces raw mode and errors if unavailable; `tty' always selects TTY.
-module(educkui_backend_selector).

-export([select/1]).

-type mode() :: auto | raw | tty.
-export_type([mode/0]).

-spec select(mode()) ->
    {ok, {raw | tty, module()}} | {error, term()}.
select(tty) ->
    {ok, {tty, educkui_backend_tty}};
select(Mode) when Mode =:= auto; Mode =:= raw ->
    case educkui_terminal:activate_raw_mode() of
        ok ->
            {ok, {raw, educkui_backend_raw}};
        {error, Reason} ->
            case Mode of
                raw -> {error, Reason};
                auto -> {ok, {tty, educkui_backend_tty}}
            end
    end.
