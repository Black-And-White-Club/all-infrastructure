package main

import (
	"image"
	"image/color"
	"math"
	"time"
)

// Placeholder builds a small dancing-penguin animation with the standard
// library so the demo runs without any GIF on disk. Pass your own
// gunter.gif on the command line for the real thing.
func Placeholder() *Animation {
	const (
		size      = 96
		numFrames = 12
	)
	anim := &Animation{Width: size, Height: size}

	for f := 0; f < numFrames; f++ {
		t := float64(f) / numFrames
		img := image.NewRGBA(image.Rect(0, 0, size, size))
		drawPenguin(img, t)
		anim.Frames = append(anim.Frames, img)
		anim.Delays = append(anim.Delays, 90*time.Millisecond)
	}
	return anim
}

var (
	penguinBlack = color.RGBA{24, 24, 30, 255}
	penguinWhite = color.RGBA{240, 240, 245, 255}
	penguinBeak  = color.RGBA{255, 165, 40, 255}
	penguinEye   = color.RGBA{10, 10, 12, 255}
)

// drawPenguin draws one dance pose at phase t in [0,1): the body sways side
// to side while the flippers flap in opposite phase and the head bobs.
func drawPenguin(img *image.RGBA, t float64) {
	sway := int(6 * math.Sin(2*math.Pi*t))
	bob := int(2 * math.Sin(4*math.Pi*t))
	flap := int(8 * math.Sin(2*math.Pi*t))

	cx := 48 + sway

	// feet stay planted while the body moves
	fillEllipse(img, 38, 88, 9, 4, penguinBeak)
	fillEllipse(img, 58, 88, 9, 4, penguinBeak)

	// flippers behind the body, flapping in anti-phase
	fillEllipse(img, cx-28, 58+flap, 6, 15, penguinBlack)
	fillEllipse(img, cx+28, 58-flap, 6, 15, penguinBlack)

	// body + belly
	fillEllipse(img, cx, 56+bob, 26, 32, penguinBlack)
	fillEllipse(img, cx, 63+bob, 18, 23, penguinWhite)

	// eyes + pupils looking in the direction of the sway
	fillEllipse(img, cx-9, 38+bob, 5, 6, penguinWhite)
	fillEllipse(img, cx+9, 38+bob, 5, 6, penguinWhite)
	fillEllipse(img, cx-9+sway/3, 39+bob, 2, 3, penguinEye)
	fillEllipse(img, cx+9+sway/3, 39+bob, 2, 3, penguinEye)

	// beak
	fillEllipse(img, cx, 48+bob, 6, 3, penguinBeak)
}

func fillEllipse(img *image.RGBA, cx, cy, rx, ry int, c color.RGBA) {
	for dy := -ry; dy <= ry; dy++ {
		for dx := -rx; dx <= rx; dx++ {
			nx := float64(dx) / float64(rx)
			ny := float64(dy) / float64(ry)
			if nx*nx+ny*ny <= 1.0 {
				img.SetRGBA(cx+dx, cy+dy, c)
			}
		}
	}
}
