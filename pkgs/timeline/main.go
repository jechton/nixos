// timeline is a terminal editor for Mermaid timeline files: periods holding
// events, with notes and people attached by dotted links. See model.go for the format.
package main

import (
	"cmp"
	"fmt"
	"maps"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type row struct {
	id, kind string
	parent   string // the item this row hangs from, for notes and people
	depth    int
	text     string // plain text, without the date
	date     string
	linked   bool   // shown again under an extra parent
	color    string // event tag, see tagColors
}

var tagRe = regexp.MustCompile(`</?(b|i|small)>`)

// plain turns a label into one line of readable text.
func plain(s string) string {
	return tagRe.ReplaceAllString(strings.ReplaceAll(s, "<br/>", " | "), "")
}

func (d *Doc) addChildren(from string, depth int, out []row) []row {
	for _, a := range d.Attaches {
		switch {
		case a.From == from:
			out = append(out, row{id: a.ID, kind: a.Kind, parent: from, depth: depth, text: plain(a.Text)})
			out = d.addChildren(a.ID, depth+1, out)
		case slices.Contains(a.Also, from): // shown again here, its own children only under the first parent
			out = append(out, row{id: a.ID, kind: a.Kind, parent: from, depth: depth, text: plain(a.Text), linked: true})
		}
	}
	return out
}

// Rows flattens the doc into the lines shown on screen.
func (d *Doc) Rows() []row {
	var out []row
	for _, p := range d.Periods {
		out = append(out, row{id: p.ID, kind: "period", text: plain(p.Text), date: p.Date})
		out = d.addChildren(p.ID, 1, out)
		for _, e := range p.Events {
			out = append(out, row{id: e.ID, kind: "event", depth: 1, text: plain(e.Text), date: e.Date, color: e.Color})
			out = d.addChildren(e.ID, 2, out)
		}
	}
	for _, f := range d.Frees {
		out = append(out, row{id: f.ID, kind: "free", text: plain(f.Text)})
	}
	return out
}

type mode int

const (
	browse mode = iota
	typing
	confirm
	pickParent // choosing a parent for the note in pending: a new one, or one more if linking
	menu       // the add menu: waiting for p, e, n, w or f
	help       // the key list, any key closes it
)

// keysHelp is the key list, shown by ? and by --help.
const keysHelp = `Add (press a, then)
  p  period       e  event       n  note
  w  person       f  free note

Edit
  r or enter  edit the item     d  delete (asks first)
  y  duplicate the item     t  cycle an event color

Move
  up/down or j/k  move the cursor
  J/K or shift+up/down  move the item down or up
  m  re-attach a note or person to a new parent

Links
  space  mark notes and people, then l links all marked
  l  link a note or person to one more parent
  x  remove the link under the cursor

View
  /  search     s  sort by date
  g  jump to a date
  ?  this list  q  quit

Undo
  u  undo       ctrl+r  redo`

// dateLabel starts every date prompt, see updateTyping.
const dateLabel = "Date, optional (1994, 1994-06-15, 1990 to 1999)"

type prompt struct{ label, initial string }

type model struct {
	doc     *Doc
	path    string
	rows    []row
	cursor  int
	offset  int
	height  int
	width   int
	mode    mode
	prompts []prompt
	step    int
	answers []string
	input   textinput.Model
	finish  func(a []string) string // returns the id to put the cursor on
	pending string                  // id awaiting delete confirmation, or the note being re-attached
	undo    []string                // rendered files from before each change
	redo    []string                // files set aside by undo, cleared by any new change
	query   string                  // last search
	linking bool                    // pickParent adds a link instead of moving the note
	marked  map[string]bool         // notes and people picked with space, linked together by l
	batch   []string                // what pickParent links, when linking
	status  string
}

var (
	kindStyle = map[string]lipgloss.Style{
		"period": lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("12")),
		"event":  lipgloss.NewStyle(),
		"note":   lipgloss.NewStyle().Foreground(lipgloss.Color("3")),
		"person": lipgloss.NewStyle().Foreground(lipgloss.Color("2")),
		"free":   lipgloss.NewStyle().Foreground(lipgloss.Color("8")),
	}
	marker  = map[string]string{"period": "▸ ", "event": "• ", "note": "┄ ", "person": "☺ ", "free": "◇ "}
	dim     = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	cursor  = lipgloss.NewStyle().Reverse(true)
	tagAnsi = map[string]string{"red": "1", "orange": "9", "green": "10", "blue": "4", "purple": "5"}
	bold    = lipgloss.NewStyle().Bold(true)
	box     = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("12")).Padding(0, 1)
)

