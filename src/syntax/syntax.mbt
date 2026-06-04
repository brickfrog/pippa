///|
pub(all) enum NameKind {
  Variable
  Function
  Type
  Module
  Attribute
  Constant
} derive(Eq, Debug)

///|
pub(all) enum LiteralKind {
  String
  Char
  Number
  Bool
  Regex
} derive(Eq, Debug)

///|
pub(all) enum SyntaxKind {
  Text
  Whitespace
  Comment
  Keyword
  Name(NameKind)
  Literal(LiteralKind)
  Operator
  Punctuation
  Escape
  Error
} derive(Eq, Debug)

///|
pub(all) struct TokenSpan {
  start_byte : Int
  end_byte : Int
  kind : SyntaxKind
} derive(Eq, Debug)

///|
pub(all) struct Highlighted {
  source : String
  tokens : Array[TokenSpan]
} derive(Eq, Debug)

///|
pub(all) enum StateId {
  StateId(String)
} derive(Eq, Hash, Debug)

///|
pub(all) enum Pattern {
  Literal(String)
  CharSet(String)
  Regex(String)
  Until(String)
} derive(Eq, Debug)

///|
pub(all) enum LexAction {
  Emit(SyntaxKind)
  Push(StateId)
  Pop
  Stay
  Delegate(String)
} derive(Eq, Debug)

///|
pub(all) struct Rule {
  pattern : Pattern
  action : LexAction
} derive(Eq, Debug)

///|
pub(all) struct RuleLexer {
  initial : StateId
  states : Map[StateId, Array[Rule]]
} derive(Debug)

///|
pub(all) enum Lexer {
  PlainText
  RuleBased(RuleLexer)
} derive(Debug)

///|
pub(all) struct SyntaxRegistry {
  lexers : Map[String, Lexer]
} derive(Debug)

///|
pub(all) enum LexError {
  UnknownLanguage(String)
  MissingState(StateId)
  InvalidRegex(String)
  EmptyRegexMatch(String)
  StateStackUnderflow
} derive(Eq, Debug)

///|
pub(all) struct SyntaxTheme {
  role_for : (SyntaxKind) -> @theme.RoleKey
}

///|
pub impl Show for NameKind with fn output(self, logger) {
  match self {
    Variable => logger.write_string("Variable")
    Function => logger.write_string("Function")
    Type => logger.write_string("Type")
    Module => logger.write_string("Module")
    Attribute => logger.write_string("Attribute")
    Constant => logger.write_string("Constant")
  }
}

///|
pub impl Show for LiteralKind with fn output(self, logger) {
  match self {
    String => logger.write_string("String")
    Char => logger.write_string("Char")
    Number => logger.write_string("Number")
    Bool => logger.write_string("Bool")
    Regex => logger.write_string("Regex")
  }
}

///|
pub impl Show for SyntaxKind with fn output(self, logger) {
  match self {
    Text => logger.write_string("Text")
    Whitespace => logger.write_string("Whitespace")
    Comment => logger.write_string("Comment")
    Keyword => logger.write_string("Keyword")
    Name(kind) => logger.write_string("Name(\{kind})")
    Literal(kind) => logger.write_string("Literal(\{kind})")
    Operator => logger.write_string("Operator")
    Punctuation => logger.write_string("Punctuation")
    Escape => logger.write_string("Escape")
    Error => logger.write_string("Error")
  }
}

///|
pub impl Show for TokenSpan with fn output(self, logger) {
  logger.write_string(
    "TokenSpan(start_byte=\{self.start_byte}, end_byte=\{self.end_byte}, kind=\{self.kind})",
  )
}

///|
pub impl Show for Highlighted with fn output(self, logger) {
  logger.write_string(
    "Highlighted(source=\{self.source.escape()}, token_count=\{self.tokens.length()})",
  )
}

///|
pub impl Show for StateId with fn output(self, logger) {
  match self {
    StateId(value) => logger.write_string("StateId(\{value})")
  }
}

///|
pub impl Show for Pattern with fn output(self, logger) {
  match self {
    Literal(value) => logger.write_string("Literal(\{value.escape()})")
    CharSet(value) => logger.write_string("CharSet(\{value.escape()})")
    Regex(value) => logger.write_string("Regex(\{value.escape()})")
    Until(value) => logger.write_string("Until(\{value.escape()})")
  }
}

///|
pub impl Show for LexAction with fn output(self, logger) {
  match self {
    Emit(kind) => logger.write_string("Emit(\{kind})")
    Push(state) => logger.write_string("Push(\{state})")
    Pop => logger.write_string("Pop")
    Stay => logger.write_string("Stay")
    Delegate(language) => logger.write_string("Delegate(\{language})")
  }
}

