package main

import (
	"slices"
	"strings"
	"testing"
)

const sample = defaultHeader + `

    subgraph p_a["A"]
        e1["one"]:::event
        e2["two"]:::event
    end
    subgraph p_b["B"]
        e3["three"]:::event
    end

    p_a
        --> p_b

    class p_a,p_b period
    e1 -.- dad("<b>Dad</b><br/><i>Dad</i>"):::person
    p_b -.- n1>"on a period"]:::note
    dad -.- n2>"on a person"]:::note
    free1["loose"]:::free
`

func ids(d *Doc) []string {
	var out []string
	for _, r := range d.Rows() {
		out = append(out, r.id)
	}
	return out
}

func TestRoundTrip(t *testing.T) {
	d, err := Parse(sample)
	if err != nil {
		t.Fatal(err)
	}
	again, err := Parse(d.Render())
	if err != nil {
		t.Fatal(err)
	}
	if d.Render() != again.Render() {
		t.Fatal("render is not stable")
	}
	if got := strings.Join(ids(d), " "); got != "p_a dad n2 e1 e2 p_b n1 e3 free1" && got != "p_a e1 dad n2 e2 p_b n1 e3 free1" {
		t.Fatalf("rows: %s", got)
	}
}

func TestRefusesUnknownLines(t *testing.T) {
	if _, err := Parse(sample + "    style e1 fill:#fff\n"); err == nil {
		t.Fatal("expected an error for a line that would be lost")
	}
}

func TestDeleteCascades(t *testing.T) {
	d, _ := Parse(sample)
	d.Delete("p_a") // takes e1, e2, dad, and dad's note
	if got := strings.Join(ids(d), " "); got != "p_b n1 e3 free1" {
		t.Fatalf("after delete: %s", got)
	}
	if strings.Contains(d.Render(), "p_a") {
		t.Fatal("p_a still in output")
	}
}

func TestMove(t *testing.T) {
	d, _ := Parse(sample)
	if !d.Move("e2", 1) { // last event of A crosses into the top of B
		t.Fatal("no move")
	}
	if !slices.Equal(evIDs(d.Periods[1]), []string{"e2", "e3"}) {
		t.Fatalf("B events: %v", evIDs(d.Periods[1]))
	}
	if !d.Move("p_a", 1) || d.Periods[0].ID != "p_b" {
		t.Fatal("period did not move")
	}
	if d.Move("p_b", -1) {
		t.Fatal("moved past the top")
	}
	if !strings.Contains(d.Render(), "    p_b\n        --> p_a") {
		t.Fatal("spine not rewritten")
	}
}

func evIDs(p Period) []string {
	var out []string
	for _, e := range p.Events {
		out = append(out, e.ID)
	}
	return out
}

func TestAddKeepsOrderAndUniqueIDs(t *testing.T) {
	d, _ := Parse(sample)
	d.AddEvent(0, 1, "one", "") // after e1; slug n_one is new
	d.AddEvent(0, 1, "one", "") // same text: id must not collide
	if got := evIDs(d.Periods[0]); len(got) != 4 || got[0] != "e1" || got[1] == got[2] {
		t.Fatalf("events: %v", got)
	}
	d.AddPeriod(0, "2001", "", "start")
	if d.Periods[1].Text != "2001" {
		t.Fatal("period not inserted after A")
	}
}

func TestPersonRoundTrip(t *testing.T) {
	for _, p := range []Person{
		{"Dad", "Father", "he/him", "Lives far away"},
		{"Dad", "", "", "Only notes"},
		{"Dad", "Father", "", ""},
		{"Dad", "", "he/him", ""},
	} {
		if got := ParsePerson(p.Label()); got != p {
			t.Fatalf("want %+v got %+v", p, got)
		}
	}
	legacy := ParsePerson("<b>Name</b><br/><i>Dad</i><br/>he/him<br/>Notes here")
	if legacy != (Person{"Name", "Dad", "he/him", "Notes here"}) {
		t.Fatalf("legacy: %+v", legacy)
	}
}

