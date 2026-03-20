# RLE Block Fill & Interpolatable — Design Specification

**Date:** 2026-03-21
**Status:** Draft
**Scope:** Add block fill, Interpolatable trait, and cursor streaming to the RLE library

---

## 1. Overview

Three additions to the generic RLE library that enable bulk sequential reads
and continuous value computation within runs. These are generic sequence
operations — not audio-specific — but they unlock parameter automation as a
downstream use case.

### Additions

1. **Interpolatable trait** — compute a numeric value at a specific offset
   within a run
2. **Block fill on Rle and Runs** — bulk read N consecutive run objects into a
   buffer from a starting position
3. **Interpolated fill** — bulk read N consecutive interpolated `Double` values
   into a buffer (the integration point between fill_buffer and Interpolatable)
4. **Cursor fill_buffer** — sequential streaming: fill a buffer from the
   cursor's current position and advance

### Out of Scope

- Audio-specific `ParamSegment` types (mdsp scope, not RLE scope)
- Interpolation of non-numeric types (colors, vectors)
- Write/mutation variants of fill_buffer

---

## 2. Interpolatable Trait

### 2.1 Definition

```moonbit
///|
/// Compute a numeric value at a specific offset within a run.
///
/// The offset is a zero-based position within the run's span.
/// Implementations may call `self.span()` for normalization.
///
/// Contract: `0 <= offset < self.span()`. Callers are responsible for
/// bounds validation — `find()` and `fill_buffer()` return validated
/// offsets via `RunPos`.
pub(open) trait Interpolatable : Spanning {
  interpolate(Self, offset : Int) -> Double
}
```

### 2.2 Design Notes

- Extends `Spanning` because implementations often need `self.span()` to
  normalize the offset into a 0.0..1.0 progress value.
- Returns `Double` (fixed-type projection, MoonBit Pattern 2). This is
  appropriate because the primary consumers (audio parameter automation,
  animation curves) need numeric values. Multi-valued interpolation (colors,
  vectors) can use wrapper types that interpolate one channel at a time.
- No bounds validation on `offset` — matches the library's pattern where
  `find()` returns a validated `RunPos` with offset already bounded.

### 2.3 Example Implementations

```moonbit
// Constant segment: same value everywhere
struct ConstantSegment { value : Double, length : Int }

impl Spanning for ConstantSegment with span(self) { self.length }
impl Interpolatable for ConstantSegment with interpolate(self, _offset) {
  self.value
}

// Linear ramp: interpolates between start and end
struct RampSegment { start : Double, end_ : Double, length : Int }

impl Spanning for RampSegment with span(self) { self.length }
impl Interpolatable for RampSegment with interpolate(self, offset) {
  if self.span() <= 1 {
    self.start
  } else {
    let t = offset.to_double() / (self.span() - 1).to_double()
    self.start + (self.end_ - self.start) * t
  }
}
```

### 2.4 Placement

File: `src/traits.mbt`, after the existing `Addressable` trait definition.

---

## 3. Block Fill

### 3.1 Rle::fill_buffer

```moonbit
///|
/// Fill `buffer` with run objects at consecutive positions starting from
/// `start`. Returns the number of positions filled (0 to buffer.length())
/// or an error for invalid start position.
pub fn[T : Spanning] Rle::fill_buffer(
  self : Rle[T],
  start : Int,
  buffer : Array[T],
) -> Result[Int, RleError]
```

**Algorithm:**
1. If `start < 0`, return `Err(PositionOutOfBounds)`.
2. If `buffer.length() == 0`, return `Ok(0)`.
3. `ensure_prefix()` to get cached prefix sums.
4. If `start >= total_span`, return `Ok(0)`.
5. `find_fast(sums, start)` for O(log n) start lookup.
6. Begin at the found run and offset. Linear scan forward:
   - For each position in the buffer, write the current run object.
   - When `offset_in_run` reaches `span(run)`, advance to the next run.
   - When runs are exhausted, stop.
7. Return `Ok(count)`.

**Optimization:** When the current run covers multiple consecutive buffer
positions (common for long runs), fill them in a batch rather than one at a
time. The inner loop advances by `min(remaining_in_run, remaining_in_buffer)`
and writes the same run object to that many positions.

**Complexity:** O(log n + k) where k is `buffer.length()`.