///|
pub impl Show for Rule with fn output(self, logger) {
  logger.write_string("Rule(pattern=\{self.pattern}, action=\{self.action})")
}

///|
pub impl Show for RuleLexer with fn output(self, logger) {
  logger.write_string(
    "RuleLexer(initial=\{self.initial}, states=\{self.states.length()})",
  )
}

///|
pub impl Show for Lexer with fn output(self, logger) {
  match self {
    PlainText => logger.write_string("PlainText")
    RuleBased(lexer) => logger.write_string("RuleBased(\{lexer})")
  }
}

///|
pub impl Show for SyntaxRegistry with fn output(self, logger) {
  logger.write_string("SyntaxRegistry(lexers=\{self.lexers.length()})")
}

///|
pub impl Show for LexError with fn output(self, logger) {
  match self {
    UnknownLanguage(language) =>
      logger.write_string("UnknownLanguage(\{language})")
    MissingState(state) => logger.write_string("MissingState(\{state})")
    InvalidRegex(pattern) =>
      logger.write_string("InvalidRegex(\{pattern.escape()})")
    EmptyRegexMatch(pattern) =>
      logger.write_string("EmptyRegexMatch(\{pattern.escape()})")
    StateStackUnderflow => logger.write_string("StateStackUnderflow")
  }
}

///|
pub impl Eq for RuleLexer with fn equal(self, other) {
  self.initial == other.initial &&
  rule_state_maps_equal(self.states, other.states)
}

///|
pub impl Eq for Lexer with fn equal(self, other) {
  match (self, other) {
    (PlainText, PlainText) => true
    (RuleBased(left), RuleBased(right)) => left == right
    _ => false
  }
}

///|
pub impl Eq for SyntaxRegistry with fn equal(self, other) {
  lexer_maps_equal(self.lexers, other.lexers)
}

///|
fn rule_state_maps_equal(
  left : Map[StateId, Array[Rule]],
  right : Map[StateId, Array[Rule]],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for entry in left {
    let (state, rules) = entry
    match right.get(state) {
      Some(other_rules) if rules == other_rules => ()
      _ => return false
    }
  }
  true
}

///|
fn lexer_maps_equal(
  left : Map[String, Lexer],
  right : Map[String, Lexer],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for entry in left {
    let (language, lexer) = entry
    match right.get(language) {
      Some(other_lexer) if lexer == other_lexer => ()
      _ => return false
    }
  }
  true
}

///|
pub fn StateId::value(self : StateId) -> String {
  match self {
    StateId(value) => value
  }
}

///|
pub fn StateId::new(value : String) -> StateId {
  StateId(value)
}

///|
pub fn RuleLexer::new(
  initial : StateId,
  states : Map[StateId, Array[Rule]],
) -> RuleLexer {
  { initial, states }
}

///|
fn normalize_language(language : String) -> String {
  language.trim().to_owned().to_lower()
}

///|
pub fn SyntaxRegistry::new() -> SyntaxRegistry {
  { lexers: Map([]) }
}

///|
pub fn SyntaxRegistry::with_lexer(
  self : SyntaxRegistry,
  names : Array[String],
  lexer : Lexer,
) -> SyntaxRegistry {
  let lexers = self.lexers.copy()
  for name in names {
    lexers.set(normalize_language(name), lexer)
  }
  { lexers, }
}

///|
pub fn SyntaxRegistry::lexer(
  self : SyntaxRegistry,
  language : String,
) -> Lexer? {
  self.lexers.get(normalize_language(language))
}

///|
pub fn SyntaxRegistry::default() -> SyntaxRegistry {
  SyntaxRegistry::new()
  .with_lexer(["text", "plain", "plaintext", "txt"], plain_text_lexer())
  .with_lexer(["moonbit", "mbt"], moonbit_lexer())
  .with_lexer(["json"], json_lexer())
  .with_lexer(["shell", "sh", "bash"], shell_lexer())
  .with_lexer(["diff", "patch"], diff_lexer())
}

///|
fn rule(pattern : Pattern, action : LexAction) -> Rule {
  { pattern, action }
}

///|
fn single_state_lexer(rules : Array[Rule]) -> RuleLexer {
  let initial = StateId("main")
  let states : Map[StateId, Array[Rule]] = Map([])
  states.set(initial, rules)
  RuleLexer::{ initial, states }
}

///|
pub fn plain_text_lexer() -> Lexer {
  PlainText
}

