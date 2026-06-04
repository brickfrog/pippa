///|
/// Elm-native form machinery for composing input groups into a larger Pippa app.
///
/// The core validator hook is deliberately pure:
/// `(FieldValue, FormValues) -> Result[Unit, Array[ValidationError]]`.
/// Async validation is expected to live in the parent app: react to
/// `FormEvent::Changed` or `FormMsg::Validate`, start an app-owned `Cmd`, and
/// route the eventual result back through app messages. That keeps this package
/// deterministic while leaving room for a later async-validation message shape.

///|
pub(all) enum FieldId {
  FieldId(String)
} derive(Eq, Hash, Debug)

///|
pub impl Show for FieldId with fn output(self, logger) {
  match self {
    FieldId(value) => logger.write_string("FieldId(\{value})")
  }
}

///|
pub fn FieldId::value(self : FieldId) -> String {
  match self {
    FieldId(value) => value
  }
}

///|
pub(all) enum FieldValue {
  Text(String)
  Bool(Bool)
  One(String)
  Empty
} derive(Eq, Debug)

///|
pub(all) struct FormValues {
  values : Map[FieldId, FieldValue]
} derive(Debug)

///|
pub fn FormValues::new() -> FormValues {
  { values: Map([]) }
}

///|
pub fn FormValues::from_pairs(
  pairs : Array[(FieldId, FieldValue)],
) -> FormValues {
  let values : Map[FieldId, FieldValue] = Map([])
  for pair in pairs {
    let (id, value) = pair
    values.set(id, value)
  }
  { values, }
}

///|
pub fn FormValues::set(
  self : FormValues,
  id : FieldId,
  value : FieldValue,
) -> FormValues {
  let values = self.values.copy()
  values.set(id, value)
  { values, }
}

///|
pub fn FormValues::get(self : FormValues, id : FieldId) -> FieldValue {
  match self.values.get(id) {
    Some(value) => value
    None => Empty
  }
}

///|
pub fn FormValues::required_text(
  self : FormValues,
  id : FieldId,
) -> Result[String, Array[ValidationError]] {
  match self.get(id) {
    Text(value) if value != "" => Ok(value)
    _ =>
      Err([
        ValidationError::{
          field: Some(id),
          message: "Required",
          severity: Error,
        },
      ])
  }
}

///|
pub fn FormValues::one(self : FormValues, id : FieldId) -> String? {
  match self.get(id) {
    One(value) if value != "" => Some(value)
    _ => None
  }
}

///|
pub fn FormValues::bool_or(
  self : FormValues,
  id : FieldId,
  fallback : Bool,
) -> Bool {
  match self.get(id) {
    Bool(value) => value
    _ => fallback
  }
}

///|
pub(all) enum Severity {
  Info
  Warning
  Error
} derive(Eq, Debug)

///|
pub(all) struct ValidationError {
  field : FieldId?
  message : String
  severity : Severity
} derive(Eq, Debug)

///|
pub fn ValidationError::new(
  field? : FieldId? = None,
  message~ : String,
  severity? : Severity = Error,
) -> ValidationError {
  { field, message, severity }
}

///|
pub(all) enum ValidationState {
  Untouched
  Dirty
  Valid
  Invalid(Array[ValidationError])
} derive(Eq, Debug)

///|
pub(all) struct FieldValidator {
  validate : (FieldValue, FormValues) -> Result[Unit, Array[ValidationError]]
}

///|
pub fn FieldValidator::run(
  self : FieldValidator,
  value : FieldValue,
  values : FormValues,
) -> Result[Unit, Array[ValidationError]] {
  (self.validate)(value, values)
}

///|
pub(all) struct Validators {} derive(Debug, Eq)

///|
pub fn Validators::required() -> FieldValidator {
  {
    validate: fn(value, _values) {
      match value {
        Text(text) if text != "" => Ok(())
        One(choice) if choice != "" => Ok(())
        Bool(true) => Ok(())
        _ => Err([ValidationError::new(message="Required")])
      }
    },
  }
}

