# Issue 81 simulator evidence

These recordings capture the signed-off vertical Card deck at app commit
`e052476a73bd05af1675874646cb51a6c4d92d01`.

The rank anatomy screenshot captures the rebased rank contract fix at app commit
`f6470a19aa108754816a589c4525dc1ed5400620`.

The typography screenshot captures the real italic Course label, SOFT=100
Fraunces display typography, preserved `35 MIN` anatomy, and gesture-axis UI
check at app commit `0f75e57539960f0d796512040e8bf174221224f6`.

- Simulator: iPhone 17, iOS 27.0 (`24A434`)
- Xcode: 27.0 RC (`27A266a`)
- `standard-motion.webp`: entry teaching motion, signed next/previous Card
  transitions, and one-Card navigation
- `first-touch-cancellation.webp`: stationary touch-down stops the teaching
  motion without navigating or blocking later gestures
- `reduce-motion.webp`: no entry nudge and cross-fade navigation with Reduce
  Motion enabled
- `rank-anatomy-f6470a1.png`: the first Card renders the signed-off `35 MIN`
  rank anatomy from `RecipeCardPresentation.rankValue` and `.rankUnit`
- `typography-0f75e57.png`: the first Card renders lowercase italic Course
  text, SOFT=100 Fraunces display typography, and the preserved `35 MIN` rank
  anatomy
