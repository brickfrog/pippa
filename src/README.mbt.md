# Pippa

A terminal UI framework for [MoonBit](https://www.moonbitlang.com/), inspired by
[bubbletea](https://github.com/charmbracelet/bubbletea) (Go) and the
[Elm Architecture](https://guide.elm-lang.org/architecture/).

## Overview

Pippa provides a **Model–Update–View** pattern where:

- **Model** — application state is a plain struct.
- **Msg** — updates are driven by typed messages (key presses, resize, timers,
  custom events).
- **View** — the view function renders state to a string of ANSI-formatted
  output.

The runtime handles raw terminal mode, input parsing, and efficient
diffing/re-rendering, so library users only think about state transitions and
string output.

A component library ships alongside the core — spinners, text inputs, selection
lists, tables, progress bars — each implemented as composable Models that can be
embedded in larger applications.

## Project Structure

```
src/                          # Source root (moon.mod.json → source: "src")
├── moon.pkg                  # Core library package
├── types.mbt                 # Cmd, UpdateResult, WindowSize, InternalMsg
├── message.mbt               # KeyMsg, MouseMsg
├── command.mbt               # Cmd::none, Cmd::batch, Cmd::map
├── program.mbt               # Program[Model, Msg] entry point
├── ansi.mbt                  # ANSI escape sequence helpers
├── component/                # Composable component sub-package
│   ├── moon.pkg
│   └── types.mbt             # Component[Model, Msg] base type
└── examples/
    └── hello/                # Minimal example app
        ├── moon.pkg
        └── main.mbt
```

## Development

```bash
moon check          # Type-check the project
moon fmt            # Format all source files
moon test           # Run all tests
moon test --update  # Run tests and update snapshots
moon run src/examples/hello  # Run the hello example
```

## License

Apache-2.0
