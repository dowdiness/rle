///|
/// Position within runs - result of find operations
pub(all) struct RunPos {
  run : Int // which run (0-indexed)
  offset : Int // offset within that run
} derive(Debug, Eq)

///|
pub impl Show for RunPos with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}