// statusStyle colors a message by its wording: errors red, questions yellow, success green.
func statusStyle(s string) lipgloss.Style {
	color := "2"
	switch {
	case strings.HasSuffix(s, "y/n") || strings.HasPrefix(s, "move to"):
		color = "3"
	default:
		for _, bad := range []string{"cannot", "failed", "must", "no match", "pick ", "nothing to", "only link", "no row"} {
			if strings.Contains(s, bad) {
				color = "1"
			}
		}
	}
	return lipgloss.NewStyle().Foreground(lipgloss.Color(color))
}

func newModel(doc *Doc, path string) *model {
	m := &model{doc: doc, path: path, height: 24, input: textinput.New()}
	m.input.CharLimit = 300
	m.rows = doc.Rows()
	return m
}

func (m *model) Init() tea.Cmd { return nil }

// refresh redraws the rows, saves, and moves the cursor to focus.
func (m *model) refresh(focus string) {
	if err := m.doc.Save(m.path); err != nil {
		m.status = "save failed: " + err.Error()
	}
	m.rows = m.doc.Rows()
	for i, r := range m.rows {
		if r.id == focus {
			m.cursor = i
		}
	}
	m.cursor = max(0, min(m.cursor, len(m.rows)-1))
}

func (m *model) current() (row, bool) {
	if m.cursor < 0 || m.cursor >= len(m.rows) {
		return row{}, false
	}
	return m.rows[m.cursor], true
}

func (m *model) ask(prompts []prompt, finish func(a []string) string) tea.Cmd {
	m.mode, m.prompts, m.step, m.answers, m.finish = typing, prompts, 0, nil, finish
	m.status = ""
	return m.showPrompt()
}

func (m *model) showPrompt() tea.Cmd {
	p := m.prompts[m.step]
	m.input.Prompt = p.label + ": "
	m.input.SetValue(p.initial)
	m.input.CursorEnd()
	return m.input.Focus()
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.height, m.width = msg.Height, msg.Width
		m.input.Width = max(10, msg.Width-20)
		return m, nil
	case tea.KeyMsg:
		switch m.mode {
		case menu:
			return m.updateMenu(msg)
		case help:
			m.mode = browse
			return m, nil
		case typing:
			return m.updateTyping(msg)
		case confirm:
			return m.updateConfirm(msg)
		case pickParent:
			return m.updatePickParent(msg)
		}
		return m.updateBrowse(msg)
	}
	return m, nil
}

func (m *model) updateTyping(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "esc":
		m.mode = browse
		m.status = "cancelled"
		return m, nil
	case "enter":
		val := strings.TrimSpace(m.input.Value())
		if m.step == 0 && val == "" {
			return m, nil // the first answer is required
		}
		// Date prompts are the ones labelled "Date...".
		if strings.HasPrefix(m.prompts[m.step].label, "Date") && val != "" && !ValidDate(val) {
			m.status = "date must look like 1994, 1994-06, 1994-06-15 or 1990 to 1999"
			return m, nil
		}
		m.answers = append(m.answers, val)
		m.step++
		if m.step < len(m.prompts) {
			return m, m.showPrompt()
		}
		before := m.doc.Render()
		focus := m.finish(m.answers)
		m.mode = browse
		m.remember(before) // only if the answers changed something, so a search adds no undo step
		m.refresh(focus)
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	return m, cmd
}

