# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-06-04

Initial release.

### Added

- **Core runtime** — a Model–Update–View architecture. Application state is a
  plain struct; `update(model, msg)` returns the next model plus a `Cmd`;
  `view(model)` renders to an ANSI string. The runtime owns raw terminal mode,
  input parsing, and diff-based re-rendering. Messages are typed: key presses,
  mouse events, resize, timer ticks, and custom events. Input parsing handles
  the Kitty/CSI-u keyboard protocol and SGR mouse reporting.
- **Structured view (opt-in)** — `Program::with_structured_view` lets a frame
  carry per-frame terminal state alongside its content: cursor position,
  visibility, and shape; window title; default foreground/background color;
  progress; and mouse mode. Unchanged state is not re-emitted between frames.
- **Components** — spinner, text input, textarea, list, selection list, table,
  paginator, viewport, timer, stopwatch, file picker, progress bar, virtual
  cursor, and key-binding/help. Each is a composable Model that embeds in a
  larger application.
- **Styling and layout** — `Style`/`Color` with hex, RGB, ANSI-indexed, and
  adaptive (light/dark) colors; borders, padding, margins, alignment, joins,
  and placement; and the `col`/`row`/`lines`/`text`/`gap`/`hgap` layout DSL.
- **Color profiles** — TrueColor, ANSI-256, ANSI-16, and NoColor, with
  automatic downsampling (truecolor → 256 → 16) and a `RenderContext` that
  resolves adaptive colors against the detected or configured background.
- **Width handling** — grapheme-cluster, wide-character, and ANSI/OSC-aware
  width measurement, and an ANSI- and OSC-8-aware `word_wrap`.
- **Terminal primitives** — OSC 8 hyperlinks, DECSCUSR cursor shape, OSC 52
  clipboard read and write, normal/cell-motion/all-motion mouse modes,
  bracketed paste, focus reporting, synchronized output, OSC 9;4 progress, and
  window-title control. Each is exposed as an ANSI builder and, where the state
  persists across frames, as a runtime `Cmd`.
- **Theme layer** (`@pippa/theme`) — semantic roles (`RoleKey`) that resolve to
  styles through a `Theme` and `RenderContext`, so components and documents draw
  from one adaptive palette rather than hardcoded colors.
- **Forms** (`@pippa/form`) — composable input groups as a nested Model: text,
  password, select, and confirm fields; pure validators; submit via a
  `FormValues -> Result[A, errors]` decoder; and an immutable focus ring.
- **Markdown** (`@pippa/markdown`) — CommonMark rendering to themed ANSI through
  a styled-span intermediate representation: text is measured and wrapped as
  plain text, with ANSI emitted last. Links use OSC 8. GFM tables, task lists,
  strikethrough, and autolinks render under an opt-in flavor, and tables support
  wrap and truncate modes at narrow widths. CommonMark parsing uses the
  `moonbit-community/cmark` package.
- **Syntax highlighting** (`@pippa/syntax`) — a state-machine lexer kernel with
  lexers for MoonBit, JSON, Shell, Diff, and plain text, rendering tokens
  through the theme layer. Markdown highlights fenced code blocks when a syntax
  registry is supplied; otherwise fences render plain.

The library builds and tests on the native, JS, and WASM-GC backends.

[Unreleased]: https://github.com/brickfrog/pippa/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/brickfrog/pippa/releases/tag/v0.1.0
