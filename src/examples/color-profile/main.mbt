///|
/// Headless color-profile demo for shell verification.

///|
fn swatch(
  label : String,
  color : @pippa.Color,
  ctx : @profile.RenderContext,
) -> String {
  @pippa.style().foreground(color).render_with(label, ctx)
}

///|
fn main {
  let ctx = @profile.RenderContext::detect()
  @profile.set_render_context(ctx)
  println(
    [
      swatch("red", @pippa.color_rgb(255, 0, 0), ctx),
      swatch("green", @pippa.color_rgb(0, 255, 0), ctx),
      swatch("blue", @pippa.color_hex("#0000ff"), ctx),
      @pippa.style()
      .foreground(
        @pippa.color_adaptive(
          @pippa.color_rgb(30, 40, 50),
          @pippa.color_rgb(230, 220, 180),
        ),
      )
      .render_with("adaptive", ctx),
      @pippa.style()
      .bold()
      .foreground_rgb(255, 128, 0)
      .render_with("bold sample", ctx),
    ].join("\n"),
  )
}
