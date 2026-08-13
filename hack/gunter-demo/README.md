# gunter-demo — real pixel graphics in a Go terminal CLI

A runnable demo of showing an animated GIF (a dancing Gunter, ideally) in the
terminal at real pixel quality — not ASCII art — from a Go CLI, including
inside a live [Bubble Tea](https://github.com/charmbracelet/bubbletea) UI.

Bubble Tea itself only deals in text cells. Real graphics require a **terminal
graphics protocol**, and which one you get depends on the terminal emulator,
not the Go code:

| Protocol | Terminals | Quality |
|---|---|---|
| **kitty graphics** | Ghostty, kitty, WezTerm, Konsole | Full 24-bit, pixel-perfect |
| **iTerm2 inline images** | iTerm2, WezTerm | Full quality |
| **sixel** | xterm, foot, mlterm, Windows Terminal 1.22+ | Paletted/dithered |
| **halfblocks** | any color terminal | Blocky `▀` cells — the fallback ceiling for "normal" terminals |

The heavy lifting is done by
[`github.com/blacktop/go-termimg`](https://github.com/blacktop/go-termimg),
which auto-detects the best protocol and encodes frames for it. GIF decoding
and frame coalescing is stdlib (`image/gif`).

## Run it

```bash
cd hack/gunter-demo

go run . detect              # which protocol does this terminal support?
go run .                     # Bubble Tea TUI with built-in placeholder penguin
go run . splash              # raw fullscreen splash (most robust rendering path)
go run . -width 60 tui ~/Downloads/gunter.gif   # the real deal
```

No GIF is committed here (Gunter is Cartoon Network's penguin) — pass a path
to your own. With no path a stdlib-drawn dancing penguin placeholder is used.

## The two integration patterns

**Splash (`splash.go`)** — play the animation *outside* any TUI framework:
raw mode, alternate screen, home the cursor, print the pre-rendered frame,
sleep the frame's native delay, repeat. Nothing can mangle the escape
sequences, so this is the bulletproof path. Good for startup/loading screens
before handing over to Bubble Tea.

**Embedded (`tui.go`)** — pre-render every frame to an escape string once at
startup, then advance an index with `tea.Tick(frameDelay)` and return the
current frame from `View()`. The rest of the view is ordinary lipgloss text.

Porting sketch for your own CLI:

```go
anim, _ := LoadGIF("gunter.gif")            // frames.go: decode + coalesce
frames, _ := renderFrames(anim, 40, proto)  // render.go: encode once, cache
// in Update(): on tickMsg → idx = (idx+1) % len(frames); re-tick with anim.Delays[idx]
// in View():   return header + "\n" + frames[idx] + "\n" + footer
```

Frame coalescing (`frames.go`) matters: GIF frames on disk are often partial
diffs with per-frame disposal semantics. Rendering them raw produces garbage;
each frame must be composited onto a persistent canvas first.

## Caveats learned the hard way

- **Don't wrap the image in lipgloss layout helpers** (borders,
  `JoinVertical`, width-constrained styles). They measure strings by
  printable cell width; kitty/iTerm2/sixel escape payloads confuse the math
  and can get truncated. Keep the frame string on its own raw lines.
  Halfblock frames are plain ANSI text and can go anywhere.
- **tmux swallows graphics** unless passthrough is on
  (`set -g allow-passthrough on`; go-termimg wraps sequences for tmux, but
  the option must be enabled). Halfblocks work regardless.
- **kitty accumulates transmitted images** — every frame is a new image in
  terminal memory. The demo emits a delete-all (`ESC _Ga=d,d=A ESC \`) on
  exit. kitty also evicts by quota, so a long-running loop is safe, just not
  free. A production version could use kitty's native animation protocol
  (transmit frames once with `a=f`, let the terminal animate) — go-termimg
  exposes a low-level `KittyRenderer.AnimateImages` for this.
- **sixel repaints flicker** on some terminals; there is no in-place update.
  Acceptable for a splash, less nice embedded.
- go-termimg's kitty "virtual placement" / Unicode placeholder mode is
  marked not production-ready by upstream — this demo uses normal rendering.
- **"Higher quality than a GIF?"** The kitty/iTerm2 protocols transmit full
  RGBA frames, so quality is limited by your *source*, not the protocol. For
  video-grade Gunter, extract frames with ffmpeg
  (`ffmpeg -i gunter.mp4 -vf fps=15,scale=320:-1 frames_%03d.png`) and feed
  them through the same pre-render + tick loop. In-process video decoding
  would drag in cgo/ffmpeg bindings and isn't worth it for a mascot.

## Tests

```bash
go test ./...                              # GIF encode→decode→coalesce round-trip
GUNTER_DUMP_DIR=/tmp go test ./...         # also writes placeholder.gif + frame0.png to inspect
```
