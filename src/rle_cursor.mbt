///|
/// Result type for cursor operations that may become stale.
/// `Some(value)` when cursor is valid, `None` when stale due to Rle mutations.
/// This is a type alias for `T?` — its purpose is documentation, not runtime
/// overhead. When you see `MayStale[Int]` as a return type, `None` means
/// "the cursor is stale" rather than "value not found."
pub type MayStale[T] = T?

///|
/// **RleCursor** — sequential traversal with automatic staleness detection.
///
/// A cursor captures the `Rle`'s `version` at creation time. On every
/// operation, it compares its captured version against the current version.
/// If they differ (meaning the `Rle` was mutated), the cursor is **stale**
/// and all operations return `None` or `false`. This is conservative: the
/// cursor refuses to return potentially wrong data rather than guessing.
///
/// The version counter is monotonically increasing, so there is no ABA
/// problem — even if the data returns to its original state after two
/// mutations, the version number is higher and staleness is correctly detected.
///
/// ## Typical Usage
///
/// ```text
/// let cursor = rle.cursor()   // captures version
/// cursor.advance(5)           // move forward
/// cursor.current_item()       // read current run
/// rle.append(x)               // mutation! version bumps
/// cursor.is_stale()           // true — cursor is now invalid
/// cursor.next()               // None — refuses to operate
/// ```
///
/// Create a new cursor after mutations to continue traversal.
pub struct RleCursor[T] {
  rle : Rle[T]
  version : Int // Captured version at cursor creation
  mut run_index : Int
  mut offset_in_run : Int
  mut global_offset : Int
} derive(Show, Eq)

///|
/// Create cursor for Rle (starts at position 0)
pub fn[T] Rle::cursor(self : Rle[T]) -> RleCursor[T] {
  {
    rle: self,
    version: self.version,
    run_index: 0,
    offset_in_run: 0,
    global_offset: 0,
  }
}

///|
/// Check if cursor is stale due to Rle mutations
pub fn[T] RleCursor::is_stale(self : RleCursor[T]) -> Bool {
  self.version != self.rle.version
}

///|
/// Current global position (returns None if stale)
pub fn[T] RleCursor::position(self : RleCursor[T]) -> MayStale[Int] {
  if self.is_stale() {
    return None
  }
  Some(self.global_offset)
}

///|
/// Current run and offset within it (returns None if stale)
pub fn[T] RleCursor::current(self : RleCursor[T]) -> (T, Int)? {
  if self.is_stale() || self.run_index >= self.rle.runs.0.length() {
    return None
  }
  Some((self.rle.runs.0[self.run_index], self.offset_in_run))
}

///|
/// Current item without offset (returns None if stale)
pub fn[T] RleCursor::current_item(self : RleCursor[T]) -> T? {
  if self.is_stale() || self.run_index >= self.rle.runs.0.length() {
    return None
  }
  Some(self.rle.runs.0[self.run_index])
}

///|
/// Check if at end (returns true if stale - conservative stop)
pub fn[T : Spanning] RleCursor::at_end(self : RleCursor[T]) -> Bool {
  self.is_stale() || self.global_offset >= self.rle.span()
}

///|
/// Advance by n positions (returns false if stale)
pub fn[T : Spanning] RleCursor::advance(self : RleCursor[T], n : Int) -> Bool {
  if self.is_stale() {
    return false
  }
  if n <= 0 {
    return true
  }
  let total = self.rle.span()
  let target = self.global_offset + n
  if target > total {
    self.global_offset = total
    self.run_index = self.rle.runs.0.length()
    self.offset_in_run = 0
    return false
  }
  let mut remaining = n
  while remaining > 0 && self.run_index < self.rle.runs.0.length() {
    let run_len = Spanning::span(self.rle.runs.0[self.run_index])
    let available = run_len - self.offset_in_run
    if remaining < available {
      self.offset_in_run = self.offset_in_run + remaining
      self.global_offset = self.global_offset + remaining
      remaining = 0
    } else {
      self.global_offset = self.global_offset + available
      remaining = remaining - available
      self.run_index = self.run_index + 1
      self.offset_in_run = 0
    }
  }
  true
}

