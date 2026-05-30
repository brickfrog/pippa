///|
/// Tests for the TextInput component.

///|
fn text_input_test_model(
  value~ : String,
  cursor~ : Int,
  focused~ : Bool,
) -> TextInputModel {
  {
    value,
    cursor,
    width: 0,
    scroll_col: 0,
    prompt: "",
    placeholder: "",
    echo_mode: Normal,
    char_limit: None,
    validation: Valid,
    focused,
    disabled: false,
  }
}

///|
test "text_input: insert char into empty field" {
  let comp = text_input(placeholder="hint")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('a')).model
  assert_eq(m1.value, "a")
  assert_eq(m1.cursor, 1)
}

///|
test "text_input: insert multiple chars" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('h')).model
  let m2 = (comp.update)(m1, InsertChar('i')).model
  assert_eq(m2.value, "hi")
  assert_eq(m2.cursor, 2)
}

///|
test "text_input: insert char in the middle" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('a')).model
  let m2 = (comp.update)(m1, InsertChar('c')).model
  // Move to position 1 (between 'a' and 'c') then insert 'b'
  let m3 = (comp.update)(m2, MoveToStart).model
  let m4 = (comp.update)(m3, MoveCursorRight).model
  let m5 = (comp.update)(m4, InsertChar('b')).model
  assert_eq(m5.value, "abc")
  assert_eq(m5.cursor, 2)
}

///|
test "text_input: delete before (backspace) removes char" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('a')).model
  let m2 = (comp.update)(m1, InsertChar('b')).model
  let m3 = (comp.update)(m2, DeleteBefore).model
  assert_eq(m3.value, "a")
  assert_eq(m3.cursor, 1)
}

///|
test "text_input: delete before at start does nothing" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, DeleteBefore).model
  assert_eq(m1.value, "")
  assert_eq(m1.cursor, 0)
}

///|
test "text_input: delete after removes char at cursor" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('a')).model
  let m2 = (comp.update)(m1, InsertChar('b')).model
  // Move to start then delete the 'a'
  let m3 = (comp.update)(m2, MoveToStart).model
  let m4 = (comp.update)(m3, DeleteAfter).model
  assert_eq(m4.value, "b")
  assert_eq(m4.cursor, 0)
}

///|
test "text_input: delete after at end does nothing" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('x')).model
  let m2 = (comp.update)(m1, DeleteAfter).model
  assert_eq(m2.value, "x")
  assert_eq(m2.cursor, 1)
}

///|
test "text_input: cursor movement left and right" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('x')).model
  assert_eq(m1.cursor, 1)
  let m2 = (comp.update)(m1, MoveCursorLeft).model
  assert_eq(m2.cursor, 0)
  // Can't go further left
  let m3 = (comp.update)(m2, MoveCursorLeft).model
  assert_eq(m3.cursor, 0)
  let m4 = (comp.update)(m3, MoveCursorRight).model
  assert_eq(m4.cursor, 1)
  // Can't go further right
  let m5 = (comp.update)(m4, MoveCursorRight).model
  assert_eq(m5.cursor, 1)
}

///|
test "text_input: move to start and end" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('a')).model
  let m2 = (comp.update)(m1, InsertChar('b')).model
  let m3 = (comp.update)(m2, InsertChar('c')).model
  let m4 = (comp.update)(m3, MoveToStart).model
  assert_eq(m4.cursor, 0)
  let m5 = (comp.update)(m4, MoveToEnd).model
  assert_eq(m5.cursor, 3)
}

///|
test "text_input: focus and blur" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  assert_eq(m0.focused, false)
  let m1 = (comp.update)(m0, Focus).model
  assert_eq(m1.focused, true)
  let m2 = (comp.update)(m1, Blur).model
  assert_eq(m2.focused, false)
}

///|
test "text_input: view shows cursor at end when focused" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertChar('a')).model
  let m3 = (comp.update)(m2, InsertChar('b')).model
  assert_eq((comp.view)(m3), "ab|")
}

///|
test "text_input: view shows cursor in the middle when focused" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertChar('a')).model
  let m3 = (comp.update)(m2, InsertChar('b')).model
  let m4 = (comp.update)(m3, MoveCursorLeft).model
  assert_eq((comp.view)(m4), "a|b")
}

///|
test "text_input: view shows cursor at start when focused" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertChar('x')).model
  let m3 = (comp.update)(m2, MoveToStart).model
  assert_eq((comp.view)(m3), "|x")
}