// remember saves the file text from before a change, unless nothing changed.
func (m *model) remember(before string) {
	if m.doc.Render() != before {
		m.undo = append(m.undo, before)
		m.redo = nil
	}
}

// offerEmpty asks to delete the period with this id if it has no events left.
func (m *model) offerEmpty(periodID string) {
	for _, p := range m.doc.Periods {
		if p.ID == periodID && len(p.Events) == 0 {
			m.pending, m.mode = p.ID, confirm
			m.status = fmt.Sprintf("Period %q is empty. Delete it too? y/n", plain(p.Text))
		}
	}
}

// periodOf is the id of the period holding event id, or "".
func (m *model) periodOf(id string) string {
	if pi, ei, ok := m.doc.Where(id); ok && ei >= 0 && m.doc.Kind(id) == "event" {
		return m.doc.Periods[pi].ID
	}
	return ""
}

func (m *model) updateConfirm(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	m.mode = browse
	if msg.String() != "y" {
		m.status = "kept"
		return m, nil
	}
	before, src := m.doc.Render(), m.periodOf(m.pending)
	m.doc.Delete(m.pending)
	m.remember(before)
	m.status = "deleted (u to undo)"
	m.refresh("")
	m.offerEmpty(src)
	return m, nil
}

func (m *model) updatePickParent(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "up", "k":
		m.cursor = max(0, m.cursor-1)
	case "down", "j":
		m.cursor = min(len(m.rows)-1, m.cursor+1)
	case "esc":
		m.mode, m.status = browse, "cancelled"
	case "enter":
		r, ok := m.current()
		before := m.doc.Render()
		m.mode = browse
		link := m.doc.Reattach
		if m.linking {
			link = m.doc.Link
		}
		linked := 0
		for _, id := range m.batch {
			if ok && link(id, r.id) {
				linked++
			}
		}
		if linked == 0 {
			m.status = "cannot attach there"
			return m, nil
		}
		m.marked = nil
		m.remember(before)
		m.status = fmt.Sprintf("%d done (u to undo)", linked)
		m.refresh(m.batch[0])
	}
	return m, nil
}

// jump finds the first row dated on or after date (a prefix like 1994 works).
func (m *model) jump(date string) string {
	for _, r := range m.rows {
		start, _, _ := strings.Cut(r.date, " to ")
		if start != "" && start >= date {
			return r.id
		}
	}
	m.status = "no row at or after that date"
	return ""
}

// search moves the cursor to the next row containing the last query, wrapping around.
func (m *model) search() string {
	q := strings.ToLower(m.query)
	for i := 1; i <= len(m.rows); i++ {
		r := m.rows[(m.cursor+i)%len(m.rows)]
		if strings.Contains(strings.ToLower(r.date+" "+r.text), q) {
			return r.id
		}
	}
	m.status = "no match"
	return ""
}

func joinLines(first, second string) string {
	if second == "" {
		return Clean(first)
	}
	return Clean(first) + "<br/>" + Clean(second)
}

