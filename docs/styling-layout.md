# Styling and layout

## Styles

Styles are `#dui_style{}` records with three fields:

```erlang
-record(dui_style, {
    fg = undefined,       %% foreground color or undefined (inherit)
    bg = undefined,       %% background color or undefined (inherit)
    attrs = []            %% ordset of style attributes
}).
```

Build styles with `educkui_style`:

```erlang
Style = educkui_style:from([{fg, cyan}, {bg, default}, {bold, true}]),
Style2 = educkui_style:bg(Style, blue),
Style3 = educkui_style:add_attr(Style2, underline).
```

Attributes: `bold`, `dim`, `italic`, `underline`, `blink`, `reverse`,
`hidden`, `strikethrough`.

`merge/2` and `inherit/2` combine styles; `undefined` fields mean "not set"
and inherit from the surrounding style, while `default` is the explicit
terminal default color.

## Colors

Colors can be:

- named atoms: `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`,
  `white` and their `bright_*` variants
- 256-color indexes: `0..255`
- true color tuples: `{R, G, B}` with `0..255`

`educkui_theme` maps style names to `#dui_style{}` values and provides the
named-color to RGB table:

```erlang
Theme = educkui_theme:new(),
Theme1 = educkui_theme:put(Theme, title, educkui_style:from([{fg, cyan}, {bold, true}])),
Style = educkui_theme:get(Theme1, title, educkui_style:new()).
```

## Character sets

`educkui_character_set` provides Unicode box-drawing characters with ASCII
fallback for terminals without Unicode support:

```erlang
Chars = educkui_character_set:border(unicode),
TopLeft = maps:get(top_left, Chars).   %% ┌ or +
```

## Display width and graphemes

`educkui_display_width` computes terminal column widths, including
double-width East Asian and emoji presentation characters:

```erlang
W = educkui_display_width:string_width(<<"你好">>),   %% 4
{Truncated, Used} = educkui_display_width:truncate(Text, MaxWidth).
```

Rendering is grapheme-cluster aware: text is split with
`string:to_graphemes/1`, so combining characters are never split, and wide
characters produce a placeholder cell in the following column.

## Layout

Render nodes use a simple flex layout solver:

- fixed sizes are honored first,
- remaining space is distributed to flex (`auto`) items,
- alignment is `start`, `center`, `end` or `space_between`.

`educkui_render_node:stack/3` accepts layout options:

```erlang
educkui_render_node:stack(vertical, Children, [{align, center}]),
educkui_render_node:stack(horizontal, Children, [{align, space_between}]).
```

Nodes can override their natural size with `width/2` and `height/2`:

```erlang
educkui_render_node:height(educkui_render_node:text(<<"x">>), 10).
```

`educkui_layout_cache` provides an ETS-backed cache for layout results.

## Render tree sizing

Natural sizes are computed recursively by `educkui_render`:

- text nodes size to their widest line and line count,
- `cells` nodes size to their maximum `{X, Y}` coordinates,
- stacks sum child sizes vertically or take the maximum horizontally,
- component/widget nodes are resolved to compute their natural size.

Explicit `width`/`height` overrides always win over natural sizes.