///|
test "text_input: view shows placeholder (dimmed) when empty and unfocused" {
  let comp = text_input(placeholder="type here")
  let m0 = (comp.init)().model
  let v = (comp.view)(m0)
  // Strip ANSI sequences — plain text should be just the placeholder
  assert_eq(@pippa.strip_ansi(v), "type here")
  // Verify exact ANSI styling so regressions in dim/reset codes are caught
  assert_eq(v, "\u{1b}[2mtype here\u{1b}[0m")
}

///|
test "text_input: view shows plain value when unfocused and non-empty" {
  let comp = text_input(placeholder="hint")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertChar('h')).model
  let m2 = (comp.update)(m1, InsertChar('i')).model
  assert_eq((comp.view)(m2), "hi")
}

///|
test "text_input: view shows empty cursor when focused and empty" {
  let comp = text_input(placeholder="hint")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  assert_eq((comp.view)(m1), "|\u{1b}[2mhint\u{1b}[0m")
}

///|
test "text_input: cursor movement stays on grapheme boundaries" {
  let accented = String::from_array(['e', '\u{0301}'])
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value="\{accented}x",
    cursor=3,
    focused=true,
  )
  let m1 = (comp.update)(model, MoveCursorLeft).model
  let m2 = (comp.update)(m1, MoveCursorLeft).model
  assert_eq((comp.view)(m1), "\{accented}|x")
  assert_eq((comp.view)(m2), "|\{accented}x")
}

///|
test "text_input: cursor right steps over base combining cluster once" {
  let accented = String::from_array(['e', '\u{0301}'])
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value="\{accented}x",
    cursor=0,
    focused=true,
  )
  let m1 = (comp.update)(model, MoveCursorRight).model
  let m2 = (comp.update)(m1, MoveCursorRight).model
  assert_eq(m1.cursor, 2)
  assert_eq((comp.view)(m1), "\{accented}|x")
  assert_eq(m2.cursor, 3)
  assert_eq((comp.view)(m2), "\{accented}x|")
}

///|
test "text_input: insert text accepts multi-scalar grapheme clusters" {
  let accented = String::from_array(['e', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertText(accented)).model
  let m2 = (comp.update)(m1, InsertText(technologist)).model
  let moved = (comp.update)(m2, MoveCursorLeft).model
  assert_eq(m1.value, accented)
  assert_eq(m1.cursor, accented.to_array().length())
  assert_eq(m2.value, "\{accented}\{technologist}")
  assert_eq(
    m2.cursor,
    accented.to_array().length() + technologist.to_array().length(),
  )
  assert_eq(moved.cursor, accented.to_array().length())
}

///|
test "text_input: delete before removes a whole grapheme cluster" {
  let accented = String::from_array(['e', '\u{0301}'])
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value="\{accented}x",
    cursor=2,
    focused=true,
  )
  let next = (comp.update)(model, DeleteBefore).model
  assert_eq(next.value, "x")
  assert_eq(next.cursor, 0)
  assert_eq((comp.view)(next), "|x")
}

///|
test "text_input: delete before removes emoji ZWJ cluster as one unit" {
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value="\{technologist}x",
    cursor=technologist.to_array().length(),
    focused=true,
  )
  let next = (comp.update)(model, DeleteBefore).model
  assert_eq(next.value, "x")
  assert_eq(next.cursor, 0)
  assert_eq((comp.view)(next), "|x")
}

///|
test "text_input: delete after removes whole combining and ZWJ clusters" {
  let accented = String::from_array(['e', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value="\{accented}\{technologist}x",
    cursor=0,
    focused=true,
  )
  let m1 = (comp.update)(model, DeleteAfter).model
  let m2 = (comp.update)(m1, DeleteAfter).model
  assert_eq(m1.value, "\{technologist}x")
  assert_eq(m1.cursor, 0)
  assert_eq(m2.value, "x")
  assert_eq(m2.cursor, 0)
  assert_eq((comp.view)(m2), "|x")
}

///|
test "text_input: styled wide glyph is one cursor stop" {
  let styled = "\u001b[31m界\u001b[0m"
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value=styled,
    cursor=styled.to_array().length(),
    focused=true,
  )
  let moved = (comp.update)(model, MoveCursorLeft).model
  assert_eq(moved.cursor, 0)
  assert_true(moved.value == styled)
  assert_true((comp.view)(moved) == "|\u001b[31m界\u001b[0m")
}

///|
test "text_input: deleting styled wide glyph removes reset too" {
  let styled = "\u001b[31m界\u001b[0m"
  let comp = text_input(placeholder="")
  let model = text_input_test_model(
    value=styled,
    cursor=styled.to_array().length(),
    focused=true,
  )
  let next = (comp.update)(model, DeleteBefore).model
  assert_true(next.value == "")
  assert_eq(next.cursor, 0)
}