func (m *model) updateBrowse(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	r, ok := m.current()
	m.status = ""
	switch msg.String() {
	case "q", "ctrl+c":
		return m, tea.Quit
	case "up", "k":
		m.cursor = max(0, m.cursor-1)
	case "down", "j":
		m.cursor = min(len(m.rows)-1, m.cursor+1)
	case "a":
		m.mode = menu
	case "?":
		m.mode = help
	case " ":
		if !ok || (r.kind != "note" && r.kind != "person") {
			m.status = "pick a note or person to mark"
			return m, nil
		}
		if m.marked == nil {
			m.marked = map[string]bool{}
		}
		m.marked[r.id] = !m.marked[r.id]
		if !m.marked[r.id] {
			delete(m.marked, r.id)
		}
		m.cursor = min(len(m.rows)-1, m.cursor+1)
	case "y", "t":
		before, focus := m.doc.Render(), r.id
		switch {
		case !ok:
		case msg.String() == "y":
			focus = m.doc.Duplicate(r.id)
		case m.doc.CycleColor(r.id):
			m.status = "color: " + cmp.Or(m.doc.item(r.id).Color, "none")
		default:
			focus = ""
		}
		if focus == "" {
			m.status = "cannot do that here (y: not a period. t: events only)"
			return m, nil
		}
		m.remember(before)
		m.refresh(focus)
	case "g":
		return m, m.ask([]prompt{{"Jump to date", ""}}, func(a []string) string { return m.jump(a[0]) })
	case "enter", "r":
		if !ok {
			return m, nil
		}
		if r.kind == "person" {
			return m, m.ask(personPrompts(ParsePerson(m.doc.Text(r.id))),
				func(a []string) string { m.doc.SetText(r.id, personFrom(a).Label()); return r.id })
		}
		if r.kind == "period" || r.kind == "event" {
			return m, m.ask([]prompt{{"Text", m.doc.Text(r.id)}, {dateLabel, m.doc.Date(r.id)}},
				func(a []string) string {
					m.doc.SetText(r.id, a[0])
					m.doc.SetDate(r.id, a[1])
					return r.id
				})
		}
		return m, m.ask([]prompt{{"Text", m.doc.Text(r.id)}},
			func(a []string) string { m.doc.SetText(r.id, a[0]); return r.id })
	case "J", "K", "shift+down", "shift+up":
		dir := 1
		if msg.String() == "K" || msg.String() == "shift+up" {
			dir = -1
		}
		before, src := m.doc.Render(), m.periodOf(r.id)
		if !ok || !m.doc.Move(r.id, dir) {
			m.status = "cannot move that way (notes follow their parent)"
			return m, nil
		}
		m.remember(before)
		m.refresh(r.id)
		m.offerEmpty(src)
	case "u":
		m.travel(&m.undo, &m.redo, "undo")
	case "ctrl+r":
		m.travel(&m.redo, &m.undo, "redo")
	case "/":
		return m, m.ask([]prompt{{"Search", m.query}}, func(a []string) string {
			m.query = a[0]
			return m.search()
		})
	case "s":
		before := m.doc.Render()
		m.doc.SortByDate()
		m.remember(before)
		m.status = "sorted by date (u to undo)"
		m.refresh(r.id)
	case "l", "x":
		if !ok || (r.kind != "note" && r.kind != "person") {
			m.status = "pick a note or person first"
			return m, nil
		}
		if msg.String() == "l" {
			m.batch = []string{r.id}
			if len(m.marked) > 0 {
				m.batch = slices.Sorted(maps.Keys(m.marked))
			}
			m.mode, m.linking = pickParent, true
			m.status = "move to the extra parent, enter to link, esc to cancel"
			return m, nil
		}
		before := m.doc.Render()
		if !m.doc.Unlink(r.id, r.parent) {
			m.status = "that is its only link, use d to delete it"
			return m, nil
		}
		m.remember(before)
		m.status = "unlinked (u to undo)"
		m.refresh(r.id)
	case "m":
		if !ok || (r.kind != "note" && r.kind != "person") {
			m.status = "pick a note or person to re-attach"
			return m, nil
		}
		m.batch, m.mode, m.linking = []string{r.id}, pickParent, false
		m.status = "move to the new parent, enter to confirm, esc to cancel"
	case "d":
		if !ok {
			return m, nil
		}
		m.pending, m.mode = r.id, confirm
		m.status = fmt.Sprintf("Delete %q and %d attached item(s)? y/n", r.text, len(m.doc.Cascade(r.id))-1)
	}
	return m, nil
}

