package main

import (
	"fmt"
	"os"
	"time"

	termimg "github.com/blacktop/go-termimg"
	"golang.org/x/term"
)

// runSplash plays the animation outside any TUI framework: raw terminal,
// alternate screen, cursor homed between frames. This is the most robust way
// to show pixel graphics because no framework re-render can mangle the
// escape sequences. loops=0 plays until a key is pressed.
func runSplash(anim *Animation, widthCells, loops int) error {
	proto := resolveProtocol()
	frames, err := renderFrames(anim, widthCells, proto)
	if err != nil {
		return err
	}

	fd := int(os.Stdin.Fd())
	var oldState *term.State
	if term.IsTerminal(fd) {
		oldState, err = term.MakeRaw(fd)
		if err != nil {
			return fmt.Errorf("entering raw mode: %w", err)
		}
	}

	// alt screen + hide cursor; restored on exit
	fmt.Print("\x1b[?1049h\x1b[?25l")
	defer func() {
		if proto == termimg.Kitty {
			fmt.Print(kittyDeleteAll)
		}
		fmt.Print("\x1b[?25h\x1b[?1049l")
		if oldState != nil {
			_ = term.Restore(fd, oldState)
		}
	}()

	// any keypress stops playback
	stop := make(chan struct{})
	go func() {
		buf := make([]byte, 1)
		_, _ = os.Stdin.Read(buf)
		close(stop)
	}()

	label := fmt.Sprintf("  dancing via %s — press any key to stop", proto)
	for loop := 0; loops == 0 || loop < loops; loop++ {
		for i, frame := range frames {
			// home the cursor and redraw in place
			fmt.Print("\x1b[H")
			fmt.Print(frame)
			fmt.Print("\r\n" + label)
			select {
			case <-stop:
				return nil
			case <-time.After(anim.Delays[i]):
			}
		}
	}
	return nil
}
