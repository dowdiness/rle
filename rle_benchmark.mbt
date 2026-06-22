// Benchmarks for Runs operations
// Run with: moon bench --release

// BenchRun: a non-mergeable run type for benchmarks.
// can_merge returns false so runs stay separate after construction,
// giving realistic multi-run data for range/concat/extend benchmarks.
// No derive(Debug, Eq) — avoids leaking into the public interface.

///|
priv struct BenchRun {
  len : Int
}

///|
impl HasLength for BenchRun with length(self : BenchRun) -> Int {
  self.len
}

///|
impl Spanning for BenchRun with span(self : BenchRun) -> Int {
  self.len
}

///|
impl Mergeable for BenchRun with can_merge(_a : BenchRun, _b : BenchRun) -> Bool {
  false
}

///|
impl Mergeable for BenchRun with merge(a : BenchRun, _b : BenchRun) -> BenchRun {
  a // unreachable since can_merge is false
}

///|
fn make_bench_runs(count : Int, run_len : Int) -> Runs[BenchRun] {
  let arr : Array[BenchRun] = []
  for _i = 0; _i < count; _i = _i + 1 {
    arr.push({ len: run_len })
  }
  Runs::from_array(arr)
}

///|
/// Benchmark: range with small span near start
test "runs - range iter (small)" (b : @bench.T) {
  let runs = make_bench_runs(10000, 4)
  let start = 0
  let end = 400
  b.bench(fn() {
    let it = match runs.range(start~, end~) {
      Ok(it) => it
      Err(_) => abort("range failed")
    }
    b.keep(it.count())
  })
}

///|
/// Benchmark: range with span near middle
test "runs - range iter (middle)" (b : @bench.T) {
  let runs = make_bench_runs(10000, 4)
  let total = 10000 * 4
  let start = total / 2
  let end = start + 400
  b.bench(fn() {
    let it = match runs.range(start~, end~) {
      Ok(it) => it
      Err(_) => abort("range failed")
    }
    b.keep(it.count())
  })
}

///|
/// Benchmark: batch concat of non-mergeable runs
test "runs - concat batch" (b : @bench.T) {
  let runs_a = make_bench_runs(500, 10)
  let runs_b = make_bench_runs(500, 10)
  b.bench(fn() {
    let result = runs_a.concat(runs_b)
    b.keep(result.length())
  })
}

///|
/// Benchmark: batch extend of non-mergeable runs
test "runs - extend batch" (b : @bench.T) {
  let template = make_bench_runs(500, 10)
  let runs_b = make_bench_runs(500, 10)
  b.bench(fn() {
    let runs_a = Runs(template.0.copy())
    runs_a.extend(runs_b)
    b.keep(runs_a.length())
  })
}

///|
/// Benchmark: from_array_batch construction (strings merge into one run)
test "runs - from_array_batch" (b : @bench.T) {
  let arr : Array[String] = []
  for i = 0; i < 1000; i = i + 1 {
    arr.push("x")
  }
  b.bench(fn() {
    let runs = Runs::from_array_batch(arr)
    b.keep(runs.length())
  })
}
