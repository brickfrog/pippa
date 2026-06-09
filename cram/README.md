# Cram end-to-end snapshots

These [cram][cram]-style tests exercise Pippa's **real, compiled example
binaries** end to end. Unlike the `*_snapshot_test.mbt` golden-frame tests under
`src/examples/*-parity/` (which call the `@replay` engine in-process), the cram
suite builds the actual `*-parity-app` executables and drives them through their
command-line / environment interface, then asserts on the bytes they print to
stdout. This is the layer that catches regressions in argument parsing, the
replay trigger wiring, color-profile detection, and raw terminal output — things
the in-process snapshots cannot see.

They are run by `moon cram test cram/`, which is wired into CI as an **advisory
(non-blocking) job** — see [Promoting cram from advisory to required](#promoting-cram-from-advisory-to-required).

[cram]: https://bitheap.org/cram/

## How a run works

`moon cram test cram/` (which invokes the bundled, experimental `moon-cram`):

1. Builds every native example executable into
   `_build/native/debug/build/examples/<app>/<app>.exe`.
2. Prepends each of those build directories to `PATH`.
3. Runs `moon-cram test cram/`, so every `  $ <command>` line in a `*.t` file can
   invoke an app by bare name (e.g. `list-parity-app.exe`).

Each app reaches replay mode through the shared trigger helper in
`src/replay/trigger.mbt` (`maybe_run_replay`). When a trigger is present the app
plays the scripted keystrokes through the headless runtime, prints the captured
frames, and exits; otherwise it falls through to the normal interactive
`@pippa.Program::run` path with byte-identical behavior. Each captured frame is
prefixed with a `--- frame N ---` delimiter line (0-based) so the per-frame
boundaries stay separable and a fixture can assert on a single frame instead of
one undelimited byte-mash. The trigger can be supplied two equivalent ways:

| | CLI flag | Environment variable |
| --- | --- | --- |
| Script (key tokens) | `--replay "<tokens>"` | `PIPPA_REPLAY=<tokens>` |
| Keep raw ANSI output | `--raw` / `--ansi` | `PIPPA_REPLAY_RAW=1` |
| Initial terminal size | `--size <WxH>` | `PIPPA_REPLAY_SIZE=<WxH>` (default `80x24`) |

> ⚠️ **Footgun — the `PIPPA_REPLAY` environment trigger is *ambient*.**
> `maybe_run_replay` consults `PIPPA_REPLAY` on **every** app launch, so any
> shell that has `export PIPPA_REPLAY=...` set will silently turn **every** app
> built on the helper — including every shipped `*-parity-app` — into
> replay-and-exit instead of starting interactively. There is no per-app opt-in.
> Prefer the explicit `--replay` CLI flag, and always unset `PIPPA_REPLAY`,
> `PIPPA_REPLAY_RAW`, and `PIPPA_REPLAY_SIZE` in tests and CI (every *replay* cram
> command below does this with `env -u`; the `color-profile.t` commands don't,
> because `color-profile.exe` isn't a replay command). A blank
> `export PIPPA_REPLAY=` is ignored as a small guard, but any non-empty value
> still triggers.

Output is **normalized** (control sequences stripped to readable text) by
default; `--raw` / `PIPPA_REPLAY_RAW=1` keeps the raw runtime ANSI so escape
sequences can be asserted directly. Normalization also drops the program-exit
teardown reset-SGR (`ESC[39m` `ESC[49m`) when it tails the stream, so a
normalized frame ends on its own content rather than a teardown barnacle;
mid-stream SGR color is preserved.

## What the suite covers

| File | Cases | Driver | What it pins |
| --- | --- | --- | --- |
| `color-profile.t` | 3 | `color-profile.exe` | Color-profile detection: TrueColor → 24-bit SGR, `xterm-256color` → 256-color downsample, and `NO_COLOR` → colors stripped while the bold attribute is retained. |
| `replay-normalized.t` | 1 | `list-parity-app.exe --replay "/ f z enter"` | The **normalized** keystroke-driven frame sequence (fuzzy-filter a list and select a row). |
| `replay-raw-ansi.t` | 1 | `terminal-state-parity-app.exe --replay "c" --raw` | The **raw ANSI** control stream: alt-screen enter/exit, cursor show/hide, line erase, and the keystroke-driven cursor-visibility diff frame. |

Total: **5 testcases across 3 files.**

## Per-command environment pinning

Terminal output depends on ambient environment (`NO_COLOR`, `CLICOLOR`,
`CLICOLOR_FORCE`, `COLORTERM`, `TERM`, …). To stay deterministic across
developer machines and CI runners, **every** command line pins its own
environment with `env -u <var>` (to unset inherited vars) plus explicit
assignments (to select the profile under test). For example, from
`color-profile.t`:

```text
TrueColor (COLORTERM=truecolor) -> 24-bit SGR escapes:
  $ env -u NO_COLOR -u CLICOLOR -u CLICOLOR_FORCE -u TERM COLORTERM=truecolor color-profile.exe
  \x1b[38;2;255;0;0mred\x1b[0m (escaped)
  ...
```

The replay tests additionally unset `PIPPA_REPLAY`, `PIPPA_REPLAY_RAW`, and
`PIPPA_REPLAY_SIZE` so an exported trigger in the surrounding shell can never
leak into the fixture. Keep this discipline for any new command: never rely on
the inherited environment. The `(escaped)` suffix on an expectation line means
`moon-cram` escaped non-printable bytes in that line.

## Authoring and updating expectations

Expectations are regenerated by `moon-cram update`, which re-runs each command
and rewrites the expected output in place. `moon cram test` itself only runs the
`test` subcommand, so the update flow drives `moon-cram` directly with the
example build directories on `PATH`:

```bash
# 1. Build the parity-app binaries (this also runs the suite; while you are
#    updating, mismatches are expected, hence the `|| true`).
moon cram test cram/ || true

# 2. Put the freshly built binaries on PATH and refresh expectations for the
#    file(s) you changed.
build=_build/native/debug/build/examples
PATH="$(printf '%s:' "$PWD/$build"/*/)$PATH" \
  moon-cram update cram/replay-normalized.t

# 3. Confirm the suite is green again.
moon cram test cram/
```

To author a brand-new case, add the description + `  $ <command>` line (with its
full `env -u … VAR=value` prefix) to a `*.t` file, leave the expectation body
empty, then run the `moon-cram update` step above to fill it in. Review the
generated diff carefully — these are golden snapshots; an unexpected change in
the output is a real behavioral change, not noise.

## Promoting cram from advisory to required

The cram job is intentionally **advisory** today (`continue-on-error: true` in
`.github/workflows/ci.yml`, and it is *not* a required status check) because
`moon-cram` is experimental/hidden and the toolchain pin is currently soft.
Promote it to a required, blocking gate only once **both** hold:

1. **The toolchain is hard-pinned and reproducible.** The official distribution
   currently serves only the rolling `latest`/`nightly` channels, so CI requests
   `MOON_VERSION` as a *soft reference* and falls back to `latest` when the dated
   build is unavailable (see the header comment in `.github/workflows/ci.yml`).
   Each setup step reads the actually-resolved toolchain (`moon version`) and
   only reports the version as pinned when it genuinely matches `MOON_VERSION`,
   emitting a non-failing `::warning::` that CI is on a floating toolchain
   otherwise — so the soft pin is reported honestly but **not yet enforced** on
   any job (required or advisory). Because the golden ANSI bytes depend on the
   exact compiler/runtime, a rolling toolchain can drift the frames and flake the
   suite. Promotion requires a hard pin — e.g. an archived/vendored toolchain or
   a cached `~/.moon` keyed on `MOON_VERSION` — with CI **failing** on a version
   mismatch instead of warning.
2. **The suite is proven stable.** The cram cases run flake-free across a
   meaningful window of CI runs (no env-dependent nondeterminism, no
   intermittent ordering/timing differences in the captured frames).

When both are met, remove `continue-on-error: true` from the `cram` job, mark its
check as required in the branch protection rules for `main`, and update this
section.