// updateMenu runs the add action for the key pressed, relative to the row under the cursor.
func (m *model) updateMenu(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	m.mode = browse
	r, ok := m.current()
	needsParent := !ok || r.kind == "free"
	switch msg.String() {
	case "p":
		after := len(m.doc.Periods) - 1
		if pi, _, found := m.doc.Where(r.id); ok && found {
			after = pi
		}
		return m, m.ask([]prompt{{"Period", ""}, {dateLabel, ""}, {"First event", ""}},
			func(a []string) string { return m.doc.AddPeriod(after, a[0], a[1], a[2]) })
	case "e":
		pi, ei, found := m.doc.Where(r.id)
		if !ok || !found {
			m.status = "pick a period or event first"
			return m, nil
		}
		at := ei + 1 // ei is -1 on a period row, so this adds at its top
		return m, m.ask([]prompt{{"Event", ""}, {dateLabel, ""}},
			func(a []string) string { return m.doc.AddEvent(pi, at, a[0], a[1]) })
	case "n", "w":
		if needsParent {
			m.status = "pick a period, event, note or person to attach to"
			return m, nil
		}
		if msg.String() == "w" {
			return m, m.ask(personPrompts(Person{}),
				func(a []string) string { return m.doc.AddAttach(r.id, "person", personFrom(a).Label(), a[0]) })
		}
		return m, m.ask([]prompt{{"Line 1", ""}, {"Line 2 (optional)", ""}},
			func(a []string) string { return m.doc.AddAttach(r.id, "note", joinLines(a[0], a[1]), a[0]) })
	case "f":
		return m, m.ask([]prompt{{"Line 1", ""}, {"Line 2 (optional)", ""}},
			func(a []string) string { return m.doc.AddFree(joinLines(a[0], a[1]), a[0]) })
	}
	m.status = "cancelled"
	return m, nil
}

func personPrompts(p Person) []prompt {
	return []prompt{{"Name", p.Name}, {"Relation (optional)", p.Relation}, {"Pronouns (optional)", p.Pronouns}, {"Notes (optional)", p.Notes}}
}

func personFrom(a []string) Person { return Person{a[0], a[1], a[2], a[3]} }

// isLastAttach reports whether the note or person at rows[i] is the last one hanging from its parent.
func isLastAttach(rows []row, i int) bool {
	for _, n := range rows[i+1:] {
		if n.depth < rows[i].depth {
			return true
		}
		if n.depth == rows[i].depth {
			return n.kind != "note" && n.kind != "person"
		}
	}
	return true
}

// header is the file name on the left and the counts on the right.
func (m *model) header() string {
	events := 0
	for _, p := range m.doc.Periods {
		events += len(p.Events)
	}
	left := bold.Render(filepath.Base(m.path))
	right := dim.Render(fmt.Sprintf("%d periods  %d events", len(m.doc.Periods), events))
	gap := max(2, m.width-lipgloss.Width(left)-lipgloss.Width(right))
	return left + strings.Repeat(" ", gap) + right
}

// line is one row on screen: dim date column, tree guide, marker, text.
func (m *model) line(i, dateWidth int) string {
	r := m.rows[i]
	date := ""
	if dateWidth > 0 {
		date = fmt.Sprintf("%-*s  ", dateWidth, r.date)
	}
	indent := strings.Repeat("  ", r.depth)
	if r.kind == "note" || r.kind == "person" {
		guide := "├ "
		if isLastAttach(m.rows, i) {
			guide = "└ "
		}
		indent = strings.Repeat("  ", r.depth-1) + guide
	}
	text := marker[r.kind] + r.text
	if r.linked {
		text += " ↔"
	}
	if m.marked[r.id] {
		text += " ✓"
	}
	style := kindStyle[r.kind]
	if r.color != "" {
		style = style.Foreground(lipgloss.Color(tagAnsi[r.color]))
	}
	if i == m.cursor && m.mode != typing {
		return cursor.Render(date + indent + text)
	}
	return dim.Render(date+indent) + style.Render(text)
}

