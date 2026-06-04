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
  assert_true(has_kind(moon.tokens, Keyword))
  assert_true(has_kind(moon.tokens, Name(Type)))
  assert_true(has_kind(moon.tokens, Literal(Bool)))

  let json = checked_highlight(registry, "json", "{\"name\": true, \"n\": 42}")
  assert_covers_all(json.tokens, @utf8.encode(json.source[:]).length())
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
