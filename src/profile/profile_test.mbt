///|
fn[T] with_env_case(
  no_color : String?,
  clicolor_force : String?,
  clicolor : String?,
  colorterm : String?,
  term : String?,
  body : () -> T raise?,
) -> T raise? {
  let keys = ["NO_COLOR", "CLICOLOR_FORCE", "CLICOLOR", "COLORTERM", "TERM"]
  let snapshot = keys.map(fn(key) { (key, @env.get_env_var(key)) })
  fn apply(key : String, value : String?) -> Unit {
    match value {
      Some(v) => @env.set_env_var(key, v)
      None => @env.unset_env_var(key)
    }
  }
  apply("NO_COLOR", no_color)
  apply("CLICOLOR_FORCE", clicolor_force)
  apply("CLICOLOR", clicolor)
  apply("COLORTERM", colorterm)
  apply("TERM", term)
  try body() catch {
    err => {
      for item in snapshot {
        let (key, value) = item
        apply(key, value)
      }
      raise err
    }
  } noraise {
    result => {
      for item in snapshot {
        let (key, value) = item
        apply(key, value)
      }
      result
    }
  }
}

///|
suberror ProfileScopeFailure

///|
test "profile quantization and render degradation" {
  assert_eq(rgb_to_ansi256(0, 0, 0), 16)
  assert_eq(rgb_to_ansi256(255, 255, 255), 231)
  assert_eq(rgb_to_ansi256(255, 0, 0), 196)
  let gray = rgb_to_ansi256(128, 128, 128)
  assert_true(gray >= 232 && gray <= 255)
  assert_eq(ansi256_to_ansi16(196), 9)
  assert_eq(ansi256_to_ansi16(16), 0)

  let ansi256 = RenderContext::default().with_color_profile(Ansi256)
  assert_eq(render_fg(ansi256, Rgb(255, 0, 0)), "\u001b[38;5;196m")
  assert_eq(render_bg(ansi256, Palette(999)), "\u001b[48;5;255m")

  let ansi16 = RenderContext::default().with_color_profile(Ansi16)
  assert_eq(render_fg(ansi16, Rgb(255, 0, 0)), "\u001b[91m")
  assert_eq(render_bg(ansi16, Palette(12)), "\u001b[104m")

  let no_color = RenderContext::default().with_color_profile(NoColor)
  assert_eq(render_fg(no_color, Rgb(255, 0, 0)), "")
  assert_eq(render_bg(no_color, Palette(2)), "")

  let forced = no_color.with_color_policy(Always)
  assert_eq(render_fg(forced, Palette(2)), "\u001b[32m")
}

///|
test "profile detect env precedence" {
  with_env_case(
    Some("1"),
    Some("1"),
    None,
    Some("truecolor"),
    Some("xterm-256color"),
    fn() raise {
      let ctx = RenderContext::detect()
      assert_eq(ctx.color_policy, Never)
      assert_eq(ctx.color_profile, TrueColor)
    },
  )
  with_env_case(None, Some("1"), Some("0"), None, Some("dumb"), fn() raise {
    let ctx = RenderContext::detect()
    assert_eq(ctx.color_policy, Always)
    assert_eq(ctx.color_profile, NoColor)
    assert_eq(render_fg(ctx, Palette(2)), "\u001b[32m")
  })
  with_env_case(Some(""), None, None, Some("24bit"), Some("dumb"), fn() raise {
    let ctx = RenderContext::detect()
    assert_eq(ctx.color_policy, Auto)
    assert_eq(ctx.color_profile, TrueColor)
  })
}

///|
test "ambient render context scope restores on raise" {
  set_render_context(RenderContext::default())
  let scoped = RenderContext::default()
    .with_color_profile(Ansi16)
    .with_background(Light)
  fn fail_in_scope() -> Unit raise {
    with_render_context(scoped, fn() raise {
      assert_eq(ambient_context(), scoped)
      raise ProfileScopeFailure
    })
  }
  let failed = Ref(false)
  try fail_in_scope() catch {
    _ => failed.val = true
  } noraise {
    _ => ()
  }
  assert_true(failed.val)
  assert_eq(ambient_context(), RenderContext::default())
}
