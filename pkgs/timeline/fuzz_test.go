// Random edits must never panic, and what Render writes must parse back and render the same.
package main

import (
	"math/rand"
	"testing"
)

func TestEditsKeepFileStable(t *testing.T) {
	for seed := int64(0); seed < 300; seed++ {
		r := rand.New(rand.NewSource(seed))
		d, _ := Parse(defaultHeader)
		var log []string
		ids := func() []string {
			var out []string
			for _, p := range d.Periods {
				if !p.Bare() {
					out = append(out, p.ID)
				}
				for _, e := range p.Events {
					out = append(out, e.ID)
				}
			}
			for _, a := range d.Attaches {
				out = append(out, a.ID)
			}
			for _, f := range d.Frees {
				out = append(out, f.ID)
			}
			return out
		}
		pick := func() string {
			x := ids()
			if len(x) == 0 {
				return ""
			}
			return x[r.Intn(len(x))]
		}
		dates := []string{"", "1990", "2001-05", "mid 1990s", "late 2002"}
		func() {
			defer func() {
				if e := recover(); e != nil {
					t.Fatalf("seed %d panic %v ops %v", seed, e, log)
				}
			}()
			for i := 0; i < 25; i++ {
				id := pick()
				op := r.Intn(14)
				log = append(log, string(rune('a'+op))+":"+id)
				switch op {
				case 0:
					d.AddPeriod(len(d.Periods)-1, []string{"", "Era"}[r.Intn(2)], dates[r.Intn(5)], []string{"ev", ""}[r.Intn(2)]+string(rune('a'+r.Intn(5))))
				case 1:
					if len(d.Periods) > 0 {
						pi := r.Intn(len(d.Periods))
						d.AddEvent(pi, 0, "e"+string(rune('a'+r.Intn(5))), dates[r.Intn(5)])
					}
				case 2:
					if id != "" && d.Kind(id) != "free" {
						d.AddAttach(id, "note", "nt", "nt")
					}
				case 3:
					d.AddFree("fr", "fr")
				case 4, 5:
					if id != "" {
						d.Move(id, []int{-1, 1}[r.Intn(2)])
					}
				case 6:
					if id != "" {
						d.Delete(id)
					}
				case 7:
					if id != "" {
						d.Duplicate(id)
					}
				case 8:
					d.SortByDate()
				case 9:
					if id != "" {
						d.CycleColor(id)
					}
				case 10:
					d.Link(pick(), pick())
				case 11:
					d.Reattach(pick(), pick())
				case 12:
					d.Unlink(pick(), pick())
				case 13:
					if id != "" {
						d.SetDate(id, dates[r.Intn(5)])
					}
				}
				out := d.Render()
				d2, err := Parse(out)
				if err != nil {
					t.Fatalf("seed %d parse err %v ops %v\n%s", seed, err, log, out)
				}
				if out2 := d2.Render(); out2 != out {
					t.Fatalf("seed %d not stable ops %v\n%s\n----\n%s", seed, log, out, out2)
				}
				d.Rows()
			}
		}()
	}
}
