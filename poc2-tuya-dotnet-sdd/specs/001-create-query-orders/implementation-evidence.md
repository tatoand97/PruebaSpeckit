# Implementation Evidence: Crear y consultar órdenes

**Date**: 2026-07-29
**Task baseline**: 33 initial tasks
**Final implementation status**: 33 completed, 0 failed, 0 pending

## Commands and Results

| Control | Command | Result |
|---|---|---|
| Tool restore | `dotnet tool restore` | PASS — dotnet-ef 10.0.10 restored |
| NuGet restore | `dotnet restore Orders.slnx` | PASS — 9 projects restored/up to date |
| Release build | `dotnet build Orders.slnx -c Release --no-restore` | PASS — 0 errors, 0 warnings |
| Unit tests | `dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj -c Release --no-build` | PASS — 21 passed, 0 failed, 0 skipped |
| Coverage | Coverlet MSBuild command from `quickstart.md` | PASS — total 94.48% line coverage |
| OpenAPI | `npx --yes @redocly/cli@2.41.1 lint specs/001-create-query-orders/contracts/openapi.yaml` | PASS — valid, 0 errors, 0 warnings |
| Whitespace | `git diff --check -- .` | PASS |

## Coverage

Report: `artifacts/coverage/coverage.json`

| Business-logic assembly | Line | Branch | Method |
|---|---:|---:|---:|
| `Orders.Application` | 97.40% | 83.33% | 95.83% |
| `Orders.Domain` | 90.00% | 91.66% | 92.85% |
| Total measured | 94.48% | 88.88% | 94.73% |

`Orders.Test` references only Domain and Application as productive feature projects. DTO-only HTTP
contracts, Program, DI, EF mappings, migrations and OpenAPI are not padded with artificial tests.

## Architecture Evidence

| Project | Actual project references | Result |
|---|---|---|
| `Common.Domain` | None | PASS |
| `Common.Infrastructure` | None | PASS |
| `Common.Presentation` | None | PASS |
| `Orders.Domain` | `Common.Domain` | PASS |
| `Orders.Application` | `Orders.Domain` | PASS |
| `Orders.Infrastructure` | `Orders.Application`, `Common.Infrastructure`, `Orders.Domain` | PASS |
| `Orders.Presentation` | `Orders.Infrastructure`, `Common.Presentation` | PASS |
| `Orders.Server` | `Common.Presentation`, `Orders.Presentation` | PASS |
| `Orders.Test` | `Orders.Domain`, `Orders.Application` | PASS |

Searches found no EF Core, ASP.NET Core, Infrastructure, Presentation or Wolverine references in
Domain/Application beyond their allowed dependencies. Presentation contains no `DbContext` or
direct repository access.

The implemented request flow is:

```text
OrdersEndpoints Minimal API
  -> IMessageBus.InvokeAsync
  -> CreateOrderHandler / GetOrderHandler
  -> Order aggregate
  -> IOrderRepository
  -> OrderRepository / OrdersDbContext
```

`Orders.Server/Program.cs` configures `DurabilityMode.MediatorOnly` and explicitly includes the
Application assembly for Wolverine handler discovery. No queues, brokers, outbox, inbox, sagas or
durable messaging exist.

## HTTP Contract Evidence

Contract: `specs/001-create-query-orders/contracts/openapi.yaml`

| Operation | Implementation | Contract responses | Result |
|---|---|---|---|
| `POST /orders` | `OrdersEndpoints.CreateOrder` | 201, 400, 500 | PASS |
| `GET /orders/{orderId}` | `OrdersEndpoints.GetOrder` | 200, 400, 404, 500 | PASS |

The contract declares a relative server and `security: []`, matching the deliberately unauthenticated
scope. Request/response properties, int32 quantity limits, UUID order IDs, validation Problem
Details, not-found Problem Details and trace identifiers align with source.

## Cross-Cutting and Safety Evidence

- FluentValidation covers create input and textual order-ID validation in Application.
- `OrdersExceptionHandler` maps module validation/duplicate/not-found outcomes; the common
  `GlobalExceptionHandler` is the safe unexpected-error fallback. Both use `IExceptionHandler` and
  `AddProblemDetails()`.
- Serilog provides structured console/request logging without request bodies or identifiers of
  clients/products.
- OpenTelemetry instruments ASP.NET Core and HttpClient without external exporter, collector or
  high-cardinality business tags.
- HealthChecks includes the scoped `OrdersDbContext` dependency and `/health` exposes only standard
  status output.
- Azure App Configuration is N/A for this greenfield local PoC because adding it would introduce an
  excluded external integration; configuration is read from standard ASP.NET providers.
- Searches found no hardcoded connection string, password, secret, token or API key in source.
- Searches found no Sonar, Veracode, SAST, DAST, integration/performance test, CI/CD, deployment,
  collector, dashboard, Azure-resource or distributed-messaging artifact.

## Implementation Adjustments and Resolved Failures

1. `dotnet add package` initially inherited central package management from the repository parent.
   The parent file was restored byte-for-byte (working hash equals `HEAD`), and a local
   `Directory.Packages.props` was added. `plan.md`, `research.md` and `tasks.md` were updated
   explicitly because isolation/reproducibility required this technical correction.
2. The first Release build found one missing namespace import for `AddOpenTelemetry`; the import was
   added and subsequent builds passed with zero warnings.
3. The first migration attempt used `--no-build` without a Debug build; the second showed that the
   startup project also needs private EF Design tooling. The private tooling reference was added,
   and `InitialCreate` was generated successfully.
4. The first Redocly lint found missing servers/security/license metadata. The OpenAPI source was
   corrected to reflect a relative server, explicitly anonymous access and internal PoC metadata;
   the final lint passed without warnings.

No functional requirement, scope boundary or approved architectural rule was weakened to resolve
these issues.

## Handoff

All 33 tasks have evidence. The next gate is `speckit-converge`.
