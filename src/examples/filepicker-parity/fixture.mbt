///|
/// Bubble Tea filepicker parity fixture: stable metadata rows and navigation
/// without depending on the checkout's live directory listing.

///|
pub(all) struct Model {
  picker : @component.FilepickerModel
  quitting : Bool
} derive(Debug)

///|
pub(all) enum Msg {
  PickerMsg(@component.FilepickerMsg)
  Quit
} derive(Debug)

///|
let filepicker_parity_component : @component.Component[
  @component.FilepickerModel,
  @component.FilepickerMsg,
] = @component.filepicker(
  current_directory=".",
  height=4,
  show_permissions=true,
  show_size=true,
  allow_files=true,
  allow_directories=true,
  cursor="> ",
)

///|
fn filepicker_parity_entry(
  name : String,
  path : String,
  is_dir : Bool,
  permissions : String,
  size : Int,
  hidden? : Bool = false,
  is_symlink? : Bool = false,
) -> @component.FileEntry {
  { name, path, is_dir, is_symlink, permissions, size, hidden, disabled: false }
}

///|
fn filepicker_parity_entries() -> Array[@component.FileEntry] {
  [
    filepicker_parity_entry("src", "./src", true, "drwxr-xr-x", 4096),
    filepicker_parity_entry("notes.md", "./notes.md", false, "-rw-r--r--", 42),
    filepicker_parity_entry(
      ".env",
      "./.env",
      false,
      "-rw-------",
      7,
      hidden=true,
    ),
    filepicker_parity_entry(
      "current",
      "./current",
      false,
      "lrwxrwxrwx",
      3,
      is_symlink=true,
    ),
  ]
}

///|
pub fn filepicker_parity_seeded_model() -> Model {
  let base = (filepicker_parity_component.init)().model
  {
    picker: {
      ..base,
      current_directory: ".",
      entries: filepicker_parity_entries(),
      loading: false,
      scan_handle: None,
      show_hidden: false,
      min_index: 0,
      max_index: 3,
    },
    quitting: false,
  }
}

///|
pub fn filepicker_parity_init() -> @pippa.UpdateResult[Model, Msg] {
  @pippa.UpdateResult::new(
    model=filepicker_parity_seeded_model(),
    cmd=@pippa.Cmd::none(),
  )
}

///|
pub fn filepicker_parity_update(
  model : Model,
  msg : Msg,
) -> @pippa.UpdateResult[Model, Msg] {
  match msg {
    PickerMsg(picker_msg) => {
      let result = (filepicker_parity_component.update)(
        model.picker,
        picker_msg,
      )
      @pippa.UpdateResult::new(
        model={ ..model, picker: result.model },
        cmd=@pippa.Cmd::map(fn(m) { PickerMsg(m) }, result.cmd),
      )
    }
    Quit =>
      @pippa.UpdateResult::new(
        model={ ..model, quitting: true },
        cmd=@pippa.Cmd::none(),
      )
  }
}

///|
pub fn filepicker_parity_sub(event : @pippa.InputEvent) -> Msg? {
  match @component.filepicker_msg_from_input_event(event) {
    Some(msg) => Some(PickerMsg(msg))
    None =>
      match event {
        @pippa.Key(@pippa.Char('q'))
        | @pippa.Key(@pippa.Modified("ctrl", "c")) => Some(Quit)
        _ => None
      }
  }
}

///|
pub fn filepicker_parity_view(model : Model) -> String {
  if model.quitting {
    return "Goodbye\n"
  }
  (filepicker_parity_component.view)(model.picker)
}