///|
pub fn Validators::matches(other : FieldId, message : String) -> FieldValidator {
  {
    validate: fn(value, values) {
      match (value, values.get(other)) {
        (Text(left), Text(right)) if left == right => Ok(())
        (One(left), One(right)) if left == right => Ok(())
        (Bool(left), Bool(right)) if left == right => Ok(())
        (Empty, Empty) => Ok(())
        _ => Err([ValidationError::new(message~)])
      }
    },
  }
}

///|
pub(all) enum ValidateOn {
  Change
  Blur
  Submit
} derive(Eq, Debug)

///|
pub(all) struct FormDecoder[A] {
  decode : (FormValues) -> Result[A, Array[ValidationError]]
}

///|
pub fn[A] FormDecoder::new(
  decode~ : (FormValues) -> Result[A, Array[ValidationError]],
) -> FormDecoder[A] {
  { decode, }
}

///|
pub fn[A] FormDecoder::run(
  self : FormDecoder[A],
  values : FormValues,
) -> Result[A, Array[ValidationError]] {
  (self.decode)(values)
}

///|
pub(all) enum FieldKind {
  Text(@component.TextInputModel)
  Password(@component.TextInputModel)
  Select(@component.SelectListModel)
  Confirm(Bool)
} derive(Debug)

///|
pub(all) struct FieldSpec {
  id : FieldId
  label : String
  help : String?
  kind : FieldKind
  validators : Array[FieldValidator]
  disabled : Bool
  visible : (FormValues) -> Bool
}

///|
pub(all) struct Field {
  id : FieldId
  label : String
  help : String?
  kind : FieldKind
  validators : Array[FieldValidator]
  disabled : Bool
  visible : (FormValues) -> Bool
  validation : ValidationState
}

