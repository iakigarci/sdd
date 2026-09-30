# Go standards

Go-specific rules on top of `docs/CODING_STANDARDS.md`. The `golang-*` skills in `.agents/skills/` carry the detail; this file holds the choices they leave open, and it wins where they disagree.

## Toolchain

- Go version pinned in `mise.toml` and `go.mod`.
- `golangci-lint` v2 with `.golangci.yml` (formatting via `gofumpt` + `goimports`, `gosec` for SAST, `depguard` for the layer rule below), `govulncheck`, race detector on in tests.
- `buf` for protobuf lint, breaking-change checks and code generation; `sqlc` for typed queries. Both run through `just`.

## Architecture: domain-driven design

Each bounded context is one package tree under `internal/`. Its language lives in `GLOSSARY.md` (one per context via `GLOSSARY-MAP.md` once there are several), and its hard-to-reverse decisions in `docs/adr/`.

```
cmd/<service>/main.go          wiring only: config, pools, connections, servers, graceful shutdown
internal/<context>/
  domain/                      entities, value objects, aggregates, domain events, repository ports
  app/                         use cases (commands and queries); owns transactions; emits events through ports
  adapters/
    postgres/                  repository implementations, sqlc output, outbox writer
    nats/                      event publishers and consumers
    http/                      Gin handlers, request/response DTOs, error mapping
    grpc/                      gRPC server implementation
internal/platform/             shared infrastructure: config, pgx pool, NATS connection, logging, telemetry
api/proto/<context>/v1/        protobuf contracts (buf module)
db/migrations/                 goose SQL migrations
db/queries/                    sqlc query files
```

- **Dependency rule:** `adapters → app → domain`. `domain` imports the standard library only; `domain` and `app` never import Gin, pgx, NATS, gRPC or `net/http`. `depguard` enforces this in `just lint`.
- Aggregates guard their invariants: state changes go through methods, fields stay unexported, constructors validate. One transaction changes one aggregate.
- Value objects for domain concepts (IDs, money, email), never bare strings or ints.
- Repository ports are interfaces declared in `domain` (or `app`), implemented in `adapters/postgres`. This is the one place an interface with a single production implementation is expected: it is the seam for fakes in tests.
- Handlers and consumers stay thin: decode → call one `app` use case → encode. Business rules live in `domain` and `app` only.
- Contexts talk to each other through their `app` API or through events, never by reading another context's tables.

## Communication

| Path | Use |
|---|---|
| Clients → service | HTTP JSON with Gin |
| Service → service, synchronous | gRPC (only when the system is split into microservices; inside one binary, contexts call each other's `app` layer directly) |
| Service → service, asynchronous | NATS JetStream domain events |

### HTTP (Gin)

- `gin.New()` with explicit middleware: recovery, request ID, `slog` request logging, per-request timeout. `gin.ReleaseMode` outside local runs.
- The engine is served by an `http.Server` with read/write/idle timeouts and graceful shutdown on SIGTERM.
- Bind and validate at the edge (`ShouldBindJSON` + `binding` tags); map domain and app errors to HTTP statuses in one error mapper, with a consistent problem-style JSON body.
- Routes are versioned (`/v1/...`).

### gRPC

- Contracts in `api/proto/<context>/v1`, generated with `buf generate`; `buf lint` and `buf breaking` against `main` run in `just check`.
- Every call carries a deadline; errors return `status` codes, never raw Go errors.
- Interceptors for logging, recovery and metrics; health service (`grpc.health.v1`) registered.

### NATS JetStream

- Subjects: `<context>.<aggregate>.<event>.v<n>`, e.g. `billing.invoice.issued.v1`. Payloads are versioned; new fields are additive.
- Publishing is transactional: the event is written to an outbox table in the same Postgres transaction as the state change, and a relay publishes it with `Nats-Msg-Id` set for de-duplication. No dual writes.
- Consumers are durable, ack explicitly, are idempotent, and have `MaxDeliver` with a dead-letter subject.
- Streams and consumers are declared in code at startup (idempotent create-or-update), not by hand.

### PostgreSQL

- `pgx/v5` with `pgxpool`; no ORM. Queries are written in `db/queries/` and generated with `sqlc`.
- Migrations with goose, SQL files, forward-only, safe to run before the code that needs them.
- Transactions are opened in the `app` layer through a transaction port, and passed to repositories; repositories never commit.
- Every query takes a `context.Context`; the pool has max-connection and statement timeouts configured.

## Code

- `context.Context` is the first parameter of anything that does I/O or blocks; never stored in a struct.
- Wrap errors with `fmt.Errorf("doing x: %w", err)`; inspect with `errors.Is`/`errors.As`; sentinel errors named `ErrX`. Domain errors are typed so adapters can map them.
- Every goroutine has an owner that cancels it and waits for it (`errgroup`, `sync.WaitGroup`).
- Outside repository ports: accept interfaces, return concrete types, define interfaces where they are consumed.
- `log/slog` for logging, injected rather than global.
- Dependencies are injected by hand: constructors take what they need, and `cmd/<service>/main.go` wires them. No DI library or container.
- Configuration from environment variables into one typed struct, validated at startup in `internal/platform`.
- Exported identifiers keep backward compatibility; `go mod tidy` leaves no diff.

## Default libraries

Standard library first. Anything outside this table is justified in the PR and added here; libraries the `golang-*` skills suggest (`samber/oops`, `samber/lo`, …) count as outside.

| Need | Default |
|---|---|
| HTTP API | `github.com/gin-gonic/gin` |
| Service-to-service RPC | `google.golang.org/grpc`, `google.golang.org/protobuf`, `buf` |
| Messaging | `github.com/nats-io/nats.go` (`jetstream` package) |
| PostgreSQL | `github.com/jackc/pgx/v5`, `sqlc`, `github.com/pressly/goose/v3` |
| Integration tests | `github.com/testcontainers/testcontainers-go` (postgres, nats modules) |
| Logging | `log/slog` |
| Concurrency | `golang.org/x/sync/errgroup` |
| Tests | `testing` with table-driven subtests |

## Tests

- `domain`: plain unit tests, no fakes needed.
- `app`: unit tests with in-memory fakes of the ports.
- `adapters`: integration tests against real Postgres and NATS via testcontainers, behind `//go:build integration`, run by `just test-integration` and the `integration` CI job. Container helpers (start, migrate, connect) live once in `internal/platform/testinfra`, behind the same build tag.
- HTTP handlers through `httptest` against the Gin engine; gRPC through `bufconn`.
- Table-driven tests with `t.Run`, `t.Parallel()` where safe, helpers call `t.Helper()`.
- Benchmarks (`BenchmarkX`) for any criterion that states a latency or throughput target.
