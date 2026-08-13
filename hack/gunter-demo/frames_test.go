package main

import (
	"image"
	"image/color/palette"
	"image/draw"
	"image/gif"
	"image/png"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// TestGIFRoundTrip encodes the placeholder animation to a real GIF file and
// reloads it through LoadGIF, exercising decode + frame coalescing.
// Set GUNTER_DUMP_DIR to also write the GIF and a PNG of frame 0 for visual
// inspection.
func TestGIFRoundTrip(t *testing.T) {
	anim := Placeholder()

	g := &gif.GIF{Config: image.Config{Width: anim.Width, Height: anim.Height}}
	for i, frame := range anim.Frames {
		p := image.NewPaletted(image.Rect(0, 0, anim.Width, anim.Height), palette.Plan9)
		draw.FloydSteinberg.Draw(p, p.Bounds(), frame, image.Point{})
		g.Image = append(g.Image, p)
		g.Delay = append(g.Delay, int(anim.Delays[i]/(10*time.Millisecond)))
		g.Disposal = append(g.Disposal, gif.DisposalBackground)
	}

	dir := os.Getenv("GUNTER_DUMP_DIR")
	if dir == "" {
		dir = t.TempDir()
	}
	gifPath := filepath.Join(dir, "placeholder.gif")
	f, err := os.Create(gifPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := gif.EncodeAll(f, g); err != nil {
		t.Fatal(err)
	}
	f.Close()

	loaded, err := LoadGIF(gifPath)
	if err != nil {
		t.Fatal(err)
	}
	if len(loaded.Frames) != len(anim.Frames) {
		t.Fatalf("got %d frames, want %d", len(loaded.Frames), len(anim.Frames))
	}
	if loaded.Width != anim.Width || loaded.Height != anim.Height {
		t.Fatalf("got %dx%d, want %dx%d", loaded.Width, loaded.Height, anim.Width, anim.Height)
	}
	for i, d := range loaded.Delays {
		if d != anim.Delays[i] {
			t.Fatalf("frame %d delay = %v, want %v", i, d, anim.Delays[i])
		}
	}

	if os.Getenv("GUNTER_DUMP_DIR") != "" {
		pf, err := os.Create(filepath.Join(dir, "frame0.png"))
		if err != nil {
			t.Fatal(err)
		}
		defer pf.Close()
		if err := png.Encode(pf, loaded.Frames[0]); err != nil {
			t.Fatal(err)
		}
	}
}

func TestCellSizeAspect(t *testing.T) {
	anim := &Animation{Width: 96, Height: 96}
	w, h := anim.cellSize(40)
	if w != 40 || h != 20 {
		t.Fatalf("square image at width 40 should be 40x20 cells (1:2 cell aspect), got %dx%d", w, h)
	}
}
