# educkui counter example

A minimal The Elm Architecture application:

- `init/1` returns initial state
- `event_to_msg/2` maps terminal events to messages
- `update/2` transforms state (and returns commands)
- `view/1` renders state to a render tree

Run it in a real terminal:

```bash
./examples/counter/run.sh
```

Use ↑/↓ to change the counter, press `Q` to quit. The terminal is restored
cleanly on exit.
