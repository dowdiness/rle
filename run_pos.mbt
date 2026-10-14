///|
/// Position within runs - result of find operations
pub(all) struct RunPos {
  run : Int32 // which run (0-indexed)
  offset : Int32 // offset within that run
} derive(Debug, Eq)

///|
pub impl Show for RunPos with fn output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub extend RunPos with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RunPos with Eq::{not_equal, equal}

///|
pub extend RunPos with Show::{to_string, output}