///|
fn field_help(value : String) -> String? {
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
fn field_visible_default(_values : FormValues) -> Bool {
  true
}

///|
fn text_input_model(
  placeholder~ : String,
  prompt~ : String,
  width~ : Int,
  echo_mode~ : @component.TextInputEchoMode,
  char_limit~ : Int?,
  disabled~ : Bool,
) -> @component.TextInputModel {
  let component = @component.text_input(
    placeholder~,
    prompt~,
    width~,
    echo_mode~,
    char_limit~,
    disabled~,
  )
  let model = (component.init)().model
  { ..model, focused: false }
}

///|
pub fn Field::text(
  id~ : FieldId,
  label~ : String,
  help? : String = "",
  validators? : Array[FieldValidator] = [],
  disabled? : Bool = false,
  visible? : (FormValues) -> Bool = field_visible_default,
  placeholder? : String = "",
  prompt? : String = "",
  width? : Int = 0,
  char_limit? : Int? = None,
) -> Field {
  {
    id,
    label,
    help: field_help(help),
    kind: Text(
      text_input_model(
        placeholder~,
        prompt~,
        width~,
        echo_mode=@component.Normal,
        char_limit~,
        disabled~,
      ),
    ),
    validators,
    disabled,
    visible,
    validation: Untouched,
  }
}

///|
pub fn Field::password(
  id~ : FieldId,
  label~ : String,
  help? : String = "",
  validators? : Array[FieldValidator] = [],
  disabled? : Bool = false,
  visible? : (FormValues) -> Bool = field_visible_default,
  placeholder? : String = "",
  prompt? : String = "",
  width? : Int = 0,
  char_limit? : Int? = None,
  mask? : Char = '*',
) -> Field {
  {
    id,
    label,
    help: field_help(help),
    kind: Password(
      text_input_model(
        placeholder~,
        prompt~,
        width~,
        echo_mode=@component.Password(mask),
        char_limit~,
        disabled~,
      ),
    ),
    validators,
    disabled,
    visible,
    validation: Untouched,
  }
}

///|
pub fn Field::select(
  id~ : FieldId,
  label~ : String,
  options~ : Array[String],
  help? : String = "",
  validators? : Array[FieldValidator] = [],
  disabled? : Bool = false,
  visible? : (FormValues) -> Bool = field_visible_default,
) -> Field {
  let component = @component.select_list(items=options)
  {
    id,
    label,
    help: field_help(help),
    kind: Select((component.init)().model),
    validators,
    disabled,
    visible,
    validation: Untouched,
  }
}

///|
pub fn Field::confirm(
  id~ : FieldId,
  label~ : String,
  help? : String = "",
  validators? : Array[FieldValidator] = [],
  disabled? : Bool = false,
  visible? : (FormValues) -> Bool = field_visible_default,
  initial? : Bool = false,
) -> Field {
  {
    id,
    label,
    help: field_help(help),
    kind: Confirm(initial),
    validators,
    disabled,
    visible,
    validation: Untouched,
  }
}

///|
pub fn Field::to_spec(self : Field) -> FieldSpec {
  {
    id: self.id,
    label: self.label,
    help: self.help,
    kind: self.kind,
    validators: self.validators,
    disabled: self.disabled,
    visible: self.visible,
  }
}

///|
fn field_kind_from_spec(kind : FieldKind, disabled : Bool) -> FieldKind {
  match kind {
    Text(model) => FieldKind::Text({ ..model, disabled, focused: false })
    Password(model) =>
      FieldKind::Password({ ..model, disabled, focused: false })
    Select(model) => FieldKind::Select(model)
    Confirm(value) => FieldKind::Confirm(value)
  }
}

///|
pub fn Field::from_spec(spec : FieldSpec) -> Field {
  {
    id: spec.id,
    label: spec.label,
    help: spec.help,
    kind: field_kind_from_spec(spec.kind, spec.disabled),
    validators: spec.validators,
    disabled: spec.disabled,
    visible: spec.visible,
    validation: Untouched,
  }
}

///|
pub fn Field::value(self : Field) -> FieldValue {
  match self.kind {
    Text(model) => Text(model.value)
    Password(model) => Text(model.value)
    Select(model) =>
      if model.selected >= 0 && model.selected < model.items.length() {
        One(model.items[model.selected])
      } else {
        Empty
      }
    Confirm(value) => Bool(value)
  }
}

///|
fn field_is_visible(field : Field, values : FormValues) -> Bool {
  (field.visible)(values)
}

///|
fn field_is_focusable(field : Field, values : FormValues) -> Bool {
  field_is_visible(field, values) && !field.disabled
}

///|
fn field_with_validation(field : Field, validation : ValidationState) -> Field {
  { ..field, validation, }
}

///|
fn field_error_for_current_id(
  id : FieldId,
  error : ValidationError,
) -> ValidationError {
  match error.field {
    Some(_) => error
    None => { ..error, field: Some(id) }
  }
}

///|
fn field_normalize_errors(
  id : FieldId,
  errors : Array[ValidationError],
) -> Array[ValidationError] {
  let normalized : Array[ValidationError] = []
  for error in errors {
    normalized.push(field_error_for_current_id(id, error))
  }
  normalized
}

///|
fn field_validate(
  field : Field,
  values : FormValues,
) -> (Field, Array[ValidationError]) {
  if !field_is_visible(field, values) || field.disabled {
    return (field_with_validation(field, Valid), [])
  }
  let errors : Array[ValidationError] = []
  let value = field.value()
  for validator in field.validators {
    match validator.run(value, values) {
      Ok(_) => ()
      Err(next_errors) =>
        for error in field_normalize_errors(field.id, next_errors) {
          errors.push(error)
        }
    }
  }
  if errors.is_empty() {
    (field_with_validation(field, Valid), [])
  } else {
    (field_with_validation(field, Invalid(errors)), errors)
  }
}

///|
fn select_index_for_value(items : Array[String], value : String) -> Int {
  let mut found = -1
  for i, item in items {
    if found == -1 && item == value {
      found = i
    }
  }
  found
}

///|
fn text_model_with_value(
  model : @component.TextInputModel,
  value : String,
) -> @component.TextInputModel {
  { ..model, value, cursor: value.length(), focused: false }
}

///|
fn field_set_value(field : Field, value : FieldValue) -> Field {
  let next_kind = match (field.kind, value) {
    (Text(model), Text(value)) =>
      FieldKind::Text(text_model_with_value(model, value))
    (Text(model), Empty) => FieldKind::Text(text_model_with_value(model, ""))
    (Password(model), Text(value)) =>
      Password(text_model_with_value(model, value))
    (Password(model), Empty) => Password(text_model_with_value(model, ""))
    (Select(model), One(value)) => {
      let selected = select_index_for_value(model.items, value)
      Select({ ..model, cursor: selected.max(0), selected })
    }
    (Select(model), Empty) => Select({ ..model, cursor: 0, selected: -1 })
    (Confirm(_), Bool(value)) => Confirm(value)
    (kind, _) => kind
  }
  { ..field, kind: next_kind, validation: Dirty }
}

///|
pub(all) enum FieldMsg {
  TextInput(@component.TextInputMsg)
  SelectList(@component.SelectListMsg)
  ToggleConfirm
  SetConfirm(Bool)
  SetValue(FieldValue)
} derive(Debug)

///|
fn field_msg_from_key(field : Field, event : @pippa.InputEvent) -> FieldMsg? {
  match field.kind {
    Text(_) | Password(_) =>
      Some(TextInput(@component.TextInputMsg::HandleInput(event)))
    Select(_) =>
      match event {
        @pippa.Key(@pippa.Special("up")) =>
          Some(SelectList(@component.SelectListMsg::CursorUp))
        @pippa.Key(@pippa.Special("down")) =>
          Some(SelectList(@component.SelectListMsg::CursorDown))
        @pippa.Key(@pippa.Special("enter")) =>
          Some(SelectList(@component.SelectListMsg::Select))
        _ => None
      }
    Confirm(_) =>
      match event {
        @pippa.Key(@pippa.Special("enter")) => Some(ToggleConfirm)
        @pippa.Key(@pippa.Char(' ')) => Some(ToggleConfirm)
        _ => None
      }
  }
}

///|
fn field_text_component(
  model : @component.TextInputModel,
) -> @component.Component[@component.TextInputModel, @component.TextInputMsg] {
  @component.text_input(
    placeholder=model.placeholder,
    prompt=model.prompt,
    width=model.width,
    echo_mode=model.echo_mode,
    char_limit=model.char_limit,
    suggestions=model.suggestions.items,
    disabled=model.disabled,
  )
}

///|
fn field_update(field : Field, msg : FieldMsg) -> (Field, @pippa.Cmd[FieldMsg]) {
  if field.disabled {
    return (field, @pippa.Cmd::none())
  }
  match (field.kind, msg) {
    (Text(model), TextInput(input_msg)) => {
      let component = field_text_component(model)
      let result = (component.update)(model, input_msg)
      (
        {
          ..field,
          kind: Text({ ..result.model, focused: false }),
          validation: Dirty,
        },
        @pippa.Cmd::map(fn(next) { TextInput(next) }, result.cmd),
      )
    }
    (Password(model), TextInput(input_msg)) => {
      let component = field_text_component(model)
      let result = (component.update)(model, input_msg)
      (
        {
          ..field,
          kind: Password({ ..result.model, focused: false }),
          validation: Dirty,
        },
        @pippa.Cmd::map(fn(next) { TextInput(next) }, result.cmd),
      )
    }
    (Select(model), SelectList(select_msg)) => {
      let component = @component.select_list(items=model.items)
      let result = (component.update)(model, select_msg)
      (
        { ..field, kind: Select(result.model), validation: Dirty },
        @pippa.Cmd::map(fn(next) { SelectList(next) }, result.cmd),
      )
    }
    (Confirm(value), ToggleConfirm) =>
      (
        { ..field, kind: Confirm(!value), validation: Dirty },
        @pippa.Cmd::none(),
      )
    (Confirm(_), SetConfirm(value)) =>
      ({ ..field, kind: Confirm(value), validation: Dirty }, @pippa.Cmd::none())
    (_, SetValue(value)) => (field_set_value(field, value), @pippa.Cmd::none())
    _ => (field, @pippa.Cmd::none())
  }
}

///|
pub(all) struct FocusRing {
  order : Array[FieldId]
  index : Int
} derive(Eq, Debug)

///|
pub fn FocusRing::new(order~ : Array[FieldId]) -> FocusRing {
  { order, index: 0 }
}

///|
fn find_field(fields : Array[Field], id : FieldId) -> Field? {
  for field in fields {
    if field.id == id {
      return Some(field)
    }
  }
  None
}

///|
fn focus_ring_has_focusable_at(
  ring : FocusRing,
  index : Int,
  fields : Array[Field],
  values : FormValues,
) -> Bool {
  if index < 0 || index >= ring.order.length() {
    return false
  }
  match find_field(fields, ring.order[index]) {
    Some(field) => field_is_focusable(field, values)
    None => false
  }
}

///|
fn focus_ring_index_of(ring : FocusRing, id : FieldId) -> Int? {
  for i, current in ring.order {
    if current == id {
      return Some(i)
    }
  }
  None
}

///|
fn focus_ring_normalized_start(ring : FocusRing) -> Int {
  let count = ring.order.length()
  if count == 0 {
    0
  } else if ring.index < 0 {
    0
  } else if ring.index >= count {
    count - 1
  } else {
    ring.index
  }
}

///|
fn focus_ring_current_index(
  ring : FocusRing,
  fields : Array[Field],
  values : FormValues,
) -> Int? {
  let count = ring.order.length()
  if count == 0 {
    return None
  }
  let start = focus_ring_normalized_start(ring)
  for offset in 0..<count {
    let index = (start + offset) % count
    if focus_ring_has_focusable_at(ring, index, fields, values) {
      return Some(index)
    }
  }
  None
}

///|
pub fn FocusRing::current(
  self : FocusRing,
  fields : Array[Field],
  values : FormValues,
) -> FieldId? {
  match focus_ring_current_index(self, fields, values) {
    Some(index) => Some(self.order[index])
    None => None
  }
}

///|
pub fn FocusRing::next(
  self : FocusRing,
  fields : Array[Field],
  values : FormValues,
) -> FocusRing {
  let count = self.order.length()
  if count == 0 {
    return self
  }
  let start = match focus_ring_current_index(self, fields, values) {
    Some(index) => index
    None => focus_ring_normalized_start(self)
  }
  for step in 1..<(count + 1) {
    let index = (start + step) % count
    if focus_ring_has_focusable_at(self, index, fields, values) {
      return { ..self, index, }
    }
  }
  self
}

///|
pub fn FocusRing::prev(
  self : FocusRing,
  fields : Array[Field],
  values : FormValues,
) -> FocusRing {
  let count = self.order.length()
  if count == 0 {
    return self
  }
  let start = match focus_ring_current_index(self, fields, values) {
    Some(index) => index
    None => focus_ring_normalized_start(self)
  }
  for step in 1..<(count + 1) {
    let index = (start + count - step % count) % count
    if focus_ring_has_focusable_at(self, index, fields, values) {
      return { ..self, index, }
    }
  }
  self
}

///|
pub fn FocusRing::focus(
  self : FocusRing,
  id : FieldId,
  fields : Array[Field],
  values : FormValues,
) -> FocusRing {
  match focus_ring_index_of(self, id) {
    Some(index) if focus_ring_has_focusable_at(self, index, fields, values) =>
      { ..self, index, }
    _ => self
  }
}

///|
pub(all) enum FormStatus[A] {
  Editing
  Submitted(A)
  Blocked(Array[ValidationError])
} derive(Debug)

///|
pub(all) enum FormEvent[A] {
  None
  Changed(FieldId, FieldValue)
  Submitted(A)
  Cancelled
} derive(Debug)

///|
pub(all) enum FormMsg {
  Key(@pippa.InputEvent)
  FocusNext
  FocusPrev
  Focus(FieldId)
  Field(FieldId, FieldMsg)
  Validate(FieldId?)
  Submit
  Reset
} derive(Debug)

///|
pub(all) struct Form[A] {
  fields : Array[Field]
  focus : FocusRing
  values : FormValues
  validate_on : ValidateOn
  decode : (FormValues) -> Result[A, Array[ValidationError]]
  status : FormStatus[A]
}

///|
fn form_values_from_fields(fields : Array[Field]) -> FormValues {
  let mut values = FormValues::new()
  for field in fields {
    values = values.set(field.id, field.value())
  }
  values
}

///|
pub fn[A] Form::new(
  fields~ : Array[Field],
  decode~ : (FormValues) -> Result[A, Array[ValidationError]],
  validate_on? : ValidateOn = Submit,
) -> Form[A] {
  let order : Array[FieldId] = []
  for field in fields {
    order.push(field.id)
  }
  {
    fields,
    focus: FocusRing::new(order~),
    values: form_values_from_fields(fields),
    validate_on,
    decode,
    status: Editing,
  }
}

///|
pub fn[A] Form::with_validate_on(
  self : Form[A],
  validate_on : ValidateOn,
) -> Form[A] {
  { ..self, validate_on, }
}

///|
pub fn[A] Form::focused_id(self : Form[A]) -> FieldId? {
  self.focus.current(self.fields, self.values)
}

///|
fn form_replace_field(fields : Array[Field], next : Field) -> Array[Field] {
  let out : Array[Field] = []
  for field in fields {
    if field.id == next.id {
      out.push(next)
    } else {
      out.push(field)
    }
  }
  out
}

///|
fn form_validate_field_by_id(
  fields : Array[Field],
  values : FormValues,
  id : FieldId,
) -> (Array[Field], Array[ValidationError]) {
  let out : Array[Field] = []
  let errors : Array[ValidationError] = []
  for field in fields {
    if field.id == id {
      let (validated, field_errors) = field_validate(field, values)
      out.push(validated)
      for error in field_errors {
        errors.push(error)
      }
    } else {
      out.push(field)
    }
  }
  (out, errors)
}

///|
fn form_validate_all(
  fields : Array[Field],
  values : FormValues,
) -> (Array[Field], Array[ValidationError]) {
  let out : Array[Field] = []
  let errors : Array[ValidationError] = []
  for field in fields {
    let (validated, field_errors) = field_validate(field, values)
    out.push(validated)
    for error in field_errors {
      errors.push(error)
    }
  }
  (out, errors)
}

///|
fn errors_for_field(
  errors : Array[ValidationError],
  id : FieldId,
) -> Array[ValidationError] {
  let out : Array[ValidationError] = []
  for error in errors {
    if error.field == Some(id) {
      out.push(error)
    }
  }
  out
}

///|
fn form_apply_errors_to_fields(
  fields : Array[Field],
  errors : Array[ValidationError],
) -> Array[Field] {
  let out : Array[Field] = []
  for field in fields {
    let field_errors = errors_for_field(errors, field.id)
    if field_errors.is_empty() {
      out.push(field)
    } else {
      out.push(field_with_validation(field, Invalid(field_errors)))
    }
  }
  out
}

///|
fn form_merge_errors(
  left : Array[ValidationError],
  right : Array[ValidationError],
) -> Array[ValidationError] {
  let merged : Array[ValidationError] = []
  for error in left {
    merged.push(error)
  }
  for error in right {
    merged.push(error)
  }
  merged
}

///|
fn form_reset_fields(fields : Array[Field]) -> Array[Field] {
  let out : Array[Field] = []
  for field in fields {
    let reset = match field.kind {
      Text(model) => { ..field, kind: Text(text_model_with_value(model, "")) }
      Password(model) =>
        { ..field, kind: Password(text_model_with_value(model, "")) }
      Select(model) =>
        { ..field, kind: Select({ ..model, cursor: 0, selected: -1 }) }
      Confirm(_) => { ..field, kind: Confirm(false) }
    }
    out.push({ ..reset, validation: Untouched })
  }
  out
}

///|
fn[A] form_status_after_validation(
  status : FormStatus[A],
  errors : Array[ValidationError],
) -> FormStatus[A] {
  if errors.is_empty() {
    status
  } else {
    Blocked(errors)
  }
}

///|
fn form_key_is_focus_next(event : @pippa.InputEvent) -> Bool {
  match event {
    @pippa.Key(@pippa.Special("tab")) => true
    _ => false
  }
}

///|
fn form_key_is_focus_prev(event : @pippa.InputEvent) -> Bool {
  match event {
    @pippa.Key(@pippa.Modified("shift", "tab")) => true
    _ => false
  }
}

///|
fn form_key_is_cancel(event : @pippa.InputEvent) -> Bool {
  match event {
    @pippa.Key(@pippa.Special("escape")) => true
    _ => false
  }
}

///|
fn[A] form_update_focus(
  form : Form[A],
  next_focus : FocusRing,
) -> (Form[A], @pippa.Cmd[FormMsg], FormEvent[A]) {
  let (fields, errors) = match form.validate_on {
    Blur =>
      match form.focused_id() {
        Some(id) => form_validate_field_by_id(form.fields, form.values, id)
        None => (form.fields, [])
      }
    _ => (form.fields, [])
  }
  (
    {
      ..form,
      fields,
      focus: next_focus,
      status: form_status_after_validation(Editing, errors),
    },
    @pippa.Cmd::none(),
    None,
  )
}

///|
fn[A] form_update_field(
  form : Form[A],
  id : FieldId,
  msg : FieldMsg,
) -> (Form[A], @pippa.Cmd[FormMsg], FormEvent[A]) {
  match find_field(form.fields, id) {
    None => (form, @pippa.Cmd::none(), None)
    Some(field) => {
      if !field_is_visible(field, form.values) || field.disabled {
        return (form, @pippa.Cmd::none(), None)
      }
      let before_value = field.value()
      let (updated, field_cmd) = field_update(field, msg)
      let fields = form_replace_field(form.fields, updated)
      let updated_value = updated.value()
      let values = form.values.set(id, updated_value)
      let changed = updated_value != before_value
      let (fields, errors) = if form.validate_on == Change && changed {
        form_validate_field_by_id(fields, values, id)
      } else {
        (fields, [])
      }
      let event = if changed { Changed(id, updated_value) } else { None }
      (
        {
          ..form,
          fields,
          values,
          status: form_status_after_validation(Editing, errors),
        },
        @pippa.Cmd::map(fn(next) { Field(id, next) }, field_cmd),
        event,
      )
    }
  }
}

///|
pub fn[A] Form::update(
  self : Form[A],
  msg : FormMsg,
) -> (Form[A], @pippa.Cmd[FormMsg], FormEvent[A]) {
  match msg {
    Key(event) => {
      if form_key_is_cancel(event) {
        return ({ ..self, status: Editing }, @pippa.Cmd::none(), Cancelled)
      }
      if form_key_is_focus_next(event) {
        return self.update(FocusNext)
      }
      if form_key_is_focus_prev(event) {
        return self.update(FocusPrev)
      }
      match self.focused_id() {
        Some(id) =>
          match find_field(self.fields, id) {
            Some(field) =>
              match field_msg_from_key(field, event) {
                Some(field_msg) => self.update(Field(id, field_msg))
                None => (self, @pippa.Cmd::none(), None)
              }
            None => (self, @pippa.Cmd::none(), None)
          }
        None => (self, @pippa.Cmd::none(), None)
      }
    }
    FocusNext =>
      form_update_focus(self, self.focus.next(self.fields, self.values))
    FocusPrev =>
      form_update_focus(self, self.focus.prev(self.fields, self.values))
    Focus(id) =>
      form_update_focus(self, self.focus.focus(id, self.fields, self.values))
    Field(id, field_msg) => form_update_field(self, id, field_msg)
    Validate(Some(id)) => {
      let (fields, errors) = form_validate_field_by_id(
        self.fields,
        self.values,
        id,
      )
      (
        {
          ..self,
          fields,
          status: form_status_after_validation(Editing, errors),
        },
        @pippa.Cmd::none(),
        None,
      )
    }
    Validate(None) => {
      let (fields, errors) = form_validate_all(self.fields, self.values)
      (
        {
          ..self,
          fields,
          status: form_status_after_validation(Editing, errors),
        },
        @pippa.Cmd::none(),
        None,
      )
    }
    Submit => {
      let (validated_fields, validation_errors) = form_validate_all(
        self.fields,
        self.values,
      )
      match (self.decode)(self.values) {
        Ok(decoded) =>
          if validation_errors.is_empty() {
            (
              { ..self, fields: validated_fields, status: Submitted(decoded) },
              @pippa.Cmd::none(),
              Submitted(decoded),
            )
          } else {
            (
              {
                ..self,
                fields: form_apply_errors_to_fields(
                  validated_fields, validation_errors,
                ),
                status: Blocked(validation_errors),
              },
              @pippa.Cmd::none(),
              None,
            )
          }
        Err(errors) => {
          let merged = form_merge_errors(validation_errors, errors)
          (
            {
              ..self,
              fields: form_apply_errors_to_fields(validated_fields, merged),
              status: Blocked(merged),
            },
            @pippa.Cmd::none(),
            None,
          )
        }
      }
    }
    Reset => {
      let fields = form_reset_fields(self.fields)
      let values = form_values_from_fields(fields)
      (
        {
          ..self,
          fields,
          focus: FocusRing::new(order=self.focus.order),
          values,
          status: Editing,
        },
        @pippa.Cmd::none(),
        None,
      )
    }
  }
}

///|
fn field_validation_errors(field : Field) -> Array[ValidationError] {
  match field.validation {
    Invalid(errors) => errors
    _ => []
  }
}

///|
fn[A] form_fieldless_errors(status : FormStatus[A]) -> Array[ValidationError] {
  let out : Array[ValidationError] = []
  match status {
    Blocked(errors) =>
      for error in errors {
        if error.field is None {
          out.push(error)
        }
      }
    _ => ()
  }
  out
}

///|
fn form_validation_role(error : ValidationError) -> @theme.RoleKey {
  match error.severity {
    Info => @theme.RoleKey::form("validation.info")
    Warning => @theme.RoleKey::form("validation.warning")
    Error => @theme.RoleKey::form("validation.error")
  }
}

///|
fn field_control_view(field : Field, focused : Bool) -> String {
  match field.kind {
    Text(model) => {
      let component = field_text_component(model)
      (component.view)({ ..model, focused, disabled: field.disabled })
    }
    Password(model) => {
      let component = field_text_component(model)
      (component.view)({ ..model, focused, disabled: field.disabled })
    }
    Select(model) => {
      let component = @component.select_list(items=model.items)
      (component.view)(model)
    }
    Confirm(value) => {
      let mark = if value { "x" } else { " " }
      "[\{mark}]"
    }
  }
}

///|
fn form_render_field(
  field : Field,
  focused : Bool,
  theme : @theme.Theme,
  ctx : @profile.RenderContext,
) -> String {
  let lines : Array[String] = []
  lines.push(theme.render(@theme.RoleKey::form("label"), field.label, ctx))
  match field.help {
    Some(help) =>
      lines.push(theme.render(@theme.RoleKey::form("help"), help, ctx))
    None => ()
  }
  let control = field_control_view(field, focused)
  lines.push(
    if focused {
      theme.render(@theme.RoleKey::ui("focus"), control, ctx)
    } else {
      control
    },
  )
  for error in field_validation_errors(field) {
    lines.push(theme.render(form_validation_role(error), error.message, ctx))
  }
  lines.join("\n")
}

///|
fn form_render_fieldless_errors(
  errors : Array[ValidationError],
  theme : @theme.Theme,
  ctx : @profile.RenderContext,
) -> String? {
  if errors.is_empty() {
    return None
  }
  let lines : Array[String] = []
  for error in errors {
    lines.push(
      theme.render(@theme.RoleKey::form("validation.error"), error.message, ctx),
    )
  }
  Some(lines.join("\n"))
}

///|
pub fn[A] Form::view(
  self : Form[A],
  theme : @theme.Theme,
  ctx : @profile.RenderContext,
) -> String {
  let focused = self.focused_id()
  let blocks : Array[String] = []
  match
    form_render_fieldless_errors(form_fieldless_errors(self.status), theme, ctx) {
    Some(summary) => blocks.push(summary)
    None => ()
  }
  for field in self.fields {
    if field_is_visible(field, self.values) {
      blocks.push(
        form_render_field(field, focused == Some(field.id), theme, ctx),
      )
    }
  }
  blocks.join("\n\n")
}
