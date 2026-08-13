// gunter-demo renders an animated GIF (a dancing Gunter, ideally) in the
// terminal at real pixel quality using whichever graphics protocol the
// terminal supports: kitty (Ghostty/kitty/WezTerm), iTerm2, sixel, or a
// universal ANSI halfblock fallback.
//
// Usage:
//
//	gunter-demo [flags] [detect|splash|tui] [gunter.gif]
//
// With no GIF argument a built-in placeholder penguin animation is used.
package main

import (
	"flag"
	"fmt"
	"os"

	termimg "github.com/blacktop/go-termimg"
)

func main() {
	width := flag.Int("width", 40, "animation width in terminal cells")
	loops := flag.Int("loops", 0, "splash mode: number of loops (0 = until keypress)")
	flag.Usage = usage
	flag.Parse()

	cmd := "tui"
	gifPath := ""
	for _, arg := range flag.Args() {
		switch arg {
		case "detect", "splash", "tui":
			cmd = arg
		default:
			gifPath = arg
		}
	}

	if err := run(cmd, gifPath, *width, *loops); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run(cmd, gifPath string, width, loops int) error {
	if cmd == "detect" {
		return runDetect()
	}

	anim, err := loadAnimation(gifPath)
	if err != nil {
		return err
	}

	switch cmd {
	case "splash":
		return runSplash(anim, width, loops)
	default:
		return runTUI(anim, width)
	}
}

func loadAnimation(gifPath string) (*Animation, error) {
	if gifPath == "" {
		fmt.Fprintln(os.Stderr, "no GIF given — using built-in placeholder penguin (pass a path to your gunter.gif)")
		return Placeholder(), nil
	}
	return LoadGIF(gifPath)
}

func runDetect() error {
	fmt.Printf("TERM=%s TERM_PROGRAM=%s\n", os.Getenv("TERM"), os.Getenv("TERM_PROGRAM"))
	fmt.Printf("detected protocol: %s\n", termimg.DetectProtocol())
	fmt.Printf("all supported:     %v\n", termimg.DetermineProtocols())
	fmt.Println()
	fmt.Println("kitty protocol → full 24-bit pixel quality (Ghostty, kitty, WezTerm, Konsole)")
	fmt.Println("iTerm2         → full quality inline images (iTerm2, WezTerm)")
	fmt.Println("sixel          → paletted/dithered (xterm, foot, Windows Terminal 1.22+)")
	fmt.Println("halfblocks     → blocky ANSI fallback, works in any color terminal")
	return nil
}

func usage() {
	fmt.Fprintf(os.Stderr, `usage: gunter-demo [flags] [command] [gunter.gif]

commands:
  tui      play the animation inside a Bubble Tea UI (default)
  splash   play the animation as a raw fullscreen splash
  detect   report which graphics protocol this terminal supports

flags:
`)
	flag.PrintDefaults()
}
