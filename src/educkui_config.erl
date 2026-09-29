%% @doc Configuration helpers.
%%
%% Runtime options take precedence over `educkui` application environment
%% values.
-module(educkui_config).

-export([merge_options/1, get/2, get/3]).

-spec merge_options([{atom(), term()}]) -> [{atom(), term()}].
merge_options(Opts) when is_list(Opts) ->
    AppOpts = application:get_all_env(educkui),
    lists:foldl(
        fun({Key, Value}, Acc) ->
            case lists:keymember(Key, 1, Acc) of
                true -> Acc;
                false -> [{Key, Value} | Acc]
            end
        end,
        Opts,
        AppOpts).

-spec get(atom(), [{atom(), term()}]) -> term().
get(Key, Opts) ->
    proplists:get_value(Key, Opts).

-spec get(atom(), [{atom(), term()}], term()) -> term().
get(Key, Opts, Default) ->
    proplists:get_value(Key, Opts, Default).