///|
pub fn moonbit_lexer() -> Lexer {
  RuleBased(
    single_state_lexer([
      rule(Regex("//[^\\n]*"), Emit(Comment)),
      rule(Regex("/[*].*?[*]/"), Emit(Comment)),
      rule(Regex("\"([^\"\\\\]|\\\\.)*\""), Emit(Literal(String))),
      rule(Regex("'([^'\\\\]|\\\\.)*'"), Emit(Literal(Char))),
      rule(Regex("\\b(true|false)\\b"), Emit(Literal(Bool))),
      rule(
        Regex(
          "\\b(async|await|break|catch|const|continue|derive|else|enum|fn|for|guard|if|impl|import|in|let|match|priv|pub|raise|return|struct|test|trait|try|type|while)\\b",
        ),
        Emit(Keyword),
      ),
      rule(Regex("@[A-Za-z_][A-Za-z0-9_]*"), Emit(Name(Attribute))),
      rule(Regex("[A-Z][A-Za-z0-9_]*"), Emit(Name(Type))),
      rule(Regex("[0-9]+([.][0-9]+)?"), Emit(Literal(Number))),
      rule(Regex("[A-Za-z_][A-Za-z0-9_]*"), Emit(Name(Variable))),
      rule(CharSet(" \t\r\n"), Emit(Whitespace)),
      rule(CharSet("+-*/=%!<>|&^~.:"), Emit(Operator)),
      rule(CharSet("(){}[];,"), Emit(Punctuation)),
    ]),
  )
}

///|
pub fn json_lexer() -> Lexer {
  RuleBased(
    single_state_lexer([
      rule(CharSet(" \t\r\n"), Emit(Whitespace)),
      rule(Regex("\"([^\"\\\\]|\\\\.)*\""), Emit(Literal(String))),
      rule(
        Regex("-?(0|[1-9][0-9]*)([.][0-9]+)?([eE][+\\-]?[0-9]+)?"),
        Emit(Literal(Number)),
      ),
      rule(Regex("\\b(true|false)\\b"), Emit(Literal(Bool))),
      rule(Regex("\\bnull\\b"), Emit(Keyword)),
      rule(CharSet("{}[]:,"), Emit(Punctuation)),
    ]),
  )
}

///|
pub fn shell_lexer() -> Lexer {
  RuleBased(
    single_state_lexer([
      rule(CharSet(" \t\r\n"), Emit(Whitespace)),
      rule(Regex("#[^\\n]*"), Emit(Comment)),
      rule(Regex("'[^']*'"), Emit(Literal(String))),
      rule(Regex("\"([^\"\\\\]|\\\\.)*\""), Emit(Literal(String))),
      rule(
        Regex(
          "\\b(case|do|done|elif|else|esac|fi|for|function|if|in|then|until|while)\\b",
        ),
        Emit(Keyword),
      ),
      rule(
        Regex("[$]([A-Za-z_][A-Za-z0-9_]*|[0-9]+|[@*#?!\\-])"),
        Emit(Name(Variable)),
      ),
      rule(
        Regex("--?[A-Za-z][A-Za-z0-9_\\-]*(=[^ \t\r\n;&|()<>]+)?"),
        Emit(Name(Attribute)),
      ),
      rule(Regex("[0-9]+([.][0-9]+)?"), Emit(Literal(Number))),
      rule(Regex("[A-Za-z_][A-Za-z0-9_]*"), Emit(Name(Variable))),
      rule(CharSet("|&;=<>"), Emit(Operator)),
      rule(CharSet("()[]{}"), Emit(Punctuation)),
    ]),
  )
}

///|
pub fn diff_lexer() -> Lexer {
  RuleBased(
    single_state_lexer([
      rule(Regex("[@][@][^\\n]*(\\n)?"), Emit(Keyword)),
      rule(Regex("[+][^\\n]*(\\n)?"), Emit(Name(Constant))),
      rule(Regex("-[^\\n]*(\\n)?"), Emit(Error)),
      rule(Regex(" [^\\n]*(\\n)?"), Emit(Text)),
      rule(CharSet("\n"), Emit(Whitespace)),
    ]),
  )
}

///|
fn encoded(source : String) -> Bytes {
  @utf8.encode(source[:])
}

///|
fn bytes_from_view(view : BytesView) -> Bytes {
  Bytes::from_array(view.to_array())
}

///|
fn byte_slice_text(bytes : Bytes, start : Int, end_index : Int) -> String {
  let safe_start = start.max(0).min(bytes.length())
  let safe_end = end_index.max(safe_start).min(bytes.length())
  @utf8.decode_lossy(bytes_from_view(bytes[safe_start:safe_end])[:])
}