**Placement:** `src/rle.mbt`, alongside `find`, `range`, `value_at`.

### 3.2 Runs::fill_buffer

```moonbit
///|
/// Fill `buffer` with run objects at consecutive positions starting from
/// `start`. Returns the number of positions filled or an error for invalid
/// start position.
pub fn[T : Spanning] Runs::fill_buffer(
  self : Runs[T],
  start : Int,
  buffer : Array[T],
) -> Result[Int, RleError]
```

Same algorithm as `Rle::fill_buffer` but uses `find` (O(n) linear scan)
instead of `find_fast` (binary search). No prefix sums needed.

**Complexity:** O(n + k).

**Placement:** `src/runs.mbt`, alongside `find`, `range`, `value_at`.

### 3.3 Rle::fill_buffer_interpolated

The integration point between `fill_buffer` and `Interpolatable`. Fills a
`Array[Double]` with interpolated numeric values at consecutive positions.

```moonbit
///|
/// Fill `buffer` with interpolated Double values at consecutive positions
/// starting from `start`. Returns the number of positions filled or an error.
///
/// For each position, the run covering that position is found and
/// `interpolate(run, offset_within_run)` produces the value.
pub fn[T : Interpolatable] Rle::fill_buffer_interpolated(
  self : Rle[T],
  start : Int,
  buffer : Array[Double],
) -> Result[Int, RleError]
```

**Algorithm:** Same traversal as `fill_buffer`, but instead of writing the run
object, writes `run.interpolate(offset_in_run)` into each buffer slot.

**Complexity:** O(log n + k).

**Placement:** `src/rle.mbt`, alongside `fill_buffer`.

**Usage pattern:**

```moonbit
// Consumer creates an Rle of parameter segments
let timeline : Rle[RampSegment] = ...

// Each audio block: read 128 interpolated values
let sample_buffer = Array::make(128, 0.0)
match timeline.fill_buffer_interpolated(cursor_position, sample_buffer) {
  Ok(count) => {
    // count values written; positions count..127 are untouched
    cursor_position += count
  }
  Err(_) => // handle error
}
```

### 3.4 Edge Cases

- `start < 0` → `Err(PositionOutOfBounds)`
- `start >= total_span` → `Ok(0)`
- `buffer.length() == 0` → `Ok(0)`
- `start + buffer.length() > total_span` → fill available positions, return
  `Ok(count)` where count < buffer.length()
- Empty sequence (no runs) → `Ok(0)`

---

## 4. Cursor Fill Buffer

### 4.1 Definition

```moonbit
///|
/// Fill `buffer` with run objects starting from the cursor's current position.
/// Advances the cursor by the number of positions filled.
/// Returns 0 if stale, at end, or empty buffer.
///
/// To fill from an arbitrary position, call `seek(pos)` first. If `seek`
/// returns false (out of bounds), the cursor is at the end and `fill_buffer`
/// will return 0.
pub fn[T : Spanning] RleCursor::fill_buffer(
  self : RleCursor[T],
  buffer : Array[T],
) -> Int
```

### 4.2 Algorithm

1. Check staleness: if `self.version != self.rle.version`, return 0.
2. If `buffer.length() == 0`, return 0.
3. Start from `self.run_index` and `self.offset_in_run` (already positioned
   from previous operations or `seek`).
4. Linear scan forward from the current position:
   - For each buffer slot, write the current run object.
   - Advance `offset_in_run`; when it reaches `span(run)`, move to the next
     run and reset offset.
   - When runs are exhausted, stop.
5. Update `self.run_index`, `self.offset_in_run`, and `self.global_offset`.
6. Return count of positions filled.

### 4.3 Cursor fill_buffer_interpolated

```moonbit
///|
/// Fill `buffer` with interpolated Double values starting from the cursor's
/// current position. Advances the cursor by the number of positions filled.
/// Returns 0 if stale, at end, or empty buffer.
pub fn[T : Interpolatable] RleCursor::fill_buffer_interpolated(
  self : RleCursor[T],
  buffer : Array[Double],
) -> Int
```

Same traversal as `RleCursor::fill_buffer` but writes
`run.interpolate(offset_in_run)` instead of the run object.

### 4.4 Performance

The key advantage over repeated `next()` calls: no per-position method call
overhead. When a run spans 1000 positions and the buffer is 128 slots, the
inner loop processes 128 positions in one traversal — one run lookup, not 128
`next()` calls.

