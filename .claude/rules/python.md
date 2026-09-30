# Python

These rules are requirements for Python work, not preferences: apply "least code" only among designs that meet them. Meet each rule's intent. Code that passes the gate but defeats a rule's purpose, such as catching `Exception` to hide a failure, is a violation. If a rule can't be met, name it and the reason in your report instead of working around it.

## Workflow

- In a repository with `scripts/agent-verify`, done means it exits 0. Elsewhere run the repository's formatter, linter, type checker and tests, or `ruff format --check`, `ruff check`, a strict type checker and `pytest`. Start a new project with `git clone ~/code/python-template <dir>`, then `git remote remove origin` and `git config core.hooksPath .githooks`; rename `src/ledger` and its tests to your package, update `pyproject.toml`, and run `uv sync`. Keep `py.typed` only in a library that others type-check against.
- In an existing repository without `scripts/agent-verify`, follow its conventions, add no lint or type errors to those it already has, and change only what the task needs: report a pre-existing bug you find instead of fixing it in the same change. Run mutation testing there only if the repository already uses it; otherwise its own test suite is the bar. Where its conventions require docstrings, write each in its neighbours' style: required docs are the exemption `~/.claude/CLAUDE.md` makes for required machine-read text.
- Add a dependency with `uv add`, and a tool with `uv add --dev`, which update `uv.lock`; the gate runs offline from the synced environment, so run `uv sync` after changing dependencies. Add one only when the spec needs it: the standard library comes first.
- In a repository with `scripts/agent-verify`, when tests or logic change, run mutation testing before reporting done: `rm -rf mutants && PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/mutmut run --max-children <a quarter of the cores, at least 1> '<package>.*'`, then `.venv/bin/mutmut results`, which lists every mutant not killed. mutmut exits 0 even when mutants survive and reuses old results, so only an empty `mutmut results` after a fresh run means every mutant was killed. mutmut credits only tests that call the code inside the pytest process: a mutant that only subprocess tests reach is listed as `no tests`. A mutant no test can kill means its code has no effect: restructure it instead of excluding it. Run mutmut rather than reading its source: it needs no configuration in the template, mutates operators, comparisons, numbers, keyword arguments (dropped or set to `None`) and every string literal (wrapped in `XX` or with its case changed), and `mutmut show <name>` prints the diff of each mutant it lists. The pre-push hook runs mutmut with pip-audit and the gate's self-test.
- Before reporting done, check the diff against each rule here and in `~/.claude/CLAUDE.md`, one at a time, and report every deviation with its reason.

## Design

- Annotate every function, parameter and return, and satisfy the strict type checker without `Any`, `cast` or ignore comments. A parameter takes the most abstract type the function uses (`Iterable`, `Sequence`, `Mapping`, `BinaryIO`); a return is concrete. Import names used only in annotations under `if TYPE_CHECKING:`; annotations are evaluated lazily, so this is safe at runtime. Model mutually exclusive states as `enum.Enum` members or frozen dataclasses joined in a union, and `match` them exhaustively, ending with `case _: assert_never(value)`.
- Parse untrusted input once at the boundary into precise types (frozen dataclasses whose constructor validates, `enum`, `pathlib.Path`), resolving implied values there too; interior code takes the parsed types. Name each limit the spec sets as a module-level `Final` constant used in the checks and messages; tests state the spec's literal value, so a wrong constant fails them.
- A library raises its own exceptions: one base class per concern with a subclass per failure, each named `...Error`, written as a `@dataclass` whose fields carry the failure's data and whose `__str__` renders the message; never raise bare `Exception` or `ValueError` for a domain failure. Catch only the exceptions a line can raise, re-raise with `raise ... from err`, and never swallow one. Only a program's entry point catches broadly, to turn failures into messages and exit codes. Check an invariant with an explicit `raise`, not `assert`, which `python -O` strips.
- Data classes are `@dataclass(frozen=True, slots=True)` unless mutation is the point. A field holding a value the spec calls secret is declared `field(repr=False)`, so no `repr`, log or traceback shows it.
- A module's public names are listed in `__all__`; everything else, a program's helpers included, starts with `_`. In a package others depend on across releases, removing or changing a public name or signature breaks callers: prefer adding a new name, and release a new major version when a break is unavoidable.
- Give every subprocess and network call a timeout. In asyncio code never block the loop (no `time.sleep`, blocking I/O or CPU-heavy work in `async def`; use `asyncio.to_thread`), bound waits with `asyncio.timeout`, run concurrent tasks in a `TaskGroup`, keep the accept path to accepting and spawning, and shut down on signals with `loop.add_signal_handler`, letting each task finish its current request.
- No mutable default arguments and no mutable module-level state; pass dependencies in.
- Escalate abstraction only as needed: a function, then a dataclass or enum, then a `Protocol`; no class with a single method where a function works, and no metaprogramming where plain code works.
- Fix a complexity failure by flattening first (guard clauses, early `return`, `continue`), then deleting, then extracting along a named seam.

## Programs

A command-line program's entry point `main(argv: Sequence[str] | None = None) -> int` parses arguments with `argparse`, returns an exit code and reports runtime failures on stderr as `<prog>: <what failed>: <reason>`. Helpers raise the program's own exceptions and only `main` turns them into messages and exit codes. `__main__.py` is `if __name__ == "__main__": raise SystemExit(main())`, the only place that may raise `SystemExit`; the console script calls `main` directly. Output goes through `sys.stdout`, never `print`, and one function writes and flushes it: a broken pipe there means success, and after any failed stdout write it points stdout at `os.devnull`, because otherwise the interpreter's final flush fails again and exits 120. argparse writes `--help` and `--version` to buffered stdout and then raises `SystemExit`, so flush through the same function there. Give `parse_args` a typed namespace, since plain `Namespace` attributes are `Any`, and put each option's default on it rather than in `add_argument`; argparse leaves a default the namespace already has. Pass exception fields by keyword (`raise _ReadError(source="stdin", error=error) from error`); ruff reads a positional string literal as a message. This shape passes the template's gate, and the tests below kill every mutant in it:

