package main

import (
	"image"
	"image/color"
	"math"
	"time"
)

// Placeholder builds a small dancing-penguin animation styled after a certain
// Adventure-Time ice-dwelling penguin, drawn entirely with the standard
// library so the demo runs without any GIF on disk. Pass your own gunter.gif
// on the command line for the real thing.
func Placeholder() *Animation {
	const (
		size      = 128
		numFrames = 12
	)
	anim := &Animation{Width: size, Height: size}

	for f := 0; f < numFrames; f++ {
		t := float64(f) / numFrames
		img := image.NewRGBA(image.Rect(0, 0, size, size))
		drawBackground(img)
		drawPenguin(img, t)
		anim.Frames = append(anim.Frames, img)
		anim.Delays = append(anim.Delays, 90*time.Millisecond)
	}
	return anim
}

var (
	inkBlack   = color.RGBA{27, 34, 56, 255} // dark navy outline/back
	bellyWhite = color.RGBA{250, 250, 248, 255}
	beakYellow = color.RGBA{248, 200, 40, 255}
	beakShadow = color.RGBA{170, 120, 20, 255}
	feetYellow = color.RGBA{250, 210, 45, 255}
	skyBlue    = color.RGBA{118, 203, 235, 255}
	hillGreen  = color.RGBA{140, 198, 78, 255}
	hillDark   = color.RGBA{112, 175, 58, 255}
	plankBrown = color.RGBA{178, 121, 62, 255}
	plankEdge  = color.RGBA{140, 92, 44, 255}
)

// drawBackground paints the sky, rolling hills, and the wooden plank Gunter
// dances on.
func drawBackground(img *image.RGBA) {
	fillRect(img, 0, 0, 128, 74, skyBlue)
	fillRect(img, 0, 74, 128, 100, hillGreen)
	fillEllipse(img, 20, 76, 42, 14, hillDark)
	fillEllipse(img, 108, 78, 46, 16, hillDark)
	fillRect(img, 0, 100, 128, 103, plankEdge)
	fillRect(img, 0, 103, 128, 128, plankBrown)
}

// drawPenguin draws one dance pose at phase t in [0,1): the body sways while
// one flipper waves overhead, the other rests at the chest, and the head bobs.
// Feet stay planted on the plank.
func drawPenguin(img *image.RGBA, t float64) {
	sway := int(4 * math.Sin(2*math.Pi*t))
	bob := int(2 * math.Sin(4*math.Pi*t))
	wave := 0.9 + 0.9*math.Sin(2*math.Pi*t) // waving flipper angle, radians

	cx := 64 + sway
	cy := 62 + bob

	// feet first so the body overlaps their tops
	fillEllipse(img, 52, 102, 10, 5, feetYellow)
	fillEllipse(img, 76, 102, 10, 5, feetYellow)

	// waving flipper: swings from the right shoulder up over the head
	tipX := cx + 24 + int(20*math.Cos(wave))
	tipY := cy - 6 - int(26*math.Sin(wave))
	drawLimb(img, cx+24, cy-4, tipX, tipY, 6, inkBlack)

	// resting flipper: bent in toward the chest
	drawLimb(img, cx-26, cy-2, cx-14, cy+14, 6, inkBlack)

	// body: dark egg with a big white front reaching up around the eyes
	fillEllipse(img, cx, cy, 30, 36, inkBlack)
	fillEllipse(img, cx, cy+4, 24, 31, bellyWhite)
	fillEllipse(img, cx, cy-12, 19, 15, bellyWhite) // face patch

	// sleepy eyes: outlined white ovals with heavy closed lids
	drawEye(img, cx-11, cy-14)
	drawEye(img, cx+11, cy-14)

	// open beak pointing off to the side, mid-quack
	fillTriangle(img, cx-24, cy-2, cx-2, cy-10, cx-2, cy+2, beakYellow)
	fillTriangle(img, cx-19, cy-2, cx-4, cy-5, cx-4, cy-1, beakShadow)
}

// drawEye draws one white eye oval with an outline and a curved shut lid.
func drawEye(img *image.RGBA, ex, ey int) {
	fillEllipse(img, ex, ey, 9, 10, inkBlack)
	fillEllipse(img, ex, ey, 8, 9, bellyWhite)
	// closed lid: a thick downward-curving lash line across the upper eye
	for dx := -7; dx <= 7; dx++ {
		lidY := ey - 4 + int(float64(dx*dx)/12.0)
		fillEllipse(img, ex+dx, lidY, 1, 1, inkBlack)
	}
}

// drawLimb draws a thick capsule between two points out of overlapping discs.
func drawLimb(img *image.RGBA, x0, y0, x1, y1, r int, c color.RGBA) {
	steps := int(math.Hypot(float64(x1-x0), float64(y1-y0))) + 1
	for i := 0; i <= steps; i++ {
		f := float64(i) / float64(steps)
		x := x0 + int(f*float64(x1-x0))
		y := y0 + int(f*float64(y1-y0))
		fillEllipse(img, x, y, r, r, c)
	}
}

func fillRect(img *image.RGBA, x0, y0, x1, y1 int, c color.RGBA) {
	for y := y0; y < y1; y++ {
		for x := x0; x < x1; x++ {
			img.SetRGBA(x, y, c)
		}
	}
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

// fillTriangle rasterizes a filled triangle using barycentric sign tests.
func fillTriangle(img *image.RGBA, x0, y0, x1, y1, x2, y2 int, c color.RGBA) {
	minX, maxX := min3(x0, x1, x2), max3(x0, x1, x2)
	minY, maxY := min3(y0, y1, y2), max3(y0, y1, y2)
	edge := func(ax, ay, bx, by, px, py int) int {
		return (bx-ax)*(py-ay) - (by-ay)*(px-ax)
	}
	for y := minY; y <= maxY; y++ {
		for x := minX; x <= maxX; x++ {
			w0 := edge(x1, y1, x2, y2, x, y)
			w1 := edge(x2, y2, x0, y0, x, y)
			w2 := edge(x0, y0, x1, y1, x, y)
			if (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0) {
				img.SetRGBA(x, y, c)
			}
		}
	}
}

func min3(a, b, c int) int { return min(a, min(b, c)) }
func max3(a, b, c int) int { return max(a, max(b, c)) }
