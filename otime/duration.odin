package otime

import "core:time"

NANO :: time.Duration(1)
MICRO :: time.Duration(1e3)
MILLI :: time.Duration(1e6)
SECOND :: time.Duration(1e9)

duration_as :: #force_inline proc "contextless" (duration, unit: time.Duration) -> f64 {
	return f64(duration) / f64(unit)
}