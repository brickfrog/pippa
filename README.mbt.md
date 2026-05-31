# Pippa

A terminal UI framework for [MoonBit](https://www.moonbitlang.com/), inspired by
[bubbletea](https://github.com/charmbracelet/bubbletea) (Go) and the
[Elm Architecture](https://guide.elm-lang.org/architecture/).

![Pippa showcase](pippa.png)

## Overview

Pippa provides a **Model–Update–View** pattern where:

- **Model** — application state is a plain struct.
- **Msg** — updates are driven by typed messages (key presses, resize, timers,
  custom events).
- **View** — the view function renders state to a string of ANSI-formatted
  output.

The runtime handles raw terminal mode, input parsing, and efficient
diffing and re-rendering, so library users only think about state transitions
and string output.

A component library ships alongside the core — spinners, text inputs, textareas,
lists, selection lists, tables, paginators, viewports, timers, stopwatches,
file pickers, and animated progress bars — each implemented as composable
Models that can be embedded in larger applications.

A richer `styling` package is also included for layout and visual styling:
hex/RGB colors, borders, padding, margins, joins, placement, and higher-level
composition primitives.

## Quick Start

```bash
moon test
moon run src/examples/showcase
```

The showcase example exercises the runtime, components, styling, spring
animation, focus handling, and viewport behavior.

## Keymaps and Help

Key bindings separate activation keys from display help. Prefer constructors
over raw struct literals:

```moonbit
let quit = binding(keys=["q", "ctrl+c"], help_key="q", help="quit")
let model = help_model(
  keymap=keymap([quit]),
  show_full=false,
  width=80,
)
let footer = help_view(model)
```

When migrating older code, replace flat `Binding::{ keys, help }` values with
`binding(keys=..., help_key=..., help=...)`. Replace
`HelpModel::{ bindings, show_full }` with `help_model(keymap=keymap(bindings),
show_full=..., width=...)`. Disabled or unbound bindings do not match and are
omitted from both short and full help.

## View Surface

The common `Program::new(..., view=fn(model) { "..." })` shape remains a plain
`Model -> String` function. Apps that need per-render terminal state can opt in
with one extra builder call:

```moonbit
let program = Program::new(
    init=my_init,
    update=my_update,
    view=my_string_view,
  )
  .with_structured_view(fn(model) {
    View::text(my_string_view(model))
    .with_window_title("Pippa")
    .with_cursor_visible(true)
  })
```

For now, the renderer uses `View.content` exactly like the old string view. The
optional cursor, title, color, progress, and mouse-mode fields are carried with
the frame for the next renderer pass.

## Project Structure

```text
src/                          # Source root (moon.mod.json → source: "src")
├── moon.pkg                  # Core library package
├── types.mbt                 # Cmd, UpdateResult, WindowSize, Program
├── message.mbt               # KeyMsg, MouseMsg, InputEvent
├── command.mbt               # Command helpers and composition
├── program.mbt               # Program[Model, Msg] entry point
├── ansi.mbt                  # ANSI escape sequence helpers
├── component/                # Composable component sub-package
│   ├── moon.pkg
│   └── ...                   # Spinner, textarea, viewport, progress, etc.
├── styling/                  # Higher-level styling and layout package
│   ├── moon.pkg
│   └── styling.mbt
└── examples/
    ├── hello/                # Minimal example app
    ├── structured-view/      # View.content plus per-frame terminal state
    └── showcase/             # Rich interactive demo
```

## Development

```bash
moon check          # Type-check the project
moon fmt            # Format all source files
moon info           # Refresh generated package interfaces
moon test           # Run all tests
moon test --update  # Run tests and update snapshots
moon run src/examples/hello  # Run the hello example
moon run src/examples/structured-view  # Run the structured View example
moon run src/examples/showcase  # Run the showcase demo
```

## License

Apache-2.0