```python
class _Arguments(argparse.Namespace):
    files: Sequence[Path] = ()
    width: int = _DEFAULT_WIDTH


class _CliError(Exception):
    pass


@dataclass
class _ReadError(_CliError):
    source: str
    error: OSError

    @override
    def __str__(self) -> str:
        return f"{self.source}: {self.error.strerror}"


@dataclass
class _WriteError(_CliError):
    error: OSError

    @override
    def __str__(self) -> str:
        return f"stdout: {self.error.strerror}"


def main(argv: Sequence[str] | None = None) -> int:
    try:
        arguments = _parse(argv)
        total = _count_all(arguments.files)
        _write_stdout(b"%*d\n" % (arguments.width, total))
    except _CliError as failure:
        sys.stderr.write(f"{_PROG}: {failure}\n")
        return 1
    return 0


def _parse(argv: Sequence[str] | None) -> _Arguments:
    parser = argparse.ArgumentParser(prog=_PROG)
    parser.add_argument("--width", type=int, metavar="N")
    parser.add_argument("files", nargs="*", type=Path)
    try:
        return parser.parse_args(argv, namespace=_Arguments())
    except SystemExit:
        _write_stdout(b"")
        raise


def _write_stdout(data: bytes) -> None:
    try:
        sys.stdout.buffer.write(data)
        sys.stdout.flush()
    except BrokenPipeError:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
    except OSError as error:
        os.dup2(os.open(os.devnull, os.O_WRONLY), sys.stdout.fileno())
        raise _WriteError(error=error) from error
```

## Performance

These defaults apply on any path that runs once per input item:

- Stream input instead of reading it whole: iterate lines from `sys.stdin.buffer` or a file opened in binary mode, and stay in `bytes` when the spec treats input as bytes. Write output through one buffered stream (`sys.stdout.buffer.write`, or build a list and `b"".join` it once) instead of a `print` per item.
- Build strings with `join`, not `+=` in a loop; test membership in a `set` or `dict`, not a `list`; compile a regex once, outside the loop; count into one `collections.Counter` shared by every input; take the top N with `heapq.nlargest(n, ...)` instead of sorting everything.
- For CPU-bound work across cores use `concurrent.futures.ProcessPoolExecutor`; threads and asyncio suit I/O-bound work. When the spec sets a performance target, measure the real program on realistic input (median of several runs), profile with `python -m cProfile` before optimizing past these defaults, and keep the fastest correct version.

## Tests

- Tests live in `tests/` and use pytest. Because mutmut credits only in-process calls, test a program through `main(argv)`: feed stdin with `monkeypatch.setattr("sys.stdin", io.TextIOWrapper(io.BytesIO(data)))` and assert both `main`'s return value and `capsysbinary.readouterr() == (stdout, stderr)` exactly; for an argparse exit, assert `SystemExit`'s `code`. Assert whole output, `--help` included, because mutmut mutates every string literal; set `monkeypatch.setenv("COLUMNS", "80")` so argparse wraps help the same everywhere. Add one subprocess test, with a timeout, for the `sys.executable -m <package>` entry point. Patch `sys` attributes by dotted name, because the gate rejects `sys` used as a value. For a usage error, assert that stderr names the offending argument. Where the spec leaves text free, such as an error reason, assert the part it fixes and the exception's type, not a copy of the implementation's wording. Cases that differ only in data are one `@pytest.mark.parametrize` table.
- Write tests first against stubs that return a wrong value, so each test fails for its own reason, and show each new test failing against a real fault. Before running tests against an injected fault or its restored original, delete `__pycache__` and set `PYTHONDONTWRITEBYTECODE=1`: Python reuses cached bytecode when an edit keeps a file's size and modification second. A library's own tests cover every boundary its spec names through its public API.
- A tool that reads files needs tests for a missing file, a directory, a failed stdin read, a failed stdout write and a stdout whose reader has exited (broken pipe); cover the last two for `--help` too. For a failed read or write, give the stream a real descriptor opened for the other direction, which fails with EBADF: `os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT), encoding="utf-8")` as stdin, or `os.fdopen(os.open(path, os.O_RDONLY), "w", encoding="utf-8")` as stdout. For a broken pipe, close the read end of `os.pipe()` and pass the write end as stdout. Open each in a `with` block around the call so it is closed:

```python
def test_failed_stdout_write_is_reported(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsysbinary: pytest.CaptureFixture[bytes],
) -> None:
    monkeypatch.setattr("sys.stdin", io.TextIOWrapper(io.BytesIO(b"a\n")))
    (tmp_path / "out").touch()
    descriptor = os.open(tmp_path / "out", os.O_RDONLY)
    with os.fdopen(descriptor, "w", encoding="utf-8") as read_only:
        monkeypatch.setattr("sys.stdout", read_only)
        assert main([]) == 1
    assert capsysbinary.readouterr() == (b"", b"lines: stdout: Bad file descriptor\n")
```

- No test may be able to hang: give every subprocess, socket and wait in a test a timeout, feed a child's stdin from a file, and stop and reap a server a test starts, failures included, with a fixture's teardown or a context manager. Never bind a fixed port: listen on port 0 and read the bound address, and check a default by parsing arguments instead of over the network. Put files under `tmp_path`, never in the working directory.