func TestReattachRefusesLoops(t *testing.T) {
	d, _ := Parse(sample)
	if d.Reattach("dad", "n2") { // n2 hangs from dad
		t.Fatal("allowed a loop")
	}
	if d.Reattach("dad", "free1") {
		t.Fatal("allowed a free note as parent")
	}
	if !d.Reattach("n1", "e3") || d.Attaches[1].From != "e3" {
		t.Fatal("reattach failed")
	}
}

func TestUptoKeepsOnlyEarlierPeriods(t *testing.T) {
	d, _ := Parse(sample)
	c := d.Upto(1)
	if got := strings.Join(ids(c), " "); got != "p_a dad n2 e1 e2" && got != "p_a e1 dad n2 e2" {
		t.Fatalf("slide 1: %s", got)
	}
	if len(c.Frees) != 0 || len(d.Periods) != 2 {
		t.Fatal("free notes kept or original changed")
	}
}

func TestMoveFree(t *testing.T) {
	d, _ := Parse(sample)
	d.AddFree("second", "second")
	if !d.Move(d.Frees[1].ID, -1) || d.Frees[0].Text != "second" {
		t.Fatal("free note did not move")
	}
}

func TestDates(t *testing.T) {
	for _, ok := range []string{"1994", "1994-06", "1994-06-15", "1990 to 1999", "1994-06 to 1995"} {
		if !ValidDate(ok) {
			t.Fatalf("%q should be valid", ok)
		}
	}
	for _, bad := range []string{"", "94", "1994-13", "1994-06-32", "June 1994", "1994 to"} {
		if ValidDate(bad) {
			t.Fatalf("%q should be invalid", bad)
		}
	}
	d, _ := Parse(sample)
	d.SetDate("e1", "1994-06")
	d.SetDate("p_b", "1990 to 1999")
	d.SetDate("dad", "1994") // not a period or event: ignored
	again, err := Parse(d.Render())
	if err != nil {
		t.Fatal(err)
	}
	if again.Date("e1") != "1994-06" || again.Text("e1") != "one" || again.Date("p_b") != "1990 to 1999" || again.Date("dad") != "" {
		t.Fatalf("dates lost: %q %q %q", again.Date("e1"), again.Text("e1"), again.Date("p_b"))
	}
}

func TestSortByDateKeepsUndated(t *testing.T) {
	d, _ := Parse(sample)
	d.AddEvent(0, 2, "third", "")
	d.SetDate("e1", "1995-02")
	d.SetDate("e2", "1995")
	d.SortByDate() // e2 (year only) sorts before e1 (month), the undated event stays last
	if got := evIDs(d.Periods[0]); got[0] != "e2" || got[1] != "e1" || len(got) != 3 {
		t.Fatalf("events: %v", got)
	}
}

func TestMultiLink(t *testing.T) {
	d, _ := Parse(sample)
	if !d.Link("dad", "e2") || d.Link("dad", "e2") || d.Link("dad", "e1") {
		t.Fatal("link rules")
	}
	if d.Link("dad", "n2") { // n2 hangs from dad
		t.Fatal("allowed a loop")
	}
	again, err := Parse(d.Render())
	if err != nil || len(again.Attaches[0].Also) != 1 {
		t.Fatalf("link lost: %v", err)
	}
	// Deleting the first parent keeps dad, now under e2, with his note.
	d.Delete("e1")
	if d.Kind("dad") != "person" || d.Kind("n2") != "note" || d.Attaches[0].From != "e2" {
		t.Fatal("dad should move to e2")
	}
	if !d.Link("dad", "e3") || !d.Unlink("dad", "e2") || d.Attaches[0].From != "e3" || d.Unlink("dad", "e3") {
		t.Fatal("unlink rules")
	}
	d.Delete("e3") // last parent: dad goes
	if d.Kind("dad") != "" {
		t.Fatal("dad should be gone")
	}
}

func TestUptoTrimsLinks(t *testing.T) {
	d, _ := Parse(sample)
	d.Link("dad", "e3") // e3 is in period B
	c := d.Upto(1)
	if len(c.Attaches[0].Also) != 0 || strings.Contains(c.Render(), "e3 -.- dad") {
		t.Fatal("link to a hidden period leaked")
	}
}