For `fill_buffer` (run objects): when a single run covers multiple buffer
positions, the same run object is written to consecutive slots in a batch.

For `fill_buffer_interpolated`: each position requires `interpolate(offset)`
which may involve arithmetic (e.g., linear interpolation), but the run lookup
is amortized.

**Complexity:** O(k) amortized where k is `buffer.length()`. Each run is
visited at most once across consecutive calls.

### 4.5 Staleness

Returns 0 and does not advance. Matches the existing cursor contract: stale
cursors refuse to operate rather than returning potentially wrong data.

### 4.6 Placement

File: `src/rle_cursor.mbt`, alongside `advance`, `next`, `iter_forward`.

---

## 5. Testing Strategy

### 5.1 Interpolatable

- Constant segment: `interpolate(_, any_offset)` returns the constant value
- Linear ramp: `interpolate(_, 0)` returns start, `interpolate(_, span-1)`
  returns end, `interpolate(_, span/2)` returns midpoint
- Single-position span: `interpolate(_, 0)` returns start value (no division
  by zero)

### 5.2 Rle::fill_buffer and Runs::fill_buffer

- Full fill: buffer fits within one run → all slots get the same run
- Cross-run fill: buffer spans multiple runs → correct run at each position
- Partial fill: buffer extends past end → count < buffer.length(), unfilled
  slots untouched
- Start at 0: fill from beginning
- Start at mid-run: fill starting from an offset within a run
- Empty sequence: returns Ok(0)
- Empty buffer: returns Ok(0)
- Start past end: returns Ok(0)
- Start < 0: returns Err(PositionOutOfBounds)
- Property test: `fill_buffer` at every position matches `value_at` at that
  position

### 5.3 fill_buffer_interpolated

- Constant runs: all positions produce the same Double value
- Ramp runs: first position = start, last position = end, middle = midpoint
- Cross-run: transitions between runs produce correct interpolated values
- Matches manual: `fill_buffer` + manual `interpolate` produces same values as
  `fill_buffer_interpolated`

### 5.4 RleCursor::fill_buffer

- Sequential blocks: cursor.fill_buffer(buf1) then cursor.fill_buffer(buf2)
  produces the same values as one large fill_buffer
- Staleness: mutate Rle, then cursor.fill_buffer returns 0
- At end: cursor at end, fill_buffer returns 0
- Partial end: cursor near end, fill_buffer returns partial count
- Matches Rle::fill_buffer: cursor from position P fills the same as
  Rle::fill_buffer(P, buffer)
- After failed seek: `seek(-1)` → false, then `fill_buffer` → returns values
  from position 0 (seek to invalid position leaves cursor at start)

### 5.5 QuickCheck Properties

- `fill_buffer(start, buf)` for each position i:
  `buf[i] == value_at(start + i)` (when i < count)
- `fill_buffer_interpolated(start, buf)` consistency: each value matches
  `interpolate(run_at_pos, offset_at_pos)`
- `cursor.fill_buffer(buf)` consistency: sequential fills produce same result
  as one contiguous fill
- `fill_buffer` count is always `<= buffer.length()` and `>= 0`

### 5.6 Integration Test

- End-to-end: create an `Rle[RampSegment]` with multiple ramps, use
  `fill_buffer_interpolated` to read a block of interpolated values, verify
  the values match the expected ramp computation at each position

---

## 6. File Changes

| File | Change |
|------|--------|
| `src/traits.mbt` | Add `Interpolatable` trait definition |
| `src/runs.mbt` | Add `Runs::fill_buffer` |
| `src/rle.mbt` | Add `Rle::fill_buffer`, `Rle::fill_buffer_interpolated` |
| `src/rle_cursor.mbt` | Add `RleCursor::fill_buffer`, `RleCursor::fill_buffer_interpolated` |
| `src/runs_test.mbt` | Tests for `Runs::fill_buffer` |
| `src/rle_test.mbt` | Tests for `Rle::fill_buffer`, `fill_buffer_interpolated`, `Interpolatable` |
| `src/rle_cursor_test.mbt` | Tests for cursor fill methods (new file if needed) |
| `src/runs_properties_test.mbt` | QuickCheck property tests |

No existing files are modified beyond appending new functions and tests.
No existing APIs change.
