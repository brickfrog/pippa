///|
/// Base types for composable TUI components.
///
/// Each component (spinner, text input, list, etc.) is itself a mini
/// Model–Update–View that can be embedded in a larger application. Components
/// expose `Component[Model, Msg]` which wraps the three core functions.

///|
/// A composable component that follows the same Elm Architecture as a full
/// Program but is designed to be embedded inside a parent model.
///
/// Users interact with a component by:
/// 1. Including its `Model` as a field in the parent model.
/// 2. Calling `component.init()` during the parent's init.
/// 3. Forwarding relevant messages via `component.update`.
/// 4. Embedding `component.view` output into the parent's view string.
pub(all) struct Component[Model, Msg] {
  /// Create the initial model and optional command.
  init : () -> @pippa.UpdateResult[Model, Msg]
  /// Handle a message and produce the next state.
  update : (Model, Msg) -> @pippa.UpdateResult[Model, Msg]
  /// Render the current model to an ANSI string.
  view : (Model) -> String
} derive(Debug)
