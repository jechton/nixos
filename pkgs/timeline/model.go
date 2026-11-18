package main

import (
	"cmp"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
)

// Doc is a timeline .mmd file. Periods are subgraphs holding events, notes and
// people hang off any period, event, note or person with a dotted link, and
// free notes have no link.
type Doc struct {
	Header   []string // everything before the first period: init, flowchart, classDefs
	Periods  []Period
	Attaches []Attach
	Frees    []Item
}

// Item is any node. Date is optional (periods and events only): see dates.go.
// Color is a tag name from tagColors, events only.
type Item struct{ ID, Text, Date, Color string }

type Period struct {
	Item
	Events []Item
}

// Bare is a period with no title or date: an invisible box, so its events stand alone.
func (p Period) Bare() bool { return p.Text == "" && p.Date == "" }

// Attach is a note or person linked from another item.
type Attach struct {
	Item
	From string
	Kind string   // "note" or "person"
	Also []string // more items this one hangs from, beyond From
}

const defaultHeader = `%%{init: {"flowchart": {"defaultRenderer": "elk"}}}%%
flowchart TB
    classDef event fill:#dbeafe,stroke:#2563eb,color:#111
    classDef note fill:#fef9c3,stroke:#ca8a04,color:#111
    classDef person fill:#dcfce7,stroke:#16a34a,color:#111
    classDef free fill:#f3f4f6,stroke:#6b7280,stroke-dasharray:4 3,color:#111
    classDef period fill:#f9fafb,stroke:#9ca3af,color:#111`

var (
	subRe    = regexp.MustCompile(`^\s*subgraph\s+(\w+)\["(.*)"\]$`)
	endRe    = regexp.MustCompile(`^\s*end$`)
	eventRe  = regexp.MustCompile(`^\s*(\w+)\["(.*)"\]:::event$`)
	freeRe   = regexp.MustCompile(`^\s*(\w+)\["(.*)"\]:::free$`)
	attachRe = regexp.MustCompile(`^\s*(\w+)\s+-\.-\s+(\w+)(?:>"(.*)"\]|\("(.*)"\)):::(note|person)$`)
	linkRe   = regexp.MustCompile(`^\s*(\w+)\s+-\.-\s+(\w+)$`) // another parent for an existing note or person
	// Lines the writer regenerates, so they are dropped on parse.
	spineRe = regexp.MustCompile(`^\s*(-->\s*)?\w+$`)
	classRe = regexp.MustCompile(`^\s*class\s+\S+\s+period$`)
	chainRe = regexp.MustCompile(`^\s*\w+(\s+~~~\s+\w+)+$`) // invisible links that pin event order
	colorRe = regexp.MustCompile(`^\s*class\s+(\w+)\s+tag_(\w+)$`)
	dirRe   = regexp.MustCompile(`^\s*direction LR$`)                        // lays a period's events out in a row
	bareRe  = regexp.MustCompile(`^\s*style\s+\w+\s+fill:none,stroke:none$`) // hides a bare period's box
)

