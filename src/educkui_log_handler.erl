%% @doc `logger' handler that forwards events to `educkui_log'.
%%
%% Installed by `educkui_runtime' while the alternate screen is active. It
%% never writes to the terminal, so log output cannot corrupt the TUI.
-module(educkui_log_handler).

-behaviour(logger_handler).

-export([adding_handler/1, changing_config/3, filter_config/1, log/2,
         removing_handler/1]).

-spec adding_handler(logger:handler_config()) ->
    {ok, logger:handler_config()} | {error, term()}.
adding_handler(Config) ->
    {ok, Config}.

-spec changing_config(set | update, logger:handler_config(),
                      logger:handler_config()) ->
    {ok, logger:handler_config()} | {error, term()}.
changing_config(_SetOrUpdate, _OldConfig, NewConfig) ->
    {ok, NewConfig}.

-spec filter_config(logger:handler_config()) -> logger:handler_config().
filter_config(Config) ->
    Config.

-spec log(logger:log_event(), logger:handler_config()) -> ok.
log(Event, _Config) ->
    educkui_log:add(Event),
    ok.

-spec removing_handler(logger:handler_config()) -> ok.
removing_handler(_Config) ->
    ok.
