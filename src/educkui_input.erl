%% @doc Behaviour for input handlers.
%%
%% An input handler converts terminal input into `#dui_event{}` records.
%% Two implementations are provided:
%% - `educkui_input_raw` - character-by-character input in raw mode
%% - `educkui_input_tty` - line-based input in cooked/tty mode
-module(educkui_input).

-export_type([state/0, poll_result/0]).

-type state() :: term().
-type poll_result() ::
    {{ok, term()}, state()}
    | {timeout, state()}
    | {eof, state()}.

-callback new() -> state().
-callback poll(state(), non_neg_integer()) -> poll_result().
-callback mode(state()) -> raw | tty.
-callback stop(state()) -> ok.