// Parse reads a timeline. It refuses files with lines it would lose on save.
func Parse(text string) (*Doc, error) {
	d := &Doc{}
	var cur *Period
	body := false
	for i, line := range strings.Split(strings.TrimRight(text, "\n"), "\n") {
		trim := strings.TrimSpace(line)
		if !body {
			if subRe.MatchString(line) || strings.Contains(line, "---- PERIODS") || strings.Contains(line, "---- EVENTS") {
				body = true
			} else {
				if !strings.HasPrefix(trim, "classDef tag_") { // Render writes these
					d.Header = append(d.Header, line)
				}
				continue
			}
		}
		switch {
		case trim == "" || strings.HasPrefix(trim, "%%") || strings.HasPrefix(trim, "classDef tag_"): // the last is rewritten by Render
		case subRe.MatchString(line):
			m := subRe.FindStringSubmatch(line)
			p := Period{Item: newItem(m[1], m[2])}
			p.Text = strings.TrimSpace(p.Text)
			d.Periods = append(d.Periods, p)
			cur = &d.Periods[len(d.Periods)-1]
		case endRe.MatchString(line):
			cur = nil
		case cur != nil && eventRe.MatchString(line):
			m := eventRe.FindStringSubmatch(line)
			cur.Events = append(cur.Events, newItem(m[1], m[2]))
		case eventRe.MatchString(line): // outside any box: a standalone event
			m := eventRe.FindStringSubmatch(line)
			e := newItem(m[1], m[2])
			d.Periods = append(d.Periods, Period{Item: Item{ID: "p_" + e.ID}, Events: []Item{e}})
		case attachRe.MatchString(line):
			m := attachRe.FindStringSubmatch(line)
			a := Attach{From: m[1], Kind: m[5], Item: Item{ID: m[2], Text: m[3]}}
			if a.Kind == "person" {
				a.Text = m[4]
			}
			d.Attaches = append(d.Attaches, a)
		case linkRe.MatchString(line):
			m := linkRe.FindStringSubmatch(line)
			at := slices.IndexFunc(d.Attaches, func(a Attach) bool { return a.ID == m[2] })
			if at < 0 {
				return nil, fmt.Errorf("line %d links to %s before it is defined: %s", i+1, m[2], trim)
			}
			d.Attaches[at].Also = append(d.Attaches[at].Also, m[1])
		case freeRe.MatchString(line):
			m := freeRe.FindStringSubmatch(line)
			d.Frees = append(d.Frees, Item{ID: m[1], Text: m[2]})
		case colorRe.MatchString(line):
			m := colorRe.FindStringSubmatch(line)
			if !slices.Contains(tagColors, m[2]) || d.Kind(m[1]) != "event" {
				return nil, fmt.Errorf("line %d not understood, would be lost on save: %s", i+1, trim)
			}
			d.item(m[1]).Color = m[2]
		case spineRe.MatchString(line) || classRe.MatchString(line) || chainRe.MatchString(line) || bareRe.MatchString(line) || dirRe.MatchString(line):
		default:
			return nil, fmt.Errorf("line %d not understood, would be lost on save: %s", i+1, trim)
		}
	}
	for _, a := range d.Attaches {
		for _, from := range append([]string{a.From}, a.Also...) {
			if !d.hasID(from) {
				return nil, fmt.Errorf("%s hangs from %s, which is not in the file", a.ID, from)
			}
		}
	}
	d.Header = trimBlank(d.Header)
	d.splitBare()
	return d, nil
}

// splitBare gives every event in a bare period its own bare period. The spine
// arrows run between periods, so events sharing one would have no arrow.
func (d *Doc) splitBare() {
	for i := 0; i < len(d.Periods); i++ {
		p := d.Periods[i]
		if !p.Bare() || len(p.Events) < 2 {
			continue
		}
		d.Periods[i].Events = p.Events[:1]
		for j, e := range p.Events[1:] {
			bare := Period{Item: Item{ID: d.NewID("p", e.Text)}, Events: []Item{e}}
			d.Periods = slices.Insert(d.Periods, i+1+j, bare)
		}
	}
}

func trimBlank(lines []string) []string {
	for len(lines) > 0 && strings.TrimSpace(lines[len(lines)-1]) == "" {
		lines = lines[:len(lines)-1]
	}
	return lines
}

// Load reads path, or starts a new timeline if the file does not exist.
func Load(path string) (*Doc, error) {
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return Parse(defaultHeader)
	}
	if err != nil {
		return nil, err
	}
	return Parse(string(b))
}

