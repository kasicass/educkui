# Widgets

educkui ships 34 widgets under `src/widgets/`. Stateful widgets implement
`educkui_elm` and are embedded with `component/3`; stateless widgets implement
`educkui_component` and are embedded with `widget/3`.

Props are passed as maps. For stateful widgets, `init/1` receives the props as
a proplist; for stateless widgets, `render/2` receives the props map directly.

## Text and input

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_label` | stateless | `text`, `align` (`left`/`center`/`right`), `wrap`, `truncate`, `style` |
| `educkui_widget_text_input` | stateful | `value`, `placeholder`; controllable via `handle_props/2` |
| `educkui_widget_text_area` | stateful | `value`; controllable via `handle_props/2` |
| `educkui_widget_text_view` | stateless | `lines` (`[[{Text, Style}]]`), `style` — pre-split styled spans (JSON/log highlighting) |
| `educkui_widget_pick_list` | stateful | `items`, `selected`, `prompt` |
| `educkui_widget_list` | stateless | `items`, `selected`, `offset`, `style`, `selected_style`; helper `visible_range/3,4` |
| `educkui_widget_scrollable_list` | stateful | `items`, `height`, `selected` |
| `educkui_widget_markdown_viewer` | stateless | `text` |

## Buttons and forms

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_button` | stateless | `label`, `focused`, `style`, `focus_style` |
| `educkui_widget_push_button` | stateful | `label`, `id` |
| `educkui_widget_form_builder` | stateful | `fields`, `groups`, `values`, `show_submit_button`, `submit_label`, `validate_on_blur`, `label_width`, `field_width`, `on_submit`, `on_change` |

Field definitions for `form_builder` support `id`, `type` (`text`,
`password`, `checkbox`, `radio`, `select`, `multi_select`), `label`,
`options`, `required`, `validators`, `visible_when`, `group`, `placeholder`
and `default`.

## Containers and navigation

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_block` | stateless | `border`, `style`, `border_style` |
| `educkui_widget_viewport` | stateless | `content`, `scroll_y`, `content_height` |
| `educkui_widget_scroll_bar` | stateless | `total`, `offset`, `viewport`, `vertical` |
| `educkui_widget_tabs` | stateful | `tabs` (`[{Title, ContentNode}]`) |
| `educkui_widget_split_pane` | stateless | `direction`, `left`, `right`, `ratio` |
| `educkui_widget_tree_view` | stateful | `items` (`[{Id, Label, Children}]`) |
| `educkui_widget_menu` | stateless | `items` (`[{Id, Label, Children}]`) |

## Overlays and dialogs

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_dialog` | stateless | `title`, `content`, `buttons`, `width`, `height`, `style` |
| `educkui_widget_alert_dialog` | stateless | `buttons` (default `[<<"OK">>, <<"Cancel">>]`) plus dialog props |
| `educkui_widget_context_menu` | stateless | `items`, `selected`, `x`, `y`, `style` |
| `educkui_widget_toast` | stateless | `message`, `style` |
| `educkui_widget_command_palette` | stateful | `commands` (`[{Label, Payload}]`) |

## Visualization

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_progress` | stateless | `value` (0.0..1.0), `style`, `fill_style` |
| `educkui_widget_gauge` | stateless | `value` (0.0..1.0), `style`, `fill_style` |
| `educkui_widget_sparkline` | stateless | `values`, `style` |
| `educkui_widget_line_chart` | stateless | `values`, `style` |
| `educkui_widget_bar_chart` | stateless | `values`, `style`, `fill_style` |
| `educkui_widget_canvas` | stateless | `pixels` (`[{X, Y, Char}]`) |
| `educkui_widget_spinner` | stateless | `frame`, `frames`, `suffix`, `style` |

## Tables and BEAM introspection

| Widget | Type | Props |
|---|---|---|
| `educkui_widget_table` | stateless | `rows`, `header`, `widths`, `align`, `selected`, `selected_style`, `column_styles`, `style`, `header_style` |
| `educkui_widget_process_monitor` | stateless | `rows` (`[{Name, Memory, Reductions}]`) |
| `educkui_widget_supervision_tree_viewer` | stateless | `tree` (`[{Label, Children}]`) |
| `educkui_widget_log_viewer` | stateless | `lines`, `height` |
| `educkui_widget_cluster_dashboard` | stateless | `nodes` (`[{Name, Slogan}]`) |
| `educkui_widget_stream` | stateful | `buffer_size`, `overflow_strategy`, `show_stats`, `height`, `item_renderer`, `on_item`, `on_error` |

`stream` receives data via
`educkui_runtime:send_message(Runtime, Id, {stream_item, Data})` or
`{stream_items, [Data]}`.

## Adding a widget

Stateful widgets implement `educkui_elm`:

```erlang
-behaviour(educkui_elm).
-export([init/1, event_to_msg/2, update/2, view/1]).
```

Stateless widgets implement `educkui_component`:

```erlang
-behaviour(educkui_component).
-export([render/2, describe/0, default_props/0]).
```

Then compose them in a root `view/1` with `educkui_render_node:widget/3` or
`educkui_render_node:component/3`.
