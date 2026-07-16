package generator

import "testing"

func TestRampFraction(t *testing.T) {
	tests := []struct {
		name                string
		elapsed, ramp, want float64
	}{
		{"zero elapsed", 0, 10, 0},
		{"quarter way", 2.5, 10, 0.25},
		{"half way", 5, 10, 0.5},
		{"complete at ramp end", 10, 10, 1},
		{"clamps beyond ramp end", 15, 10, 1},
		{"ramp seconds zero completes instantly", 0, 0, 1},
		{"ramp seconds negative completes instantly", 5, -1, 1},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := rampFraction(tc.elapsed, tc.ramp)
			if got != tc.want {
				t.Errorf("rampFraction(%v, %v) = %v, want %v", tc.elapsed, tc.ramp, got, tc.want)
			}
		})
	}
}

// TestAccumulateNoSystematicLoss checks that carrying the fractional
// remainder across many ticks yields a total dispatch count that tracks the
// nominal rps*time exactly, rather than losing the fractional part every
// tick.
func TestAccumulateNoSystematicLoss(t *testing.T) {
	const rps = 7.3
	const tickSeconds = 0.1
	const ticks = 10000

	carry := 0.0
	total := 0
	for i := 0; i < ticks; i++ {
		var count int
		count, carry = accumulate(rps, tickSeconds, carry)
		total += count
	}

	want := rps * tickSeconds * ticks // 7300.0
	diff := float64(total) - want
	if diff < -1 || diff > 1 {
		t.Fatalf("total dispatched over %d ticks = %d, want within 1 of %v", ticks, total, want)
	}

	// Truncating every tick instead of carrying the remainder would lose
	// floor(0.3 * ticks) requests here (0.7 dispatched per tick vs 0.73
	// nominal); make sure we're nowhere near that degraded total.
	perTick := rps * tickSeconds
	truncatedOnly := 0
	for i := 0; i < ticks; i++ {
		truncatedOnly += int(perTick)
	}
	if total <= truncatedOnly {
		t.Fatalf("accumulated total %d did not improve on naive truncation total %d", total, truncatedOnly)
	}
}

// TestAccumulateExactPattern pins down the carry behaviour for a simple
// rate: 2.5 rps at a 0.1s tick is exactly 0.25 requests/tick, so over 8
// ticks the carried remainder must produce exactly 2 dispatched requests
// (8 * 0.25 = 2.0), not 0 (if truncated every tick) or some other drift.
func TestAccumulateExactPattern(t *testing.T) {
	const rps = 2.5
	const tickSeconds = 0.1
	const ticks = 8
	const wantTotal = 2

	carry := 0.0
	total := 0
	for i := 0; i < ticks; i++ {
		var count int
		count, carry = accumulate(rps, tickSeconds, carry)
		total += count
	}

	if total != wantTotal {
		t.Fatalf("total dispatched over %d ticks = %d, want %d", ticks, total, wantTotal)
	}
}

func TestAccumulateRemainderNeverNegativeOrOverOne(t *testing.T) {
	const rps = 3.7
	const tickSeconds = 0.1

	carry := 0.0
	for i := 0; i < 1000; i++ {
		_, carry = accumulate(rps, tickSeconds, carry)
		if carry < 0 || carry >= 1 {
			t.Fatalf("tick %d: carry = %v, want in [0,1)", i, carry)
		}
	}
}
