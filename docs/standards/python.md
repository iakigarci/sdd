# Python standards

Python-specific rules on top of `docs/CODING_STANDARDS.md`. Python is the second language: used when Go lacks a mature library for the core problem (see `docs/adr/0001-*.md`). The `modern-python` skill carries tooling detail.

## Toolchain

- Python ≥ 3.13, managed with `uv` (`uv.lock` committed).
- `ruff` for format and lint, `ty` for type checking, `pytest` + `pytest-cov` for tests, `pip-audit` for vulnerabilities.

## Layout

- `src/<package>/` layout; `tests/` mirrors it.
- Same DDD shape as Go (`docs/standards/go.md` → Architecture): `src/<package>/<context>/{domain,app,adapters}`, with `domain` and `app` free of framework and driver imports.
- Same infrastructure choices: PostgreSQL via `psycopg` 3, NATS JetStream via `nats-py`, gRPC via `grpcio` with the shared `buf` contracts.
- Entry points declared in `pyproject.toml` `[project.scripts]`.

## Code

- Type hints on every public function; the type checker passes with no ignores unless explained inline.
- Raise specific exception types; wrap with `raise X(...) from err` at module boundaries.
- `logging` with structured extras (or `structlog`), configured once at the entry point.
- `asyncio` only when the workload is I/O-bound and the libraries are async-native.

## Tests

- `pytest` with parametrised tests for input tables; fixtures over setup methods.