// Render writes the timeline back out.
func (d *Doc) Render() string {
	var b strings.Builder
	line := func(f string, a ...any) { fmt.Fprintf(&b, f+"\n", a...) }
	for _, h := range d.Header {
		line("%s", h)
	}
	line("")
	drawn := map[string]bool{}
	single := map[string][]int{} // attaches with one parent, by parent: the ones that can sit inside a box
	for i, a := range d.Attaches {
		if len(a.Also) == 0 {
			single[a.From] = append(single[a.From], i)
		}
	}
	attach := func(indent string, a Attach) {
		drawn[a.ID] = true
		if a.Kind == "person" {
			line("%s%s -.- %s(\"%s\"):::person", indent, a.From, a.ID, a.Text)
		} else {
			line("%s%s -.- %s>\"%s\"]:::note", indent, a.From, a.ID, a.Text)
		}
		for _, x := range a.Also {
			line("%s%s -.- %s", indent, x, a.ID)
		}
	}
	line("    %%%% ---- EVENTS. A box holds events in the same span. The rest stand alone. ----")
	var spine, boxes []string // spine: what the arrows connect. boxes: titled periods, which share a color.
	for _, p := range d.Periods {
		if p.Bare() { // a standalone event is a plain node, no box
			if len(p.Events) == 0 {
				continue
			}
			e := p.Events[0]
			line("    %s[\"%s\"]:::event", e.ID, e.label())
			spine = append(spine, e.ID)
			continue
		}
		spine, boxes = append(spine, p.ID), append(boxes, p.ID)
		line("    subgraph %s[\"%s\"]", p.ID, p.label())
		line("        direction LR")
		ids := make([]string, len(p.Events))
		for i, e := range p.Events {
			line("        %s[\"%s\"]:::event", e.ID, e.label())
			ids[i] = e.ID
		}
		// The elk renderer orders unlinked nodes arbitrarily, so chain the events invisibly. With direction LR the chain lays them out left to right.
		if len(ids) > 1 {
			line("        %s", strings.Join(ids, " ~~~ "))
		}
		// An edge leaving a box makes elk drop direction LR, so notes and people of a period's events stay inside it.
		// That includes notes hanging from those notes, and so on.
		var inside []int // indexes into d.Attaches, kept in file order
		for queue := slices.Clone(ids); len(queue) > 0; queue = queue[1:] {
			for _, i := range single[queue[0]] {
				inside = append(inside, i)
				queue = append(queue, d.Attaches[i].ID)
			}
		}
		slices.Sort(inside)
		for _, i := range inside {
			attach("        ", d.Attaches[i])
		}
		line("    end")
	}
	if len(spine) > 0 {
		line("")
		line("    %%%% ---- SPINE. Order of the periods and standalone events. ----")
		line("    %s", spine[0])
		for _, id := range spine[1:] {
			line("        --> %s", id)
		}
	}
	if len(boxes) > 0 {
		line("")
		line("    %%%% All periods share one color.")
		line("    class %s period", strings.Join(boxes, ","))
	}
	d.renderColors(line)
	line("")
	line("    %%%% ---- NOTES AND PEOPLE (dotted line) ----")
	for _, a := range d.Attaches {
		if !drawn[a.ID] {
			attach("    ", a)
		}
	}
	line("")
	line("    %%%% ---- FREE NOTES (no link) ----")
	for _, f := range d.Frees {
		line("    %s[\"%s\"]:::free", f.ID, f.Text)
	}
	return b.String()
}

func (d *Doc) Save(path string) error {
	// WriteFile truncates in place, so file watchers (entr) keep working.
	return os.WriteFile(path, []byte(d.Render()), 0o644)
}

// Clean makes text safe inside a quoted label: a double quote would end the string.
func Clean(s string) string { return strings.ReplaceAll(strings.TrimSpace(s), `"`, "'") }

func (d *Doc) hasID(id string) bool {
	for _, p := range d.Periods {
		if p.ID == id {
			return true
		}
		for _, e := range p.Events {
			if e.ID == id {
				return true
			}
		}
	}
	for _, a := range d.Attaches {
		if a.ID == id {
			return true
		}
	}
	for _, f := range d.Frees {
		if f.ID == id {
			return true
		}
	}
	return false
}

var nonSlug = regexp.MustCompile(`[^a-z0-9]+`)

// NewID builds a unique id from a prefix and some text, like n_parents_got_.
func (d *Doc) NewID(prefix, text string) string {
	slug := nonSlug.ReplaceAllString(strings.ToLower(text), "_")
	if len(slug) > 12 {
		slug = slug[:12]
	}
	base := prefix + "_" + slug
	id := base
	for n := 2; d.hasID(id); n++ {
		id = fmt.Sprintf("%s%d", base, n)
	}
	return id
}

// Kind of the item with this id: period, event, note, person, free, or "".
func (d *Doc) Kind(id string) string {
	for _, p := range d.Periods {
		if p.ID == id {
			return "period"
		}
		for _, e := range p.Events {
			if e.ID == id {
				return "event"
			}
		}
	}
	for _, a := range d.Attaches {
		if a.ID == id {
			return a.Kind
		}
	}
	for _, f := range d.Frees {
		if f.ID == id {
			return "free"
		}
	}
	return ""
}

// Where finds an item: period index, event index (-1 for the period itself).
// Notes and people resolve to the item they hang from.
func (d *Doc) Where(id string) (pi, ei int, ok bool) {
	for i := 0; i < len(d.Attaches)+1; i++ { // bounded walk up the attach chain
		for pi, p := range d.Periods {
			if p.ID == id {
				return pi, -1, true
			}
			for ei, e := range p.Events {
				if e.ID == id {
					return pi, ei, true
				}
			}
		}
		next := ""
		for _, a := range d.Attaches {
			if a.ID == id {
				next = a.From
			}
		}
		if next == "" {
			return 0, 0, false
		}
		id = next
	}
	return 0, 0, false
}

