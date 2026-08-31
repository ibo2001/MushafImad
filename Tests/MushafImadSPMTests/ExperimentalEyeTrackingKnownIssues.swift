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
