import Testing

// Eye tracking is an experimental feature. Its estimation and geometry maths are
// known to be incomplete, and the expectations tagged with the comments below
// currently fail. They are marked as known issues rather than deleted or
// disabled: the tests still run, still document the intended behavior, and
// swift-testing will fail the run if one of them starts passing — which is the
// signal that the underlying work has landed and the marker should come off.
//
// Nothing outside the eye-tracking feature depends on these paths.

/// `FallbackGazeEstimator.estimatedGaze` does not advance down the page as time
/// passes: `screenPosition.y` holds its initial value regardless of elapsed time
/// or `arabicWordsPerMinute`, so progression, speed, resume, and reset all
/// observe the same static point.
let experimentalGazeProgression: Comment = """
Experimental eye tracking: FallbackGazeEstimator's estimated gaze does not \
progress over time — screenPosition.y stays at its initial value.
"""

/// `GazeToVerseMapper` resolves gaze to a verse only for the portrait geometry it
/// was configured with; in landscape, and after an orientation change, mapping
/// returns nil instead of a line/verse.
let experimentalLandscapeMapping: Comment = """
Experimental eye tracking: GazeToVerseMapper returns nil in landscape and after \
an orientation change.
"""

/// `GazeToVerseMapper` does not fall back to the nearest verse when the gaze
/// lands between two verses, returning nil rather than the closer one.
let experimentalNearestVerseFallback: Comment = """
Experimental eye tracking: GazeToVerseMapper does not fall back to the nearest \
verse when gaze lands between two verses.
"""

/// `ReadingProgressTracker` keeps reporting line 0 after `updateGeometry` for a
/// rotated page, rather than the line the gaze actually falls on.
let experimentalRotationTracking: Comment = """
Experimental eye tracking: ReadingProgressTracker still reports line 0 after a \
geometry update for a rotated page.
"""