func (d *Doc) AddPeriod(after int, title, date, firstEvent string) string {
	p := Period{Item: Item{ID: d.NewID("p", cmp.Or(title, firstEvent)), Text: Clean(title), Date: date}}
	if firstEvent != "" {
		p.Events = []Item{{ID: d.NewID("n", firstEvent), Text: Clean(firstEvent)}}
	}
	d.Periods = append(d.Periods, Period{})
	copy(d.Periods[after+2:], d.Periods[after+1:])
	d.Periods[after+1] = p
	return p.ID
}

// AddEvent inserts at index at of period pi.
func (d *Doc) AddEvent(pi, at int, text, date string) string {
	e := Item{ID: d.NewID("n", text), Text: Clean(text), Date: date}
	if d.Periods[pi].Bare() { // standalone events each get their own period, after this one
		bare := Period{Item: Item{ID: d.NewID("p", text)}, Events: []Item{e}}
		d.Periods = slices.Insert(d.Periods, pi+1, bare)
		return e.ID
	}
	evs := d.Periods[pi].Events
	evs = append(evs, Item{})
	copy(evs[at+1:], evs[at:])
	evs[at] = e
	d.Periods[pi].Events = evs
	return e.ID
}

func (d *Doc) AddAttach(from, kind, label, slugSource string) string {
	a := Attach{From: from, Kind: kind, Item: Item{ID: d.NewID("n", slugSource), Text: label}}
	d.Attaches = append(d.Attaches, a)
	return a.ID
}

func (d *Doc) AddFree(label, slugSource string) string {
	f := Item{ID: d.NewID("n", slugSource), Text: label}
	d.Frees = append(d.Frees, f)
	return f.ID
}

// Cascade lists id and everything that hangs off it: a period takes its
// events, and each removed item takes the notes and people linked from it.
func (d *Doc) Cascade(id string) []string {
	out := []string{id}
	for _, p := range d.Periods {
		if p.ID == id {
			for _, e := range p.Events {
				out = append(out, e.ID)
			}
		}
	}
	for i := 0; i < len(out); i++ { // out grows while we walk it
		for _, a := range d.Attaches {
			if a.From == out[i] {
				out = append(out, a.ID)
			}
		}
	}
	return out
}

// Delete removes id and what hangs from it. A note or person that is also
// linked from a surviving item is kept and moves to that parent.
func (d *Doc) Delete(id string) {
	gone := map[string]bool{}
	for _, g := range d.Cascade(id) {
		gone[g] = true
	}
	for rescued := true; rescued; {
		rescued = false
		for i := range d.Attaches {
			a := &d.Attaches[i]
			if !gone[a.ID] || a.ID == id {
				continue
			}
			if j := slices.IndexFunc(a.Also, func(x string) bool { return !gone[x] }); j >= 0 {
				a.From = a.Also[j]
				a.Also = slices.Delete(a.Also, j, j+1)
				for _, g := range d.Cascade(a.ID) {
					delete(gone, g)
				}
				rescued = true
			}
		}
	}
	for i := range d.Attaches {
		d.Attaches[i].Also = slices.DeleteFunc(d.Attaches[i].Also, func(x string) bool { return gone[x] })
	}
	periods := d.Periods[:0]
	for _, p := range d.Periods {
		if gone[p.ID] {
			continue
		}
		evs := p.Events[:0]
		for _, e := range p.Events {
			if !gone[e.ID] {
				evs = append(evs, e)
			}
		}
		p.Events = evs
		if p.Bare() && len(evs) == 0 { // nothing left to stand alone
			continue
		}
		periods = append(periods, p)
	}
	d.Periods = periods
	attaches := d.Attaches[:0]
	for _, a := range d.Attaches {
		if !gone[a.ID] {
			attaches = append(attaches, a)
		}
	}
	d.Attaches = attaches
	frees := d.Frees[:0]
	for _, f := range d.Frees {
		if !gone[f.ID] {
			frees = append(frees, f)
		}
	}
	d.Frees = frees
}

