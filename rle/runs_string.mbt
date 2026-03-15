///| String-specific operations for Runs

///|
/// String implements Mergeable - strings always merge
pub impl Mergeable for String with can_merge(_a : String, _b : String) -> Bool {
  true
}

///|
/// Merge two strings by concatenation
pub impl Mergeable for String with merge(a : String, b : String) -> String {
  a + b
}

///|
/// String implements HasLength - length() is used by Spanning default
/// logical_length() → span() → HasLength::length(), all returning UTF-16 code unit count
pub impl HasLength for String with length(self : String) -> Int {
  self.length()
}

///|
/// String implements Spanning via defaults:
/// span() → HasLength::length(), logical_length() → span()
/// Both return UTF-16 code unit count.
pub impl Spanning for String with span(self : String) -> Int {
  HasLength::length(self)
}

///|
/// Check if a code unit index falls on a UTF-16 low surrogate (0xDC00–0xDFFF),
/// meaning it would split a surrogate pair.
fn is_low_surrogate(text : String, index : Int) -> Bool {
  if index < 0 || index >= text.length() {
    return false
  }
  let code_unit = text.code_unit_at(index)
  code_unit >= 0xDC00 && code_unit <= 0xDFFF
}

///|
/// String helper that slices with bounds and surrogate pair validation.
///
/// MoonBit's `text[start:end]` no longer raises on invalid boundaries,
/// so we validate explicitly:
/// - Out of bounds → `SliceError::IndexOutOfBounds`
/// - Boundary inside a surrogate pair → `SliceError::InvalidIndex`
pub fn slice_string_view(
  text : String,
  start~ : Int,
  end~ : Int,
) -> Result[String, SliceError] {
  let len = text.length()
  if start < 0 || end > len || start > end {
    return Err(SliceError::IndexOutOfBounds)
  }
  if is_low_surrogate(text, start) || is_low_surrogate(text, end) {
    return Err(SliceError::InvalidIndex)
  }
  Ok(text[start:end].to_string())
}

///|
/// String implements Sliceable via substring with UTF-16 boundary validation.
pub impl Sliceable for String with slice(
  self : String,
  start~ : Int,
  end~ : Int,
) -> Result[String, RleError] {
  match slice_string_view(self, start~, end~) {
    Ok(value) => Ok(value)
    Err(err) => Err(RleError::InvalidSlice(reason=err))
  }
}

///|
/// Create from string (single run)
pub fn Runs::from_string(text : String) -> Runs[String] {
  if text.is_empty() {
    Runs::new()
  } else {
    Runs([text])
  }
}

///|
/// Concatenate all runs into single string
pub fn Runs::to_string(self : Runs[String]) -> String {
  self.0
  .fold(init=StringBuilder::new(), fn(sb, s) {
    sb.write_string(s)
    sb
  })
  .to_string()
}

///|
/// Iterate over codepoints
pub fn Runs::iter_chars(self : Runs[String]) -> Iter[Char] {
  let chars : Array[Char] = []
  for run in self.0 {
    for c in run {
      chars.push(c)
    }
  }
  chars.iter()
}

///|
/// Create Rle from string
pub fn Rle::from_string(text : String) -> Rle[String] {
  Rle::from_runs(Runs::from_string(text))
}

///|
/// Concatenate all runs into single string
pub fn Rle::to_string(self : Rle[String]) -> String {
  self.runs.to_string()
}

///|
/// Iterate over codepoints
pub fn Rle::iter_chars(self : Rle[String]) -> Iter[Char] {
  self.runs.iter_chars()
}
