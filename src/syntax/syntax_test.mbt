///|
fn checked_highlight(
  registry : SyntaxRegistry,
  language : String,
  source : String,
) -> Highlighted raise {
  match highlight(registry, language, source) {
    Ok(highlighted) => highlighted
    Err(err) => fail("highlight failed: \{err}")
  }
}

///|
fn assert_covers_all(tokens : Array[TokenSpan], byte_len : Int) -> Unit raise {
  let mut cursor = 0
  for token in tokens {
    assert_eq(token.start_byte, cursor)
    assert_true(token.end_byte > token.start_byte)
    cursor = token.end_byte
  }
  assert_eq(cursor, byte_len)
}

///|
fn has_kind(tokens : Array[TokenSpan], kind : SyntaxKind) -> Bool {
  for token in tokens {
    if token.kind == kind {
      return true
    }
  }
  false
}

///|
fn has_role(spans : Array[@theme.StyledSpan], role : @theme.RoleKey) -> Bool {
  for span in spans {
    if span.role == role {
      return true
    }
  }
  false
}

///|
fn bytes_from_view(view : BytesView) -> Bytes {
  Bytes::from_array(view.to_array())
}

///|
fn token_text(highlighted : Highlighted, token : TokenSpan) -> String {
  let bytes = @utf8.encode(highlighted.source[:])
  @utf8.decode_lossy(bytes_from_view(bytes[token.start_byte:token.end_byte])[:])
}

///|
fn assert_token(
  highlighted : Highlighted,
  index : Int,
  kind : SyntaxKind,
  text : String,
) -> Unit raise {
  let token = highlighted.tokens[index]
  @test.assert_eq(token.kind, kind)
  @test.assert_eq(token_text(highlighted, token), text)
}

///|
test "plain text lexer emits one identity token covering utf8 bytes" {
  let source = "plain é\n"
  let highlighted = checked_highlight(SyntaxRegistry::default(), "text", source)
  @test.assert_eq(highlighted.source, source)
  @test.assert_eq(highlighted.tokens, [
    TokenSpan::{
      start_byte: 0,
      end_byte: @utf8.encode(source[:]).length(),
      kind: Text,
    },
  ])
  @test.assert_eq(
    @theme.span_plain_text(
      highlighted_spans(highlighted, SyntaxTheme::default()),
    ),
    source,
  )
}

///|
test "seed lexers classify representative tokens and preserve coverage" {
  let registry = SyntaxRegistry::default()

  let moon = checked_highlight(
    registry, "moonbit", "fn main() -> Int { true }\n",
  )
  assert_covers_all(moon.tokens, @utf8.encode(moon.source[:]).length())
  assert_eq(moon.tokens.length(), 15)
  assert_token(moon, 0, Keyword, "fn")
  assert_token(moon, 1, Whitespace, " ")
  assert_token(moon, 2, Name(Variable), "main")
  assert_token(moon, 3, Punctuation, "()")
  assert_token(moon, 5, Operator, "->")
  assert_token(moon, 7, Name(Type), "Int")
  assert_token(moon, 11, Literal(Bool), "true")
  assert_true(has_kind(moon.tokens, Keyword))
  assert_true(has_kind(moon.tokens, Name(Type)))
  assert_true(has_kind(moon.tokens, Literal(Bool)))

  let json = checked_highlight(registry, "json", "{\"name\": true, \"n\": 42}")
  assert_covers_all(json.tokens, @utf8.encode(json.source[:]).length())
  assert_eq(json.tokens.length(), 12)
  assert_token(json, 0, Punctuation, "{")
  assert_token(json, 1, Literal(String), "\"name\"")
  assert_token(json, 2, Punctuation, ":")
  assert_token(json, 4, Literal(Bool), "true")
  assert_token(json, 7, Literal(String), "\"n\"")
  assert_token(json, 10, Literal(Number), "42")
  assert_token(json, 11, Punctuation, "}")
  assert_true(has_kind(json.tokens, Literal(String)))
  assert_true(has_kind(json.tokens, Literal(Bool)))
  assert_true(has_kind(json.tokens, Literal(Number)))

  let shell = checked_highlight(
    registry, "sh", "if [ -n \"$HOME\" ]; then echo ok; fi\n",
  )
  assert_covers_all(shell.tokens, @utf8.encode(shell.source[:]).length())
  assert_true(has_kind(shell.tokens, Keyword))
  assert_true(has_kind(shell.tokens, Literal(String)))
  assert_true(has_kind(shell.tokens, Name(Variable)))
  assert_true(!has_kind(shell.tokens, Error))

  let diff = checked_highlight(registry, "diff", "@@ -1 +1 @@\n-old\n+new\n")
  assert_covers_all(diff.tokens, @utf8.encode(diff.source[:]).length())
  assert_true(has_kind(diff.tokens, Keyword))
  assert_true(has_kind(diff.tokens, Error))
  assert_true(has_kind(diff.tokens, Name(Constant)))
}