///|
/// Retreat by n positions (returns false if stale)
pub fn[T : Spanning] RleCursor::retreat(self : RleCursor[T], n : Int) -> Bool {
  if self.is_stale() {
    return false
  }
  if n <= 0 {
    return true
  }
  if n > self.global_offset {
    self.global_offset = 0
    self.run_index = 0
    self.offset_in_run = 0
    return false
  }
  let mut remaining = n
  while remaining > 0 {
    if self.offset_in_run >= remaining {
      self.offset_in_run = self.offset_in_run - remaining
      self.global_offset = self.global_offset - remaining
      remaining = 0
    } else {
      remaining = remaining - self.offset_in_run
      self.global_offset = self.global_offset - self.offset_in_run
      if self.run_index == 0 {
        self.offset_in_run = 0
        break
      }
      self.run_index = self.run_index - 1
      self.offset_in_run = Spanning::span(self.rle.runs.0[self.run_index])
    }
  }
  true
}

///|
/// Seek to absolute position — O(log n) via `Rle::find` binary search.
/// Returns false if stale or if `pos` is out of bounds.
pub fn[T : Spanning] RleCursor::seek(self : RleCursor[T], pos : Int) -> Bool {
  if self.is_stale() {
    return false
  }
  if pos < 0 {
    self.global_offset = 0
    self.run_index = 0
    self.offset_in_run = 0
    return false
  }
  let total = self.rle.span()
  if pos >= total {
    self.global_offset = total
    self.run_index = self.rle.runs.0.length()
    self.offset_in_run = 0
    return pos == total
  }
  match self.rle.find(pos) {
    Some(found) => {
      self.run_index = found.run
      self.offset_in_run = found.offset
      self.global_offset = pos
      true
    }
    None => {
      self.global_offset = total
      self.run_index = self.rle.runs.0.length()
      self.offset_in_run = 0
      false
    }
  }
}

///|
/// Seek to start
pub fn[T] RleCursor::seek_start(self : RleCursor[T]) -> Unit {
  self.global_offset = 0
  self.run_index = 0
  self.offset_in_run = 0
}

///|
/// Seek to end
pub fn[T : Spanning] RleCursor::seek_end(self : RleCursor[T]) -> Unit {
  self.global_offset = self.rle.span()
  self.run_index = self.rle.runs.0.length()
  self.offset_in_run = 0
}

///|
/// Get next item and advance (returns None if stale)
pub fn[T : Spanning] RleCursor::next(self : RleCursor[T]) -> T? {
  if self.is_stale() || self.run_index >= self.rle.runs.0.length() {
    return None
  }
  let item = self.rle.runs.0[self.run_index]
  let _ = self.advance(1)
  Some(item)
}

///|
/// Retreat and get previous item (returns None if stale)
pub fn[T : Spanning] RleCursor::prev(self : RleCursor[T]) -> T? {
  if self.is_stale() || self.global_offset == 0 {
    return None
  }
  let _ = self.retreat(1)
  if self.run_index < self.rle.runs.0.length() {
    Some(self.rle.runs.0[self.run_index])
  } else {
    None
  }
}

///|
/// Iterate forward from current position, yielding `(item, offset_in_run, global_pos)`
/// for each atomic position (per unit of span, not per run).
///
/// For a string run "hello" (span 5), this yields 5 entries, each pointing to
/// the same run object with increasing offsets. Returns empty iterator if stale.
pub fn[T : Spanning] RleCursor::iter_forward(
  self : RleCursor[T],
) -> Iter[(T, Int, Int)] {
  if self.is_stale() {
    return Iter::empty()
  }
  let items = self.rle.runs.0
  let mut run_idx = self.run_index
  let mut offset = self.offset_in_run
  let mut global = self.global_offset
  Iter::new(fn() {
    if run_idx >= items.length() {
      return None
    }
    let item = items[run_idx]
    let item_len = Spanning::span(item)
    if offset >= item_len {
      run_idx = run_idx + 1
      offset = 0
      if run_idx >= items.length() {
        return None
      }
      let next_item = items[run_idx]
      let result = (next_item, 0, global)
      offset = 1
      global = global + 1
      return Some(result)
    }
    let result = (item, offset, global)
    offset = offset + 1
    global = global + 1
    Some(result)
  })
}
