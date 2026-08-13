package main

import (
	"fmt"
	"time"

	termimg "github.com/blacktop/go-termimg"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// tuiModel embeds the animation inside a live Bubble Tea view: frames are
// pre-rendered escape strings and a tea.Tick at each frame's native delay
// advances the index. Everything around the image is ordinary lipgloss text,
// proving the animation coexists with a real TUI.
type tuiModel struct {
	frames []string
	delays []time.Duration
	proto  termimg.Protocol
	idx    int
	ticks  int
}

type frameMsg struct{}

var (
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("212"))
	statusStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
)

func newTUIModel(anim *Animation, widthCells int) (tuiModel, error) {
	proto := resolveProtocol()
	frames, err := renderFrames(anim, widthCells, proto)
	if err != nil {
		return tuiModel{}, err
	}
	return tuiModel{frames: frames, delays: anim.Delays, proto: proto}, nil
}

func (m tuiModel) tick() tea.Cmd {
	return tea.Tick(m.delays[m.idx], func(time.Time) tea.Msg { return frameMsg{} })
}

func (m tuiModel) Init() tea.Cmd {
	return m.tick()
}

func (m tuiModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case frameMsg:
		m.idx = (m.idx + 1) % len(m.frames)
		m.ticks++
		return m, m.tick()
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m tuiModel) View() string {
	header := titleStyle.Render("♪ Gunter's dance party ♪")
	footer := statusStyle.Render(fmt.Sprintf(
		"protocol: %s   frame: %d/%d   ticks: %d   q to quit",
		m.proto, m.idx+1, len(m.frames), m.ticks,
	))
	// The image frame sits on its own lines, un-wrapped by lipgloss: layout
	// helpers measure strings by cell width and would mis-handle the pixel
	// protocols' escape sequences.
	return header + "\n\n" + m.frames[m.idx] + "\n" + footer + "\n"
}

func runTUI(anim *Animation, widthCells int) error {
	m, err := newTUIModel(anim, widthCells)
	if err != nil {
		return err
	}
	p := tea.NewProgram(m, tea.WithAltScreen())
	_, err = p.Run()
	if m.proto == termimg.Kitty {
		fmt.Print(kittyDeleteAll)
	}
	return err
}
