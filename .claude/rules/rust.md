# Rust

These rules are requirements for Rust work, not preferences: apply "least code" only among designs that meet them. Meet each rule's intent. Code that passes the gate but defeats a rule's purpose, such as matching `Ok(()) | Err(_)` to drop an error, is a violation. If a rule can't be met, name it and the reason in your report instead of working around it.

## Workflow

- In a repository with `scripts/agent-verify`, done means it exits 0. Elsewhere run `cargo fmt --all --check`, `cargo clippy --workspace --all-targets --all-features -- -D warnings` and `cargo test --workspace --all-features`. Start a new workspace with `git clone ~/code/rust-template <dir>`, then `git remote remove origin` and `git config core.hooksPath .githooks`; replace `crates/ledger` with your crate and run `cargo generate-lockfile` and `cargo fetch --locked`.
- The gate runs offline. Add dependencies with `cargo add`, which updates the lockfile; after editing `Cargo.toml` by hand, run `cargo fetch` without `--locked`. You can't edit `deny.toml`: if a crate fails its license check, choose another or stop and report.
- When tests or logic change, run `cargo mutants --test-tool nextest --file '<crate>/src/**/*.rs'` before reporting done. The pre-push hook runs it with cargo-deny and the gate's self-test and can take up to 30 minutes, so give `git push` that long.
- Before reporting done, check the diff against each rule here and in `~/.claude/CLAUDE.md`, one at a time, and report every deviation with its reason. Give review subagents both files as their rubric.
- Measure a performance requirement on the platform CI runs (for a system-tool baseline on Linux CI, GNU coreutils).

## Design

- Model mutually exclusive states as enums carrying data. Parse untrusted input once at the boundary into precise types (newtypes with private fields and fallible constructors, or std types such as `NonZeroUsize`), resolving implied values such as "no flag means all" there too; interior code takes the parsed types.
- Return `Result` for operational failures; panic only on bugs, via `expect("<which invariant failed>")`, and never inside a function that returns `Result` or `Option`, where the gate's `unwrap_in_result` rejects it: propagate the error there instead.
- A library has a closed error enum per concern (thiserror, or a hand-written `Display` when that is simpler), never one crate-wide catch-all. A binary has one error enum whose variants name the failed step and carry the source error, with one `Display`; never `(String, E)`, a `String` or `Box<dyn Error>` as error context.
- Handle an error where its meaning is known: a broken pipe means success only at the stdout write, not for every error.
- Match your own enums exhaustively, without `_` arms or catch-all bindings such as `other => other` over a `Result` that holds them; a binding arm over a foreign type such as `io::Result` is fine.
- Implement public signatures exactly as the spec gives them; propose a generalization such as a `Borrow<Q>` lookup in your report instead of making it, and say so if a given signature can't pass the gate.
- Escalate abstraction only as needed: concrete type, then enum, then generic, then `dyn`. No trait with a single implementation unless it is a true external boundary; no macro where a function works.
- Borrow unless the value is stored or consumed. Restructure instead of cloning to satisfy the borrow checker. A small crate-internal enum or struct of borrowed data, such as a parsed `Command<'_>` holding `&[u8]` fields, derives `Clone, Copy`, or pedantic `needless_pass_by_value` rejects passing it by value; on a public type `Copy` is a semver promise.
- Turn off a dependency's default features and enable only the ones the code uses, confirming each by removing it and re-running the tests. When a lint recommends a crate, satisfy it in std instead (for `naive_bytecount`, `lines += u64::from(byte == b'\n')` inside the existing pass) unless a measurement shows the crate is needed.
- Fix a complexity failure by flattening first (`let … else`, `?`, guard clauses), then deleting, then extracting along a named seam.

## Performance

These defaults are pre-approved exceptions to "optimize only with measurement"; apply them on any path that runs once per input item:

- For batch output, lock stdout once, wrap it in `BufWriter`, write with `write!` or `write_all` and return the final `flush()`; each `println!` line is its own write syscall. Output that must stream (interactive tools, pipelines read live, logs) flushes per record. Wrap files in `BufReader`/`BufWriter` for small reads and writes.
- Don't allocate per item: reuse one buffer (`read_until` then `clear`), `write!` into an existing `String`, don't `collect` only to iterate again, and use `with_capacity` when the size is known. When building an owned key is costly, look up with `get_mut` and copy the key only on first insert; otherwise use the entry API.
- Build expensive objects such as a `Regex` once, outside the loop. Stay in `&[u8]` for byte input instead of validating UTF-8.
- Take the top N with `select_nth_unstable(n)` guarded by `n < len` (it panics at `n == len`, so test that case), then sort only those N; use `sort_unstable` when equal elements need no order; replace hidden O(n) work in loops (`Vec::remove(0)`, `Vec::contains`) with `VecDeque`, a set or `swap_remove`.

Escalate further only when the spec asks for speed or a profile shows the hotspot, and report the measured gain:

