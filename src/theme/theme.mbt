///|
pub(all) struct RoleKey {
  scope : String
  name : String
} derive(Eq, Show, Hash)

///|
struct Theme {
  roles : Map[RoleKey, @pippa.Style]
  fallback : @pippa.Style
}

///|
pub fn RoleKey::new(scope~ : String, name~ : String) -> RoleKey {
  { scope, name }
}

///|
pub fn RoleKey::ui(name : String) -> RoleKey {
  RoleKey::new(scope="ui", name~)
}

///|
pub fn RoleKey::markdown(name : String) -> RoleKey {
  RoleKey::new(scope="markdown", name~)
}

///|
pub fn RoleKey::syntax(name : String) -> RoleKey {
  RoleKey::new(scope="syntax", name~)
}

///|
pub fn RoleKey::form(name : String) -> RoleKey {
  RoleKey::new(scope="form", name~)
}

///|
pub fn Theme::new(fallback? : @pippa.Style = @pippa.style()) -> Theme {
  { roles: Map([]), fallback }
}

///|
pub fn Theme::with_role(
  self : Theme,
  role : RoleKey,
  style : @pippa.Style,
) -> Theme {
  let roles = self.roles.copy()
  roles.set(role, style)
  { ..self, roles, }
}

///|
pub fn Theme::style(self : Theme, role : RoleKey) -> @pippa.Style {
  match self.roles.get(role) {
    Some(style) => style
    None => self.fallback
  }
}

///|
pub fn Theme::render(
  self : Theme,
  role : RoleKey,
  text : String,
  ctx : @profile.RenderContext,
) -> String {
  self.style(role).render_with(text, ctx)
}

///|
pub fn default_theme() -> Theme {
  Theme::new()
  .with_role(
    RoleKey::ui("text"),
    adaptive_foreground(
      light=@pippa.color_rgb(31, 41, 55),
      dark=@pippa.color_rgb(229, 231, 235),
    ),
  )
  .with_role(
    RoleKey::ui("muted"),
    adaptive_foreground(
      light=@pippa.color_rgb(107, 114, 128),
      dark=@pippa.color_rgb(156, 163, 175),
    ),
  )
  .with_role(
    RoleKey::ui("accent"),
    adaptive_foreground(
      light=@pippa.color_rgb(37, 99, 235),
      dark=@pippa.color_rgb(96, 165, 250),
    ),
  )
  .with_role(
    RoleKey::ui("focus"),
    adaptive_foreground(
      light=@pippa.color_rgb(124, 58, 237),
      dark=@pippa.color_rgb(167, 139, 250),
    ),
  )
  .with_role(
    RoleKey::ui("error"),
    adaptive_foreground(
      light=@pippa.color_rgb(185, 28, 28),
      dark=@pippa.color_rgb(248, 113, 113),
    ),
  )
  .with_role(
    RoleKey::ui("warning"),
    adaptive_foreground(
      light=@pippa.color_rgb(180, 83, 9),
      dark=@pippa.color_rgb(251, 191, 36),
    ),
  )
  .with_role(
    RoleKey::ui("success"),
    adaptive_foreground(
      light=@pippa.color_rgb(21, 128, 61),
      dark=@pippa.color_rgb(74, 222, 128),
    ),
  )
  .with_role(
    RoleKey::ui("border"),
    adaptive_foreground(
      light=@pippa.color_rgb(156, 163, 175),
      dark=@pippa.color_rgb(75, 85, 99),
    ),
  )
}

///|
fn adaptive_foreground(
  light~ : @pippa.Color,
  dark~ : @pippa.Color,
) -> @pippa.Style {
  @pippa.style().foreground(@pippa.color_adaptive(light, dark))
}