// item finds any item by id, or nil.
func (d *Doc) item(id string) *Item {
	for i := range d.Periods {
		if d.Periods[i].ID == id {
			return &d.Periods[i].Item
		}
		for j := range d.Periods[i].Events {
			if d.Periods[i].Events[j].ID == id {
				return &d.Periods[i].Events[j]
			}
		}
	}
	for i := range d.Attaches {
		if d.Attaches[i].ID == id {
			return &d.Attaches[i].Item
		}
	}
	for i := range d.Frees {
		if d.Frees[i].ID == id {
			return &d.Frees[i]
		}
	}
	return nil
}

// Text is the raw label of any item, without its date.
func (d *Doc) Text(id string) string {
	if it := d.item(id); it != nil {
		return it.Text
	}
	return ""
}

// SetText changes the label of any item.
func (d *Doc) SetText(id, text string) {
	if it := d.item(id); it != nil {
		it.Text = Clean(text)
	}
}

// Date is the date of a period or event, or "".
func (d *Doc) Date(id string) string {
	if it := d.item(id); it != nil {
		return it.Date
	}
	return ""
}

// SetDate changes the date of a period or event. Callers check ValidDate first.
func (d *Doc) SetDate(id, date string) {
	if it := d.item(id); it != nil && (d.Kind(id) == "period" || d.Kind(id) == "event") {
		if date == "" && d.Kind(id) == "period" && it.Text == "" { // an untitled, undated period is a hidden box, its notes would vanish
			return
		}
		it.Date = date
	}
}

// Move shifts a period or event one step (dir -1 up, +1 down). An event at the
// edge of its period crosses into the neighbouring period. Reports whether it moved.
func (d *Doc) Move(id string, dir int) bool {
	for i, f := range d.Frees {
		if f.ID != id {
			continue
		}
		to := i + dir
		if to < 0 || to >= len(d.Frees) {
			return false
		}
		d.Frees[i], d.Frees[to] = d.Frees[to], d.Frees[i]
		return true
	}
	pi, ei, ok := d.Where(id)
	if !ok || d.Kind(id) == "note" || d.Kind(id) == "person" {
		return false
	}
	if ei == -1 {
		to := pi + dir
		if to < 0 || to >= len(d.Periods) {
			return false
		}
		d.Periods[pi], d.Periods[to] = d.Periods[to], d.Periods[pi]
		return true
	}
	evs := d.Periods[pi].Events
	if to := ei + dir; to >= 0 && to < len(evs) {
		evs[ei], evs[to] = evs[to], evs[ei]
		return true
	}
	np := pi + dir
	inRange := np >= 0 && np < len(d.Periods)
	if !inRange || d.Periods[np].Bare() {
		if d.Periods[pi].Bare() { // a standalone event moves as a whole
			if !inRange {
				return false
			}
			d.Periods[pi], d.Periods[np] = d.Periods[np], d.Periods[pi]
			return true
		}
		// Leaving a period: the event becomes standalone just past its edge.
		e := evs[ei]
		d.Periods[pi].Events = append(evs[:ei:ei], evs[ei+1:]...)
		bare := Period{Item: Item{ID: d.NewID("p", e.Text)}, Events: []Item{e}}
		at := pi
		if dir > 0 {
			at++
		}
		d.Periods = slices.Insert(d.Periods, at, bare)
		return true
	}
	e := evs[ei]
	d.Periods[pi].Events = append(evs[:ei:ei], evs[ei+1:]...)
	if dir > 0 {
		d.Periods[np].Events = append([]Item{e}, d.Periods[np].Events...)
	} else {
		d.Periods[np].Events = append(d.Periods[np].Events, e)
	}
	if d.Periods[pi].Bare() { // the standalone event joined a period, its empty box goes
		d.Periods = slices.Delete(d.Periods, pi, pi+1)
	}
	return true
}

// Person is the four sections of a person node, top to bottom.
type Person struct{ Name, Relation, Pronouns, Notes string }

var (
	nameRe  = regexp.MustCompile(`<b>(.*?)</b>`)
	relRe   = regexp.MustCompile(`<i>(.*?)</i>`)
	notesRe = regexp.MustCompile(`<small>(.*?)</small>`)
)

