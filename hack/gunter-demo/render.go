package main

import (
	"fmt"

	termimg "github.com/blacktop/go-termimg"
)

// kittyDeleteAll removes every image and placement the terminal is holding
// for us. Each rendered frame transmits a new kitty image, so emit this when
// playback stops to release terminal-side memory.
const kittyDeleteAll = "\x1b_Ga=d,d=A,q=2\x1b\\"

// renderFrames pre-encodes every animation frame to a protocol escape string
// at the given cell width. Encoding (PNG + base64 for kitty/iTerm2, palette
// quantization for sixel) is the expensive part, so it happens once up front
// instead of on every tick.
func renderFrames(anim *Animation, widthCells int, proto termimg.Protocol) ([]string, error) {
	wc, hc := anim.cellSize(widthCells)
	frames := make([]string, 0, len(anim.Frames))
	for i, frame := range anim.Frames {
		s, err := termimg.New(frame).
			Protocol(proto).
			Width(wc).
			Height(hc).
			Render()
		if err != nil {
			return nil, fmt.Errorf("rendering frame %d via %s: %w", i, proto, err)
		}
		frames = append(frames, s)
	}
	return frames, nil
}

// resolveProtocol picks the best protocol the terminal supports, falling
// back to halfblocks (plain ANSI, works everywhere) when nothing pixel-based
// is detected.
func resolveProtocol() termimg.Protocol {
	p := termimg.DetectProtocol()
	if p == termimg.Unsupported || p == termimg.Auto {
		return termimg.Halfblocks
	}
	return p
}