///|
test "text_input: password echo masks one glyph per grapheme" {
  let accented = String::from_array(['e', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let comp = text_input(placeholder="", echo_mode=Password('*'))
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertText("\{accented}\{technologist}")).model
  assert_eq(m2.value, "\{accented}\{technologist}")
  assert_eq((comp.view)(m2), "**|")
}

///|
test "text_input: hidden echo renders no value while editing real content" {
  let comp = text_input(placeholder="", echo_mode=Hidden)
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertText("secret")).model
  let m3 = (comp.update)(m2, MoveCursorLeft).model
  assert_eq(m3.value, "secret")
  assert_eq(m3.cursor, 5)
  assert_eq((comp.view)(m3), "|")
}

///|
test "text_input: char limit truncates insert text at grapheme boundary" {
  let accented = String::from_array(['e', '\u{0301}'])
  let technologist = String::from_array(['👩', '\u{200D}', '💻'])
  let comp = text_input(placeholder="", char_limit=Some(2))
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertText("\{accented}\{technologist}x")).model
  let m2 = (comp.update)(m1, InsertChar('z')).model
  assert_eq(m1.value, "\{accented}\{technologist}")
  assert_eq(m1.cursor, m1.value.to_array().length())
  assert_eq(m2.value, m1.value)
  assert_eq(m2.cursor, m1.cursor)
}

///|
test "text_input: prompt prefixes placeholder and focused content" {
  let comp = text_input(placeholder="name", prompt="> ")
  let m0 = (comp.init)().model
  assert_eq(@pippa.strip_ansi((comp.view)(m0)), "> name")
  assert_eq((comp.view)(m0), "> \u{1b}[2mname\u{1b}[0m")
  let m1 = (comp.update)(m0, Focus).model
  assert_eq(@pippa.strip_ansi((comp.view)(m1)), "> |name")
  assert_eq(m1.value, "")
  assert_eq(m1.cursor, 0)
  let m2 = (comp.update)(m1, InsertChar('A')).model
  assert_eq((comp.view)(m2), "> A|")
}

///|
test "text_input: viewport scroll keeps cursor visible" {
  let comp = text_input(placeholder="", width=4)
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertText("abcdef")).model
  assert_eq(m2.scroll_col, 3)
  assert_eq((comp.view)(m2), "def|")
}

///|
test "text_input: prompt consumes viewport width" {
  let comp = text_input(placeholder="abcdef", prompt="> ", width=4)
  let m0 = (comp.init)().model
  assert_eq(@pippa.strip_ansi((comp.view)(m0)), "> ab")
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertText("abcdef")).model
  assert_eq(m2.scroll_col, 5)
  assert_eq((comp.view)(m2), "> f|")
}

///|
test "text_input: viewport slice preserves wide glyph cells" {
  let comp = text_input(placeholder="", width=2)
  let model : TextInputModel = {
    value: "你x",
    cursor: 1,
    placeholder: "",
    focused: true,
    width: 2,
    scroll_col: 1,
    prompt: "",
    echo_mode: Normal,
    char_limit: None,
    validation: Valid,
    disabled: false,
  }
  assert_eq((comp.view)(model), " |")
}

///|
test "text_input: validator accepts input and tracks invalid state" {
  let comp = text_input(placeholder="", validator=fn(value) {
    if value == "" || value.contains("@") {
      Ok(())
    } else {
      Err("missing @")
    }
  })
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, InsertText("name")).model
  let m2 = (comp.update)(m1, InsertText("@example")).model
  assert_true(m0.validation is Valid)
  assert_eq(m1.value, "name")
  assert_true(m1.validation is Invalid("missing @"))
  assert_eq(m2.value, "name@example")
  assert_true(m2.validation is Valid)
}

///|
test "text_input: disabled ignores input and blur hides cursor" {
  let comp = text_input(placeholder="")
  let m0 = (comp.init)().model
  let m1 = (comp.update)(m0, Focus).model
  let m2 = (comp.update)(m1, InsertText("ab")).model
  let disabled = { ..m2, disabled: true }
  let ignored_insert = (comp.update)(disabled, InsertChar('c')).model
  let ignored_move = (comp.update)(ignored_insert, MoveCursorLeft).model
  assert_eq(ignored_insert.value, "ab")
  assert_eq(ignored_insert.cursor, 2)
  assert_eq(ignored_move.cursor, 2)
  assert_eq((comp.view)(m2), "ab|")
  let blurred = (comp.update)(m2, Blur).model
  assert_eq((comp.view)(blurred), "ab")
}