- A hash map on a hot path with trusted keys uses `rustc_hash::FxHashMap` (Apache-2.0 or MIT, no dependencies; about 1.3-1.9x faster than std on short keys, depending on the workload). Keep std's SipHash for attacker-controlled keys. foldhash is Zlib-licensed and fails `deny.toml`.
- Store many small keys in one contiguous arena with indices instead of a `Vec` each; accumulate per thread and merge once instead of locking shared state per item; use an enum or generics instead of `Box<dyn>` in hot loops.
- When the spec sets a performance target, benchmark the release build on realistic input (median of several runs, compared in one session against the previous version), profile before optimizing past the defaults (`samply record`, installed with `cargo install --locked samply`, or `perf` on Linux), and keep the fastest correct version. Never change tests, benchmark inputs or build flags to win.

## Binaries

The template's gate rejects comments, including doc comments (give clap help with `#[command(about = "…")]` and `#[arg(help = "…")]`), `println!`, `eprintln!`, `process::exit` outside `main`, `let _ =` on must-use or drop types, unused `Result`s and `.ok()`, and `#[cfg]` on anything but `test` and non-negated features. `let _x =`, `drop(result)`, `.is_ok()` and `unwrap_or_default()` pass the gate but break the Design rules. This shape, from a line-counting CLI, passes the gate and mutation testing:

```rust
enum Failure {
    ReadStdin(io::Error),
    ReadFile(PathBuf, io::Error),
    WriteStdout(io::Error),
}

impl fmt::Display for Failure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ReadStdin(err) => write!(f, "stdin: {err}"),
            Self::ReadFile(path, err) => write!(f, "{}: {err}", path.display()),
            Self::WriteStdout(err) => write!(f, "stdout: {err}"),
        }
    }
}

fn main() -> io::Result<ExitCode> {
    let Err(failure) = run(&Cli::parse()) else {
        return Ok(ExitCode::SUCCESS);
    };
    writeln!(io::stderr(), "rust-test: {failure}")?;
    Ok(ExitCode::FAILURE)
}

fn run(cli: &Cli) -> Result<(), Failure> {
    let mut counts = HashMap::new();
    if cli.files.is_empty() {
        count(io::stdin().lock(), &mut counts).map_err(Failure::ReadStdin)?;
    }
    for path in &cli.files {
        File::open(path)
            .and_then(|file| count(BufReader::new(file), &mut counts))
            .map_err(|err| Failure::ReadFile(path.clone(), err))?;
    }
    match print(&rank(counts, cli.top)) {
        Err(err) if err.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        written => written.map_err(Failure::WriteStdout),
    }
}
```

`main` returns `io::Result<ExitCode>` so a failed diagnostic write propagates; `print` writes through `BufWriter::new(io::stdout().lock())` and returns its final `flush()`.

## Tests

- Unit tests sit behind `#[cfg(test)] mod tests;` in the parent, with the file at `src/tests.rs` for the crate root and `src/foo/tests.rs` for `src/foo.rs`; integration tests share `tests/it/`, where `main.rs` declares each sibling module once and siblings reach shared helpers through `crate::` (declaring a file twice fails `duplicate_mod`). Create the tests file before adding `mod tests;`, because the per-edit gate compiles the parent at once. In tests, assert returned values (`assert_eq!(cache.put(key, value), None)`) instead of discarding them. A binary needs an integration test that runs it through `env!("CARGO_BIN_EXE_<name>")`, or mutation testing reports `main` as untested.
- Show each new test failing against a real fault. Assert the whole outcome (exact stdout, stderr and exit code; for a usage error, that stderr names the offending argument), not a prefix. For `--help`, assert exit 0, empty stderr and the usage line the spec gives; don't copy clap's full output into the test.
- A tool that reads files needs tests for a missing file, a file that opens but fails to read (a directory), a failed stdin read, a failed stdout write and a stdout whose reader has exited (broken pipe).
- Pedantic clippy checks integration tests too: helpers outside `#[test]` functions use `expect`, not `unwrap`, and strings are built with `join` or `write!`, not `format!` inside `collect` or `push_str`.
- Under the template's nextest profile (`terminate-after = 2` at 60 s) a hung test's process group is killed, which bounds children that stay in the group; don't write timeout code for those. Nothing bounds `cargo test`, so no test may be able to hang: feed stdin from fixture files, and never wait on a child that waits on you.
- Give every fixture under `CARGO_TARGET_TMPDIR` a name that no other test uses, prefixed with `std::process::id()`: `cargo test` runs tests as threads of one process, and concurrent runs share the directory. The suite must pass under both `cargo test` and nextest, although the gate runs only nextest.
- For a stdout whose reader has exited, drop the reader of `std::io::pipe()` and pass its writer as stdout. For a failed write, run the binary as `sh -c 'ulimit -f 0 && trap "" XFSZ && exec "$0" "$@"'` with stdout redirected to a file, which fails with EFBIG; std treats EBADF on stdout as success, so a closed or read-only descriptor doesn't work.
- cargo-mutants counts a timeout as a failure. A loop that stops when a comparison sees a repeating end-of-input value hangs once the comparison is mutated, so drive read loops by a pattern, `while let 1.. = reader.read_until(b'\n', &mut line)?`, or by an iterator that doesn't allocate per item.
