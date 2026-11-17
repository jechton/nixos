package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// present shows the timeline as a slideshow in the terminal. Slide n holds the
// first n periods and what hangs from them. Needs mmdc and chafa on PATH.
func present(doc *Doc) error {
	dir, err := os.MkdirTemp("", "timeline-present")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)

	total := len(doc.Periods)
	if total == 0 {
		return fmt.Errorf("no periods to present")
	}
	in := bufio.NewReader(os.Stdin)
	for n := 1; n <= total; {
		src, png := filepath.Join(dir, "s.mmd"), filepath.Join(dir, "s.png")
		if err := os.WriteFile(src, []byte(doc.Upto(n).Render()), 0o644); err != nil {
			return err
		}
		if out, err := exec.Command("mmdc", "-i", src, "-o", png, "-b", "white", "-s", "2", "-q").CombinedOutput(); err != nil {
			return fmt.Errorf("mmdc: %v\n%s", err, out)
		}
		fmt.Print("\x1b[2J\x1b[H")
		show := exec.Command("chafa", "-f", "kitty", png)
		show.Stdout = os.Stdout
		if err := show.Run(); err != nil {
			return fmt.Errorf("chafa: %v", err)
		}
		fmt.Printf("\n%d/%d  enter next, b back, q quit: ", n, total)
		line, err := in.ReadString('\n')
		switch cmd := strings.TrimSpace(line); {
		case err != nil || cmd == "q":
			return nil
		case cmd == "b" && n > 1:
			n--
		case cmd != "b":
			n++
		}
	}
	return nil
}