func TestUndoRedo(t *testing.T) {
	d, _ := Parse(sample)
	m := newModel(d, t.TempDir()+"/t.mmd")
	before := m.doc.Render()
	m.doc.Delete("p_a")
	m.remember(before)
	after := m.doc.Render()
	m.travel(&m.undo, &m.redo, "undo")
	if m.doc.Render() != before {
		t.Fatal("undo did not restore")
	}
	m.travel(&m.redo, &m.undo, "redo")
	if m.doc.Render() != after {
		t.Fatal("redo did not reapply")
	}
	m.travel(&m.undo, &m.redo, "undo")
	m.remember(m.doc.Render() + " ") // a new change clears redo
	if len(m.redo) != 0 {
		t.Fatal("redo kept after a new change")
	}
}

func TestLastAttachGuide(t *testing.T) {
	d, _ := Parse(sample)
	rows := d.Rows()
	last := map[string]bool{}
	for i, r := range rows {
		if r.kind == "note" || r.kind == "person" {
			last[r.id] = isLastAttach(rows, i)
		}
	}
	// n1 is the only child of p_b, n2 the only child of dad, dad the only child of e1.
	if !last["n1"] || !last["n2"] || !last["dad"] {
		t.Fatalf("single children should be last: %v", last)
	}
	d.AddAttach("e1", "note", "second", "second")
	rows = d.Rows()
	for i, r := range rows {
		if r.id == "dad" && isLastAttach(rows, i) {
			t.Fatal("dad has a sibling after it")
		}
	}
}

func TestColorsRoundTrip(t *testing.T) {
	d, _ := Parse(sample)
	if !d.CycleColor("e1") || d.CycleColor("dad") || d.item("e1").Color != "red" {
		t.Fatal("cycle rules")
	}
	out := d.Render()
	if !strings.Contains(out, "classDef tag_red") || !strings.Contains(out, "class e1 tag_red") {
		t.Fatal("color not written")
	}
	again, err := Parse(out)
	if err != nil || again.item("e1").Color != "red" || again.Render() != out {
		t.Fatalf("color lost or unstable: %v", err)
	}
	for range tagColors {
		d.CycleColor("e1")
	}
	if d.item("e1").Color != "" || strings.Contains(d.Render(), "tag_") {
		t.Fatal("cycle should end at none")
	}
}

func TestDuplicate(t *testing.T) {
	d, _ := Parse(sample)
	d.SetDate("e1", "1994")
	d.CycleColor("e1")
	cp := d.Duplicate("e1")
	if got := evIDs(d.Periods[0]); got[1] != cp || d.Date(cp) != "1994" || d.item(cp).Color != "red" {
		t.Fatalf("event copy: %v", got)
	}
	if n := d.Duplicate("dad"); d.Kind(n) != "person" || d.Attaches[len(d.Attaches)-1].From != "e1" {
		t.Fatal("person copy")
	}
	if d.Duplicate("p_a") != "" {
		t.Fatal("periods are not copied")
	}
}

func TestJump(t *testing.T) {
	d, _ := Parse(sample)
	d.SetDate("e2", "1995-03")
	d.SetDate("e3", "1999")
	m := newModel(d, t.TempDir()+"/t.mmd")
	if m.jump("1995") != "e2" || m.jump("1996") != "e3" || m.jump("2001") != "" {
		t.Fatal("jump")
	}
}

func TestEventOrderChain(t *testing.T) {
	d, err := Parse(defaultHeader + "\n    subgraph p[\"1990s\"]\n        a[\"A\"]:::event\n        b[\"B\"]:::event\n        c[\"C\"]:::event\n    end\n")
	if err != nil {
		t.Fatal(err)
	}
	out := d.Render()
	if !strings.Contains(out, "a ~~~ b ~~~ c") {
		t.Fatalf("no chain in output:\n%s", out)
	}
	again, err := Parse(out)
	if err != nil || again.Render() != out {
		t.Fatalf("chain does not round-trip: %v", err)
	}
}
