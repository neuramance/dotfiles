# Rust

These rules are requirements for Rust work, not preferences: apply "least code" only among designs that meet them. Meet each rule's intent. Code that passes the gate but defeats a rule's purpose, such as matching `Ok(()) | Err(_)` to drop an error, is a violation. If a rule can't be met, name it and the reason in your report instead of working around it.

## Workflow

- In a repository with `scripts/agent-verify`, done means it exits 0. Elsewhere run `cargo fmt --check`, `cargo clippy --all-targets` and the tests. Start a new workspace with `git clone ~/code/rust-template <dir>`, then `git remote remove origin` and `git config core.hooksPath .githooks`; replace `crates/ledger` with your crate and run `cargo generate-lockfile` and `cargo fetch --locked`.
- The gate runs offline, so run `cargo fetch --locked` after changing dependencies. You can't edit `deny.toml`: if a crate fails its license check, choose another or stop and report. Give `git push` up to 10 minutes, because the pre-push hook runs mutation testing.
- Before reporting done, check the diff against each rule here and in `~/.claude/CLAUDE.md`, one at a time, and report every deviation with its reason. Give review subagents both files as their rubric.
- Measure a performance requirement on the platform CI runs; against a system tool, that means GNU coreutils on Linux, not only macOS.
- Never edit lint configuration, `.lints-baseline`, gate scripts, snapshots or proptest regressions to get green. Stop and report the failure instead.

## Design

- Model mutually exclusive states as enums carrying data. Parse untrusted input once at the boundary into precise types (newtypes with private fields and fallible constructors, or std types such as `NonZeroUsize`), resolving implied values such as "no flag means all" there too; interior code takes the parsed types.
- Return `Result` for operational failures and panic only on bugs, via `expect("<which invariant failed>")`. Never discard an error or substitute a default for one.
- Libraries define closed error enums per concern with thiserror. A binary has one error enum whose variants name the failed step and carry the source error, with one `Display` impl; never a tuple or a string as error context. No catch-all error enum.
- Handle an error where its meaning is known: a broken pipe means success only at the stdout write, not for every error.
- Match your own enums exhaustively, without `_` arms or catch-all bindings such as `other => other`, even inside a `Result`.
- Implement public signatures exactly as the spec gives them; propose a generalization such as a `Borrow<Q>` lookup in your report instead of making it.
- Escalate abstraction only as needed: concrete type, then enum, then generic, then `dyn`. No trait with a single implementation; no macro where a function works.
- Borrow unless the value is stored or consumed. Restructure instead of cloning to satisfy the borrow checker.
- Search the workspace before adding a function, type or dependency. State why a new dependency is needed and confirm the crate exists. Turn off its default features and enable only the ones the code uses, confirming each by removing it and re-running the tests. When a lint recommends a crate, satisfy it in std instead (for `naive_bytecount`, `lines += u64::from(byte == b'\n')` inside the existing pass) unless a measurement shows the crate is needed.
- Fix a complexity failure by flattening first (`let … else`, `?`, guard clauses, branching pushed up to the caller), then deleting, then extracting along a named seam.

## Performance

Apply these on any path that runs once per input item; they add no complexity:

- Lock stdout once, wrap it in `BufWriter`, write with `write!` and return the final `flush()`; `println!` flushes a syscall per line. Wrap files in `BufReader`/`BufWriter` for small reads and writes.
- Don't allocate per item: reuse one buffer (`read_until` then `clear`), `write!` into an existing `String`, don't `collect` only to iterate again, and use `with_capacity` when the size is known. Look up with `get_mut` and copy the key only on first insert.
- Build expensive objects such as a `Regex` once, outside the loop. Stay in `&[u8]` for byte input instead of validating UTF-8.
- Take the top N with `select_nth_unstable`, then sort only those N; use `sort_unstable` when equal elements need no order; replace hidden O(n) work in loops (`Vec::remove(0)`, `Vec::contains`) with `VecDeque`, a set or `swap_remove`.

Escalate further only when the spec asks for speed or a profile shows the hotspot, and report the measured gain:

- A hash map on a hot path with trusted keys uses `rustc_hash::FxHashMap` (Apache-2.0 or MIT, no dependencies; 1.3-1.4x faster than std on short byte keys). Keep std's SipHash for attacker-controlled keys. foldhash is Zlib-licensed and fails `deny.toml`.
- Store many small keys in one contiguous arena with indices instead of a `Vec` each; accumulate per thread and merge once instead of locking shared state per item; use an enum or generics instead of `Box<dyn>` in hot loops.
- When the spec sets a performance target, benchmark the release build on realistic input (median of several runs, compared in one session against the previous version), profile with `samply record` before optimizing past the defaults, and keep the fastest correct version. Never change tests, benchmark inputs or build flags to win.

## Binaries

The template's gate rejects comments, including doc comments (give clap help with `#[command(about = "…")]` and `#[arg(help = "…")]`), `println!`, `eprintln!`, `process::exit`, discarded results, and `#[cfg]` on anything but `test` and non-negated features. This shape, from a line-counting CLI, passes the gate and mutation testing:

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

`main` returns `io::Result<ExitCode>` so that a failed diagnostic write propagates instead of being dropped. `print` writes through `BufWriter::new(io::stdout().lock())` and returns its final `flush()`, so write errors surface.

## Tests

- Unit tests live in a sibling `tests.rs` behind `#[cfg(test)] mod tests;`; integration tests share one `tests/it/main.rs`. Create `tests.rs` before adding `mod tests;` to its parent, because the per-edit gate compiles the parent at once. In tests, assert returned values (`assert_eq!(cache.put(key, value), None)`) instead of binding them to `_`, which the gate rejects. A binary needs an integration test that runs it through `env!("CARGO_BIN_EXE_<name>")`, or mutation testing reports `main` as untested.
- Every new test must fail against a real fault; show the failing run. Assert the whole outcome (exact stdout, stderr and exit code; for a usage error, that stderr names the offending argument), not a prefix. For `--help`, assert exit 0, empty stderr and the usage line the spec gives; don't copy clap's full output into the test.
- A tool that reads files needs tests for a missing file, a file that opens but fails to read (a directory), a failed stdin read, a failed stdout write and a closed stdout.
- A small enum or struct of borrowed data, such as a parsed `Command<'_>` holding `&[u8]` fields, derives `Clone, Copy`; otherwise pedantic `needless_pass_by_value` rejects passing it by value.
- Pedantic clippy checks tests too: helpers outside `#[test]` functions use `expect`, not `unwrap`, and strings are built with `join` or `write!`, not `format!` inside `collect` or `push_str`.
- nextest's `slow-timeout` kills the test's whole process group, which bounds every process a test spawns and meets the subprocess-timeout rule for tests; don't write timeout code in tests.
- Name fixtures under `CARGO_TARGET_TMPDIR` with `std::process::id()`, because concurrent test runs share that directory.
- For a closed stdout, drop the reader of `std::io::pipe()` and pass its writer as stdout. For a failed write, run the binary as `sh -c 'ulimit -f 0 && trap "" XFSZ && exec "$0" "$@"'` with stdout redirected to a file, which fails with EFBIG; std treats EBADF on stdout as success, so a read-only descriptor doesn't work.
- cargo-mutants counts a timeout as a failure. A loop that stops when a comparison sees a repeating end-of-input value hangs once the comparison is mutated, so drive read loops by a pattern, `while let 1.. = reader.read_until(b'\n', &mut line)?`, or by an iterator.
