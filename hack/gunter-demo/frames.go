package main

import (
	"fmt"
	"image"
	"image/draw"
	"image/gif"
	"os"
	"time"
)

// Animation is a decoded, coalesced animation: every frame is a full
// standalone image (GIF frames on disk are often partial diffs).
type Animation struct {
	Frames []image.Image
	Delays []time.Duration
	Width  int // pixel width of the logical screen
	Height int // pixel height of the logical screen
}

// LoadGIF decodes an animated GIF from disk and coalesces its frames.
func LoadGIF(path string) (*Animation, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	g, err := gif.DecodeAll(f)
	if err != nil {
		return nil, fmt.Errorf("decoding %s: %w", path, err)
	}
	if len(g.Image) == 0 {
		return nil, fmt.Errorf("%s contains no frames", path)
	}
	return coalesce(g), nil
}

// coalesce composites each (possibly partial) GIF frame onto a persistent
// canvas, honoring the per-frame disposal method, so every output frame is a
// complete picture that can be rendered independently.
func coalesce(g *gif.GIF) *Animation {
	w, h := g.Config.Width, g.Config.Height
	if w == 0 || h == 0 {
		b := g.Image[0].Bounds()
		w, h = b.Max.X, b.Max.Y
	}

	canvas := image.NewRGBA(image.Rect(0, 0, w, h))
	anim := &Animation{Width: w, Height: h}
	var saved *image.RGBA

	for i, frame := range g.Image {
		disposal := byte(gif.DisposalNone)
		if i < len(g.Disposal) {
			disposal = g.Disposal[i]
		}
		if disposal == gif.DisposalPrevious {
			saved = image.NewRGBA(canvas.Rect)
			copy(saved.Pix, canvas.Pix)
		}

		draw.Draw(canvas, frame.Bounds(), frame, frame.Bounds().Min, draw.Over)

		snap := image.NewRGBA(canvas.Rect)
		copy(snap.Pix, canvas.Pix)
		anim.Frames = append(anim.Frames, snap)
		anim.Delays = append(anim.Delays, frameDelay(g, i))

		switch disposal {
		case gif.DisposalBackground:
			draw.Draw(canvas, frame.Bounds(), image.Transparent, image.Point{}, draw.Src)
		case gif.DisposalPrevious:
			if saved != nil {
				copy(canvas.Pix, saved.Pix)
			}
		}
	}
	return anim
}

// frameDelay converts a GIF delay (centiseconds) to a duration. Delays of
// 0–10ms are a historical artifact meaning "as fast as possible"; browsers
// clamp those to 100ms, and so do we.
func frameDelay(g *gif.GIF, i int) time.Duration {
	delay := 0
	if i < len(g.Delay) {
		delay = g.Delay[i]
	}
	d := time.Duration(delay) * 10 * time.Millisecond
	if d <= 10*time.Millisecond {
		d = 100 * time.Millisecond
	}
	return d
}

// cellSize converts the animation's pixel aspect ratio into terminal cell
// dimensions for a requested width, assuming the common 1:2 cell aspect.
func (a *Animation) cellSize(widthCells int) (int, int) {
	if widthCells < 1 {
		widthCells = 1
	}
	h := int(float64(widthCells)*float64(a.Height)/float64(a.Width)/2.0 + 0.5)
	if h < 1 {
		h = 1
	}
	return widthCells, h
}