///|
test "shell lexer preserves exact option tokens including long options" {
  let shell = checked_highlight(
    SyntaxRegistry::default(),
    "sh",
    "grep --line-number --flag=value -n foo file\n",
  )
  assert_covers_all(shell.tokens, @utf8.encode(shell.source[:]).length())
  assert_eq(shell.tokens.length(), 12)
  assert_token(shell, 0, Name(Variable), "grep")
  assert_token(shell, 1, Whitespace, " ")
  assert_token(shell, 2, Name(Attribute), "--line-number")
  assert_token(shell, 3, Whitespace, " ")
  assert_token(shell, 4, Name(Attribute), "--flag=value")
  assert_token(shell, 5, Whitespace, " ")
  assert_token(shell, 6, Name(Attribute), "-n")
  assert_token(shell, 7, Whitespace, " ")
  assert_token(shell, 8, Name(Variable), "foo")
  assert_token(shell, 9, Whitespace, " ")
  assert_token(shell, 10, Name(Variable), "file")
  assert_token(shell, 11, Whitespace, "\n")
}

///|
test "rule lexer covers unmatched bytes as error tokens" {
  let state = StateId::new("main")
  let states : Map[StateId, Array[Rule]] = Map([])
  states.set(state, [Rule::{ pattern: Literal("ok"), action: Emit(Keyword) }])
  let lexer = RuleLexer::{ initial: state, states }
  let registry = SyntaxRegistry::new().with_lexer(["mini"], RuleBased(lexer))
  let highlighted = checked_highlight(registry, "mini", "ok!")
  assert_covers_all(highlighted.tokens, 3)
  assert_true(has_kind(highlighted.tokens, Keyword))
  assert_true(has_kind(highlighted.tokens, Error))
}

///|
test "delegate action reuses a registered lexer for the matched span" {
  let state = StateId::new("main")
  let states : Map[StateId, Array[Rule]] = Map([])
  states.set(state, [
    Rule::{ pattern: Literal("{\"n\": 1}"), action: Delegate("json") },
  ])
  let lexer = RuleLexer::{ initial: state, states }
  let registry = SyntaxRegistry::default().with_lexer(
    ["embedded"],
    RuleBased(lexer),
  )
  let highlighted = checked_highlight(registry, "embedded", "{\"n\": 1}!")
  assert_covers_all(highlighted.tokens, 9)
  assert_true(has_kind(highlighted.tokens, Literal(String)))
  assert_true(has_kind(highlighted.tokens, Literal(Number)))
  assert_true(has_kind(highlighted.tokens, Error))
}

///|
test "render_highlighted maps syntax kinds through styled spans" {
  let highlighted = checked_highlight(
    SyntaxRegistry::default(),
    "moonbit",
    "fn main\n",
  )
  let spans = highlighted_spans(highlighted, SyntaxTheme::default())
  assert_true(has_role(spans, @theme.RoleKey::syntax("keyword")))
  let theme = @theme.Theme::new().with_role(
    @theme.RoleKey::syntax("keyword"),
    @pippa.style().foreground(@pippa.color_ansi(2)).bold(),
  )
  let ctx = @profile.RenderContext::default().with_color_profile(
    @profile.Ansi16,
  )
  let rendered = render_highlighted(
    highlighted,
    SyntaxTheme::default(),
    theme,
    ctx,
  )
  assert_true(rendered.contains("\u001b[32m"))
  assert_true(rendered.contains("\u001b[1mfn"))
}
