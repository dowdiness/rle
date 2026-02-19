/// AuthoredRun: a run of text attributed to a single author.
/// Adjacent runs from the same author merge automatically.

///|
pub struct AuthoredRun {
  author : String
  text : String
} derive(Show, Eq)

///|
/// Two runs merge only when they share the same author.
pub impl @rle.Mergeable for AuthoredRun with can_merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> Bool {
  a.author == b.author
}

///|
/// Merge by concatenating the text, keeping the shared author.
pub impl @rle.Mergeable for AuthoredRun with merge(
  a : AuthoredRun,
  b : AuthoredRun,
) -> AuthoredRun {
  { author: a.author, text: a.text + b.text }
}

///|
/// Length is the UTF-16 code-unit count of the text.
pub impl @rle.HasLength for AuthoredRun with length(self : AuthoredRun) -> Int {
  self.text.length()
}

///|
/// Span equals length (no tombstones in this example).
pub impl @rle.Spanning for AuthoredRun with span(self : AuthoredRun) -> Int {
  self.text.length()
}

///|
/// Slice by extracting a substring of the text.
pub impl @rle.Sliceable for AuthoredRun with slice(
  self : AuthoredRun,
  start~ : Int,
  end~ : Int,
) -> Result[AuthoredRun, @rle.RleError] {
  match @rle.slice_string_view(self.text, start~, end~) {
    Ok(sliced) => Ok({ author: self.author, text: sliced })
    Err(_) =>
      Err(@rle.RleError::InvalidSlice(reason=@rle.SliceError::InvalidIndex))
  }
}

// ── helpers ──────────────────────────────────────────────────────────

///|
fn authored(author : String, text : String) -> AuthoredRun {
  { author, text }
}

// ── examples ─────────────────────────────────────────────────────────

///|
test "same-author runs merge" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("alice", ", world"))
  inspect(rle.length(), content="1") // merged
  match rle.get(0) {
    Some(run) => {
      inspect(run.author, content="alice")
      inspect(run.text, content="Hello, world")
    }
    None => fail("expected a run")
  }
}

///|
test "different-author runs stay separate" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", ", world"))
  inspect(rle.length(), content="2") // kept separate
}

///|
test "split at author boundary" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", " world"))
  match rle.split(5) {
    Ok((left, right)) => {
      inspect(left.length(), content="1")
      inspect(right.length(), content="1")
      match left.get(0) {
        Some(r) => inspect(r.author, content="alice")
        None => fail("expected left run")
      }
      match right.get(0) {
        Some(r) => inspect(r.author, content="bob")
        None => fail("expected right run")
      }
    }
    Err(_) => fail("unexpected split error")
  }
}

///|
test "range extracts slice across runs" {
  let rle : @rle.Rle[AuthoredRun] = @rle.Rle::new()
  let _ = rle.append(authored("alice", "Hello"))
  let _ = rle.append(authored("bob", " world"))
  // Extract positions 3..8 ("lo wo") — spans both runs
  match rle.range(start=3, end=8) {
    Ok(iter) => {
      let slices = iter.collect()
      inspect(slices.length(), content="2") // one slice per run
      match slices[0].to_inner() {
        Ok(r) => {
          inspect(r.author, content="alice")
          inspect(r.text, content="lo")
        }
        Err(_) => fail("unexpected slice error")
      }
      match slices[1].to_inner() {
        Ok(r) => {
          inspect(r.author, content="bob")
          inspect(r.text, content=" wo")
        }
        Err(_) => fail("unexpected slice error")
      }
    }
    Err(_) => fail("unexpected range error")
  }
}

///|
test "from_array merges same-author adjacent runs" {
  let runs = [
    authored("alice", "foo"),
    authored("alice", "bar"),
    authored("bob", "baz"),
  ]
  let rle = @rle.Rle::from_array(runs)
  inspect(rle.length(), content="2") // alice merged, bob separate
  match rle.get(0) {
    Some(r) => inspect(r.text, content="foobar")
    None => fail("expected run 0")
  }
}
