///| RLE error types

///|
/// Internal invariant violations - indicates bugs, not user errors
pub(all) suberror InternalError {
  EmptyElement // Attempted to add element with span == 0
  InvalidState(detail~ : String)
} derive(Show)

///|
/// Slice errors when extracting sub-ranges from a run.
///
/// These are raised when a slice lands outside the valid bounds or splits a
/// UTF-16 surrogate pair (string slicing is done in code units).
pub(all) suberror SliceError {
  /// Start/end fall outside the run bounds.
  IndexOutOfBounds
  /// Start/end split a UTF-16 surrogate pair.
  InvalidIndex
} derive(Show, Eq)

///|
/// Why a range is invalid
pub enum RangeIssue {
  NegativeStart
  NegativeEnd
  StartAfterEnd
  ExceedsLength
} derive(Show, Eq)

///|
/// User-facing errors with context for friendly messages
pub(all) suberror RleError {
  PositionOutOfBounds(position~ : Int, length~ : Int)
  InvalidRange(start~ : Int, end~ : Int, length~ : Int, reason~ : RangeIssue)
  /// A slice failed to produce a valid value (e.g., invalid UTF-16 boundary).
  InvalidSlice(reason~ : SliceError)
  Internal(InternalError)
} derive(Show)

///|
/// Rust style wrapper struct for user-friendly error display
///
/// https://doc.rust-lang.org/stable/std/path/struct.Display.html
pub struct ErrorMessage {
  priv error : RleError
}

///|
/// Get a user-friendly message wrapper for this error
pub fn RleError::message(self : RleError) -> ErrorMessage {
  { error: self }
}

///|
/// Display user-friendly error message
pub impl Show for ErrorMessage with output(self, logger) {
  match self.error {
    PositionOutOfBounds(position~, length~) =>
      logger.write_string(
        "Position \{position} is outside the document (length: \{length})",
      )
    InvalidRange(start~, end~, length~, reason~) =>
      match reason {
        NegativeStart =>
          logger.write_string("Range start (\{start}) cannot be negative")
        NegativeEnd =>
          logger.write_string("Range end (\{end}) cannot be negative")
        StartAfterEnd =>
          logger.write_string(
            "Range start (\{start}) must come before end (\{end})",
          )
        ExceedsLength =>
          logger.write_string(
            "Range end (\{end}) exceeds document length (\{length})",
          )
      }
    InvalidSlice(reason~) =>
      match reason {
        IndexOutOfBounds =>
          logger.write_string("Slice indices are out of bounds")
        InvalidIndex =>
          logger.write_string("Slice indices are not on valid boundaries")
      }
    Internal(_) =>
      logger.write_string(
        "An internal error occurred. Please report this as a bug.",
      )
  }
}
