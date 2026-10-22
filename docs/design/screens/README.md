# Signed-off boards

One PNG per board signed off in the design canvas (linked from #15), exported
at 2× from the canvas. File name: `<screen>-<state>.png`, e.g.
`cooking-step.png`, `cooking-step-timer.png`. The matching rules live in
[`../karta-v1.md`](../karta-v1.md); when the PNG and the text disagree, the
text wins and the PNG is re-exported in the same PR.

The cooking boards (#101) are drawn on the device they will run on: an iPhone 17,
402 × 874 pt, with the Dynamic Island and home-indicator safe areas hatched, so
the PNGs are 804 × 1748. A board that leaves the safe areas out hides overflow.

A UI issue is `ready-for-agent` only once its boards are here (`AGENTS.md` →
*Design gate*).
