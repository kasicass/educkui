%% @doc Shared records for educkui.
%%
%% Records are used for the hot-path core types (cell, style, rect, event,
%% render node, runtime state) per the OTP Efficiency Guide: they give
%% compile-time field checking and use slightly less memory than small maps.
%%
%% Users may include this header with:
%%   -include_lib("educkui/include/educkui.hrl").
-ifndef(EDUCKUI_HRL).
-define(EDUCKUI_HRL, true).

%% Terminal default color marker.
-define(DUI_COLOR_DEFAULT, default).

%% ---------------------------------------------------------------------------
%% Style
%% ---------------------------------------------------------------------------
-record(dui_style, {
    fg = undefined :: term(),        %% undefined means "not set" (inherit);
                                     %% 'default' is the explicit terminal default
    bg = undefined :: term(),
    attrs = [] :: [atom()]           %% ordset of style attributes
}).

%% ---------------------------------------------------------------------------
%% Cell
%% ---------------------------------------------------------------------------
-record(dui_cell, {
    char = <<" ">> :: binary(),      %% grapheme cluster
    fg = default :: term(),
    bg = default :: term(),
    attrs = [] :: [atom()],          %% ordset of style attributes
    width = 1 :: 0 | 1 | 2,          %% display width (0 = placeholder)
    placeholder = false :: boolean()  %% wide-char second-column placeholder
}).

%% ---------------------------------------------------------------------------
%% Rect (render area)
%% ---------------------------------------------------------------------------
-record(dui_rect, {
    x = 0 :: integer(),
    y = 0 :: integer(),
    width = 0 :: non_neg_integer(),
    height = 0 :: non_neg_integer()
}).

%% ---------------------------------------------------------------------------
%% Event
%% ---------------------------------------------------------------------------
-record(dui_event, {
    type :: atom(),                   %% key | mouse | focus | resize | paste | tick | custom
    key :: atom() | binary() | undefined,
    char :: binary() | undefined,
    modifiers = [] :: [atom()],       %% ordset([ctrl, shift, alt, meta])
    action :: atom() | undefined,
    button :: atom() | undefined,     %% left | middle | right
    x :: integer() | undefined,
    y :: integer() | undefined,
    width :: pos_integer() | undefined,
    height :: pos_integer() | undefined,
    interval :: pos_integer() | undefined,
    content :: term() | undefined,    %% paste content / custom payload
    timestamp = 0 :: integer()
}).

%% ---------------------------------------------------------------------------
%% Render node
%% ---------------------------------------------------------------------------
-record(dui_node, {
    type :: atom(),                   %% text | box | stack | cells | empty | component
    content :: binary() | undefined,
    style :: term() | undefined,      %% #dui_style{}
    children = [] :: [term()],        %% [#dui_node{}]
    direction :: vertical | horizontal | undefined,
    width :: non_neg_integer() | auto | undefined,
    height :: non_neg_integer() | auto | undefined,
    align :: start | center | 'end' | space_between | undefined,
    cells :: [{integer(), integer(), term()}] | undefined,
    component_id :: term() | undefined,
    module :: module() | undefined,
    props :: map() | undefined,
    x :: integer() | undefined,
    y :: integer() | undefined
}).

%% ---------------------------------------------------------------------------
%% Component instance (a node in the runtime component tree)
%% ---------------------------------------------------------------------------
-record(dui_component, {
    id :: term(),
    module :: module(),
    state = undefined :: term(),
    props = #{} :: map()
}).

%% ---------------------------------------------------------------------------
%% Screen buffer (ETS-backed)
%% ---------------------------------------------------------------------------
-record(dui_buffer, {
    table :: ets:tid() | undefined,
    rows = 0 :: non_neg_integer(),
    cols = 0 :: non_neg_integer()
}).

%% ---------------------------------------------------------------------------
%% Cursor optimizer state
%% ---------------------------------------------------------------------------
-record(dui_cursor, {
    row = 1 :: pos_integer(),
    col = 1 :: pos_integer(),
    bytes_saved = 0 :: non_neg_integer()
}).

%% ---------------------------------------------------------------------------
%% Escape sequence buffer
%% ---------------------------------------------------------------------------
-record(dui_seqbuf, {
    buffer = [] :: iodata(),
    size = 0 :: non_neg_integer(),
    threshold = 4096 :: pos_integer(),
    pending_sgr = [] :: [string()],
    last_style :: term() | undefined,
    total_bytes = 0 :: non_neg_integer(),
    flush_count = 0 :: non_neg_integer()
}).

%% ---------------------------------------------------------------------------
%% Runtime state
%% ---------------------------------------------------------------------------
-record(dui_runtime_state, {
    root_module :: module() | undefined,
    root_state :: term() | undefined,
    render_interval = 16 :: pos_integer(),
    terminal_started = false :: boolean(),
    current_buffer :: term() | undefined,
    previous_buffer :: term() | undefined,
    dimensions :: {pos_integer(), pos_integer()} | undefined,
    backend_mode :: raw | tty | skip | undefined,
    backend :: module() | undefined,
    backend_state :: term() | undefined,
    input_handler :: module() | undefined,
    input_state :: term() | undefined,
    input_reader :: pid() | undefined,
    command_executor :: pid() | undefined,
    capabilities :: map() | undefined,
    logger_handler_config :: term() | undefined,
    dirty = false :: boolean(),
    last_render :: integer() | undefined,
    focus = [] :: [term()],
    targets = [] :: [{term(), term()}],
    components = #{} :: map(),        %% Id => #dui_component{}
    focus_order = [] :: [term()],
    escape_timer :: reference() | undefined,
    shortcuts = [] :: [{term(), term()}]
}).

-endif.