// Label builds the node text: bold name, italic relation, pronouns, small notes.
// Blank sections are skipped. Notes sit in <small> so they stay distinct from pronouns.
func (p Person) Label() string {
	s := "<b>" + Clean(p.Name) + "</b>"
	if p.Relation != "" {
		s += "<br/><i>" + Clean(p.Relation) + "</i>"
	}
	if p.Pronouns != "" {
		s += "<br/>" + Clean(p.Pronouns)
	}
	if p.Notes != "" {
		s += "<br/><small>" + Clean(p.Notes) + "</small>"
	}
	return s
}

// ParsePerson reads a label back into sections. Older labels without <small>
// notes read as pronouns, then notes.
func ParsePerson(label string) Person {
	var p Person
	grab := func(re *regexp.Regexp, into *string) {
		if m := re.FindStringSubmatch(label); m != nil {
			*into = m[1]
			label = strings.Replace(label, m[0], "", 1)
		}
	}
	grab(nameRe, &p.Name)
	grab(relRe, &p.Relation)
	grab(notesRe, &p.Notes)
	var rest []string
	for _, s := range strings.Split(label, "<br/>") {
		if s != "" {
			rest = append(rest, s)
		}
	}
	if len(rest) > 0 {
		p.Pronouns = rest[0]
	}
	if p.Notes == "" && len(rest) > 1 {
		p.Notes = strings.Join(rest[1:], " ")
	}
	return p
}

// below lists id and everything under it through any link, first parent or extra.
func (d *Doc) below(id string) []string {
	out := []string{id}
	for i := 0; i < len(out); i++ {
		for _, a := range d.Attaches {
			if (a.From == out[i] || slices.Contains(a.Also, out[i])) && !slices.Contains(out, a.ID) {
				out = append(out, a.ID)
			}
		}
	}
	return out
}

// Reattach hangs a note or person from another item. It refuses free notes as
// parents, and loops (a note cannot hang from itself or from something under it).
func (d *Doc) Reattach(id, to string) bool {
	k := d.Kind(id)
	if k != "note" && k != "person" {
		return false
	}
	if d.Kind(to) == "free" || d.Kind(to) == "" || slices.Contains(d.below(id), to) {
		return false
	}
	for i := range d.Attaches {
		if d.Attaches[i].ID == id {
			d.Attaches[i].From = to
		}
	}
	return true
}

// Link hangs a note or person from one more item, so one person can sit under
// several events. Same refusals as Reattach, plus duplicates.
func (d *Doc) Link(id, to string) bool {
	i := slices.IndexFunc(d.Attaches, func(a Attach) bool { return a.ID == id })
	if i < 0 || d.Kind(to) == "free" || d.Kind(to) == "" || slices.Contains(d.below(id), to) {
		return false
	}
	a := &d.Attaches[i]
	if a.From == to || slices.Contains(a.Also, to) {
		return false
	}
	a.Also = append(a.Also, to)
	return true
}

// Unlink drops one parent of a note or person. It refuses to drop the last one.
func (d *Doc) Unlink(id, from string) bool {
	i := slices.IndexFunc(d.Attaches, func(a Attach) bool { return a.ID == id })
	if i < 0 {
		return false
	}
	a := &d.Attaches[i]
	if j := slices.Index(a.Also, from); j >= 0 {
		a.Also = slices.Delete(a.Also, j, j+1)
		return true
	}
	if a.From == from && len(a.Also) > 0 {
		a.From, a.Also = a.Also[0], a.Also[1:]
		return true
	}
	return false
}

// Upto is a copy holding only the first n periods and what hangs from them.
// Free notes are left out, so a slideshow shows them at no step.
func (d *Doc) Upto(n int) *Doc {
	c := &Doc{Header: d.Header, Periods: slices.Clone(d.Periods[:n])}
	kept := map[string]bool{}
	for _, p := range c.Periods {
		kept[p.ID] = true
		for _, e := range p.Events {
			kept[e.ID] = true
		}
	}
	for grew := true; grew; { // notes can hang from notes, so repeat until stable
		grew = false
		for _, a := range d.Attaches {
			if !kept[a.ID] && slices.ContainsFunc(append([]string{a.From}, a.Also...), func(x string) bool { return kept[x] }) {
				kept[a.ID] = true
				grew = true
			}
		}
	}
	for _, a := range d.Attaches {
		if !kept[a.ID] {
			continue
		}
		links := slices.DeleteFunc(append([]string{a.From}, a.Also...), func(x string) bool { return !kept[x] })
		a.From, a.Also = links[0], links[1:]
		c.Attaches = append(c.Attaches, a)
	}
	return c
}
