package main

import (
	"fmt"
	"regexp"
	"slices"
	"strings"
)

// Dates are 1994, 1994-06 or 1994-06-15, optionally as a range ("1990 to 1999").
// They sort correctly as plain text: a shorter date sorts before a longer one
// that starts with it.
const dateP = `\d{4}(?:-(?:0[1-9]|1[0-2])(?:-(?:0[1-9]|[12]\d|3[01]))?)?`

var (
	validDateRe = regexp.MustCompile(`^` + dateP + `(?: to ` + dateP + `)?$`)
	// A dated label is stored as "<small>DATE</small><br/>text".
	labelDateRe = regexp.MustCompile(`^<small>(` + dateP + `(?: to ` + dateP + `)?)</small><br/>(.*)$`)
)

func ValidDate(s string) bool { return validDateRe.MatchString(s) }

// newItem reads a label, splitting off its date.
func newItem(id, label string) Item {
	if m := labelDateRe.FindStringSubmatch(label); m != nil {
		return Item{ID: id, Date: m[1], Text: m[2]}
	}
	return Item{ID: id, Text: label}
}

// label is the text written into the file.
func (i Item) label() string {
	if i.Date == "" {
		return i.Text
	}
	return "<small>" + i.Date + "</small><br/>" + i.Text
}

// sortDated orders the dated entries by start date. Undated entries stay where they are.
func sortDated[T any](xs []T, date func(T) string) {
	var slots []int
	var dated []T
	for i, x := range xs {
		if date(x) != "" {
			slots, dated = append(slots, i), append(dated, x)
		}
	}
	start := func(x T) string { s, _, _ := strings.Cut(date(x), " to "); return s }
	slices.SortStableFunc(dated, func(a, b T) int { return strings.Compare(start(a), start(b)) })
	for k, i := range slots {
		xs[i] = dated[k]
	}
}

// SortByDate orders periods, and the events inside each, by date.
func (d *Doc) SortByDate() {
	sortDated(d.Periods, func(p Period) string { return p.Date })
	for i := range d.Periods {
		sortDated(d.Periods[i].Events, func(e Item) string { return e.Date })
	}
}

// tagColors are the colors an event can be tagged with, in the order t cycles them.
// Each maps to a classDef written by renderColors.
var tagColors = []string{"red", "orange", "green", "blue", "purple"}

var tagFills = map[string]string{
	"red": "#fee2e2,stroke:#dc2626", "orange": "#ffedd5,stroke:#ea580c", "green": "#d1fae5,stroke:#059669",
	"blue": "#bfdbfe,stroke:#1d4ed8", "purple": "#ede9fe,stroke:#7c3aed",
}

// renderColors writes a classDef for each color in use, then one class line per tagged event.
func (d *Doc) renderColors(line func(string, ...any)) {
	used := map[string]bool{}
	var tagged []string
	for _, p := range d.Periods {
		for _, e := range p.Events {
			if e.Color != "" {
				used[e.Color] = true
				tagged = append(tagged, fmt.Sprintf("    class %s tag_%s", e.ID, e.Color))
			}
		}
	}
	if len(tagged) == 0 {
		return
	}
	line("")
	line("    %%%% ---- COLOR TAGS ----")
	for _, c := range tagColors {
		if used[c] {
			line("    classDef tag_%s fill:%s,color:#111", c, tagFills[c])
		}
	}
	for _, t := range tagged {
		line("%s", t)
	}
}

// CycleColor moves an event to the next color, and back to none after the last.
func (d *Doc) CycleColor(id string) bool {
	if d.Kind(id) != "event" {
		return false
	}
	it := d.item(id)
	next := slices.Index(tagColors, it.Color) + 1 // no color is -1, so this starts at 0
	if next == len(tagColors) {
		it.Color = ""
	} else {
		it.Color = tagColors[next]
	}
	return true
}

// Duplicate copies an event, note, person or free note and returns the copy's id,
// or "" for a period. An event copy sits right after the original.
func (d *Doc) Duplicate(id string) string {
	switch d.Kind(id) {
	case "event":
		pi, ei, _ := d.Where(id)
		it := *d.item(id)
		copyID := d.AddEvent(pi, ei+1, it.Text, it.Date)
		d.item(copyID).Color = it.Color
		return copyID
	case "note", "person":
		for _, a := range d.Attaches {
			if a.ID == id {
				return d.AddAttach(a.From, a.Kind, a.Text, a.Text)
			}
		}
	case "free":
		return d.AddFree(d.Text(id), d.Text(id))
	}
	return ""
}
