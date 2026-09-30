%% @doc Character sets for drawing, with ASCII fallback.
%%
%% `unicode' uses box-drawing characters; `ascii' uses `+', `-', `|' so that
%% borders and charts degrade gracefully on ASCII-only terminals.
-module(educkui_character_set).

-export([border/1, get/2]).

-define(UNICODE_BORDER, #{
    top_left => <<"┌"/utf8>>,
    top_right => <<"┐"/utf8>>,
    bottom_left => <<"└"/utf8>>,
    bottom_right => <<"┘"/utf8>>,
    horizontal => <<"─"/utf8>>,
    vertical => <<"│"/utf8>>,
    cross => <<"┼"/utf8>>,
    tee_down => <<"┬"/utf8>>,
    tee_up => <<"┴"/utf8>>,
    tee_right => <<"├"/utf8>>,
    tee_left => <<"┤"/utf8>>
}).

-define(ASCII_BORDER, #{
    top_left => <<"+">>,
    top_right => <<"+">>,
    bottom_left => <<"+">>,
    bottom_right => <<"+">>,
    horizontal => <<"-">>,
    vertical => <<"|">>,
    cross => <<"+">>,
    tee_down => <<"+">>,
    tee_up => <<"+">>,
    tee_right => <<"+">>,
    tee_left => <<"+">>
}).

-type charset() :: unicode | ascii.
-export_type([charset/0]).

-spec border(charset()) -> map().
border(unicode) -> ?UNICODE_BORDER;
border(ascii) -> ?ASCII_BORDER.

-spec get(charset(), atom()) -> binary().
get(Charset, Key) ->
    maps:get(Key, border(Charset)).