///|
fn next_scalar_width(bytes : Bytes, index : Int) -> Int {
  if index >= bytes.length() {
    return 0
  }
  let first = bytes[index].to_int()
  let width = if first < 0x80 {
    1
  } else if first < 0xE0 {
    2
  } else if first < 0xF0 {
    3
  } else {
    4
  }
  width.min(bytes.length() - index).max(1)
}

///|
fn bytes_have_prefix(bytes : Bytes, index : Int, needle : Bytes) -> Bool {
  if needle.length() == 0 || index + needle.length() > bytes.length() {
    return false
  }
  for i in 0..<needle.length() {
    if bytes[index + i] != needle[i] {
      return false
    }
  }
  true
}

///|
fn find_bytes(bytes : Bytes, start : Int, needle : Bytes) -> Int? {
  if needle.length() == 0 {
    return Some(start)
  }
  let mut index = start
  while index + needle.length() <= bytes.length() {
    if bytes_have_prefix(bytes, index, needle) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn charset_contains_byte(charset : String, byte : Byte) -> Bool {
  let bytes = encoded(charset)
  for i in 0..<bytes.length() {
    if bytes[i] == byte {
      return true
    }
  }
  false
}

///|
fn match_literal(bytes : Bytes, index : Int, literal : String) -> Int {
  let needle = encoded(literal)
  if bytes_have_prefix(bytes, index, needle) {
    needle.length()
  } else {
    0
  }
}

///|
fn match_charset(bytes : Bytes, index : Int, chars : String) -> Int {
  if index < bytes.length() && charset_contains_byte(chars, bytes[index]) {
    1
  } else {
    0
  }
}

///|
fn match_until(bytes : Bytes, index : Int, delimiter : String) -> Int {
  let needle = encoded(delimiter)
  if needle.length() == 0 {
    return next_scalar_width(bytes, index)
  }
  match find_bytes(bytes, index, needle) {
    Some(found) => found + needle.length() - index
    None => bytes.length() - index
  }
}

///|
fn match_regex(
  bytes : Bytes,
  index : Int,
  pattern : String,
) -> Result[Int, LexError] {
  let suffix = byte_slice_text(bytes, index, bytes.length())
  let anchored_pattern = "^(?:" + pattern + ")"
  let regex : @string.Regex = @string.Regex(anchored_pattern[:]) catch {
    _ => return Err(InvalidRegex(pattern))
  }
  match regex.execute(suffix[:], last_index=0) {
    Some(matched) => {
      let consumed = encoded(matched.content().to_owned()).length()
      if consumed == 0 {
        Err(EmptyRegexMatch(pattern))
      } else {
        Ok(consumed)
      }
    }
    _ => Ok(0)
  }
}

///|
fn match_pattern(
  pattern : Pattern,
  bytes : Bytes,
  index : Int,
) -> Result[Int, LexError] {
  match pattern {
    Literal(value) => Ok(match_literal(bytes, index, value))
    CharSet(chars) => Ok(match_charset(bytes, index, chars))
    Regex(value) => match_regex(bytes, index, value)
    Until(value) => Ok(match_until(bytes, index, value))
  }
}

///|
fn action_kind(action : LexAction) -> SyntaxKind {
  match action {
    Emit(kind) => kind
    Push(_) | Pop | Stay | Delegate(_) => Text
  }
}

///|
fn push_token(
  tokens : Array[TokenSpan],
  start : Int,
  end_index : Int,
  kind : SyntaxKind,
) -> Unit {
  if end_index <= start {
    return
  }
  if tokens.length() > 0 {
    let last_index = tokens.length() - 1
    let last = tokens[last_index]
    if last.kind == kind && last.end_byte == start {
      tokens[last_index] = { ..last, end_byte: end_index }
      return
    }
  }
  tokens.push(TokenSpan::{ start_byte: start, end_byte: end_index, kind })
}

///|
fn apply_action(
  action : LexAction,
  stack : Array[StateId],
  current : StateId,
) -> Result[StateId, LexError] {
  match action {
    Push(state) => {
      stack.push(current)
      Ok(state)
    }
    Pop =>
      match stack.pop() {
        Some(state) => Ok(state)
        None => Err(StateStackUnderflow)
      }
    Emit(_) | Stay | Delegate(_) => Ok(current)
  }
}

///|
fn run_rule_lexer(
  registry : SyntaxRegistry,
  lexer : RuleLexer,
  source : String,
  depth : Int,
) -> Result[Highlighted, LexError] {
  let bytes = encoded(source)
  let tokens : Array[TokenSpan] = []
  let stack : Array[StateId] = []
  let mut current = lexer.initial
  let mut index = 0
  while index < bytes.length() {
    let rules = match lexer.states.get(current) {
      Some(rules) => rules
      None => return Err(MissingState(current))
    }
    let mut matched = false
    for item in rules {
      let length = match match_pattern(item.pattern, bytes, index) {
        Ok(length) => length
        Err(err) => return Err(err)
      }
      if length > 0 {
        match item.action {
          Delegate(language) => {
            let delegated_source = byte_slice_text(bytes, index, index + length)
            let delegated = match
              highlight_with_depth(
                registry,
                language,
                delegated_source,
                depth + 1,
              ) {
              Ok(highlighted) => highlighted
              Err(err) => return Err(err)
            }
            for token in delegated.tokens {
              push_token(
                tokens,
                index + token.start_byte,
                index + token.end_byte,
                token.kind,
              )
            }
          }
          _ =>
            push_token(tokens, index, index + length, action_kind(item.action))
        }
        current = match apply_action(item.action, stack, current) {
          Ok(state) => state
          Err(err) => return Err(err)
        }
        index = index + length
        matched = true
        break
      }
    }
    if !matched {
      let length = next_scalar_width(bytes, index)
      push_token(tokens, index, index + length, Error)
      index = index + length
    }
  }
  Ok({ source, tokens })
}

///|
fn plain_highlighted(source : String) -> Highlighted {
  let tokens : Array[TokenSpan] = []
  let length = encoded(source).length()
  if length > 0 {
    tokens.push(TokenSpan::{ start_byte: 0, end_byte: length, kind: Text })
  }
  { source, tokens }
}

///|
pub fn highlight(
  registry : SyntaxRegistry,
  language : String,
  source : String,
) -> Result[Highlighted, LexError] {
  highlight_with_depth(registry, language, source, 0)
}

///|
fn highlight_with_depth(
  registry : SyntaxRegistry,
  language : String,
  source : String,
  depth : Int,
) -> Result[Highlighted, LexError] {
  if depth > 8 {
    return Err(UnknownLanguage(language))
  }
  match registry.lexer(language) {
    Some(PlainText) => Ok(plain_highlighted(source))
    Some(RuleBased(lexer)) => run_rule_lexer(registry, lexer, source, depth)
    None => Err(UnknownLanguage(language))
  }
}

///|
fn default_syntax_role(kind : SyntaxKind) -> @theme.RoleKey {
  match kind {
    Text | Whitespace => @theme.RoleKey::syntax("text")
    Comment => @theme.RoleKey::syntax("comment")
    Keyword => @theme.RoleKey::syntax("keyword")
    Name(Variable) => @theme.RoleKey::syntax("variable")
    Name(Function) => @theme.RoleKey::syntax("function")
    Name(Type) => @theme.RoleKey::syntax("type")
    Name(Module) => @theme.RoleKey::syntax("module")
    Name(Attribute) => @theme.RoleKey::syntax("attribute")
    Name(Constant) => @theme.RoleKey::syntax("constant")
    Literal(String) => @theme.RoleKey::syntax("string")
    Literal(Char) => @theme.RoleKey::syntax("char")
    Literal(Number) => @theme.RoleKey::syntax("number")
    Literal(Bool) => @theme.RoleKey::syntax("bool")
    Literal(Regex) => @theme.RoleKey::syntax("regex")
    Operator => @theme.RoleKey::syntax("operator")
    Punctuation => @theme.RoleKey::syntax("punctuation")
    Escape => @theme.RoleKey::syntax("escape")
    Error => @theme.RoleKey::syntax("error")
  }
}

///|
pub fn SyntaxTheme::default() -> SyntaxTheme {
  { role_for: default_syntax_role }
}

///|
pub fn SyntaxTheme::role(
  self : SyntaxTheme,
  kind : SyntaxKind,
) -> @theme.RoleKey {
  (self.role_for)(kind)
}

///|
pub fn highlighted_spans(
  highlighted : Highlighted,
  syntax_theme : SyntaxTheme,
) -> Array[@theme.StyledSpan] {
  let bytes = encoded(highlighted.source)
  let spans : Array[@theme.StyledSpan] = []
  for token in highlighted.tokens {
    spans.push(
      @theme.StyledSpan::new(
        byte_slice_text(bytes, token.start_byte, token.end_byte),
        syntax_theme.role(token.kind),
      ),
    )
  }
  spans
}

///|
pub fn render_highlighted(
  highlighted : Highlighted,
  syntax_theme : SyntaxTheme,
  theme : @theme.Theme,
  ctx : @profile.RenderContext,
) -> String {
  @theme.render_spans(highlighted_spans(highlighted, syntax_theme), theme, ctx)
}