func (m *model) View() string {
	if m.mode == help {
		return box.Render(keysHelp) + "\n" + dim.Render("any key closes")
	}
	var b strings.Builder
	b.WriteString(m.header() + "\n\n")
	dateWidth := 0
	for _, r := range m.rows {
		dateWidth = max(dateWidth, len(r.date))
	}
	room := max(3, m.height-10)
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+room {
		m.offset = m.cursor - room + 1
	}
	end := min(len(m.rows), m.offset+room)
	for i := m.offset; i < end; i++ {
		b.WriteString(m.line(i, dateWidth) + "\n")
	}
	if len(m.rows) == 0 {
		b.WriteString(dim.Render("empty: press a then p to add a period") + "\n")
	}
	b.WriteString("\n")
	status := statusStyle(m.status).Render(m.status)
	switch m.mode {
	case typing:
		title := ""
		if len(m.prompts) > 1 {
			title = dim.Render(fmt.Sprintf("%d of %d", m.step+1, len(m.prompts))) + "\n"
		}
		b.WriteString(status + "\n" + box.Render(title+m.input.View()) + "\n" + dim.Render("enter next, esc cancel"))
	case menu:
		b.WriteString(box.Render("add:  p period   e event   n note   w person   f free note") + "\n" + dim.Render("esc cancel"))
	default:
		b.WriteString(status + "\n" + dim.Render("a add  r edit  d delete  u undo  ? keys  q quit"))
	}
	return b.String()
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "timeline:", err)
	os.Exit(1)
}

const usage = `usage:
  timeline file.mmd                  edit
  timeline live file.mmd             edit, with a live preview window beside it
  timeline present file.mmd          slideshow
  timeline export file.mmd out.png   render to png, svg or pdf
  timeline --help                    this text

keys in the editor:
` + keysHelp

func main() {
	args := os.Args[1:]
	if len(args) > 0 && slices.Contains([]string{"-h", "--help", "help"}, args[0]) {
		fmt.Println(usage)
		return
	}
	cmd := "edit"
	if len(args) > 0 && slices.Contains([]string{"live", "present", "export"}, args[0]) {
		cmd, args = args[0], args[1:]
	}
	if len(args) != map[bool]int{true: 2, false: 1}[cmd == "export"] {
		fmt.Fprintln(os.Stderr, usage)
		os.Exit(1)
	}
	path := args[0]
	if cmd == "export" {
		out, err := exec.Command("mmdc", "-i", path, "-o", args[1], "-b", "white", "-s", "2", "-q").CombinedOutput()
		if err != nil {
			fail(fmt.Errorf("mmdc: %v\n%s", err, out))
		}
		return
	}
	doc, err := Load(path)
	if err != nil {
		fail(err)
	}
	if cmd == "present" {
		if err := present(doc); err != nil {
			fail(err)
		}
		return
	}
	backup(path)
	if cmd == "live" {
		// A second terminal window redraws the diagram on every save, see mermaid-preview.
		preview := exec.Command("ghostty", "-e", "mermaid-preview", path)
		if err := preview.Start(); err != nil {
			fail(fmt.Errorf("preview window: %v", err))
		}
		defer func() { _ = preview.Process.Kill() }()
	}
	if _, err := tea.NewProgram(newModel(doc, path), tea.WithAltScreen()).Run(); err != nil {
		fail(err)
	}
}

// backup copies the file to path.bak once per session, before any edit.
func backup(path string) {
	if data, err := os.ReadFile(path); err == nil {
		_ = os.WriteFile(path+".bak", data, 0o644)
	}
}

// travel restores the newest snapshot in from, and keeps the current file in to
// so the step can be reversed. Used for both undo and redo.
func (m *model) travel(from, to *[]string, name string) {
	if len(*from) == 0 {
		m.status = "nothing to " + name
		return
	}
	doc, err := Parse((*from)[len(*from)-1])
	if err != nil {
		m.status = name + " failed: " + err.Error()
		return
	}
	*to = append(*to, m.doc.Render())
	*from = (*from)[:len(*from)-1]
	m.doc = doc
	m.status = name + " done"
	m.refresh("")
}
