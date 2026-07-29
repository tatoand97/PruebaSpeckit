# PoC 2 Results — `dotnet-sdd`

**Application**: Orders

**Feature**: Crear y consultar órdenes

**Audit date**: 2026-07-29

**Code freeze**: Started after the first clean `speckit-converge`; no code corrections were made
during this audit.

## Executive Result

Spec Kit plus `dotnet-sdd` governed specification, planning, tasks, implementation and convergence
without technical instructions added by the experiment prompt. The resulting feature has one DDD
module, the four required layers, SQL Server persistence through Repository Pattern, Minimal APIs
delegating to Wolverine, standardized Problem Details, local observability and unit-test evidence.

The Local Definition of Done has no FAIL controls. One integration-level deviation remains:
`specify integration status` reports `ERROR unsafe-multi-install` because the pre-existing Copilot
integration is not declared multi-install safe, even though Codex is installed, active and contains
the preset-composed Skills.

## A. SDD Execution

| Metric | Result | Evidence |
|---|---|---|
| Spec Kit version | 0.14.3 | `specify version` |
| Preset | `dotnet-sdd` 1.0.0, enabled, priority 10 | `specify preset info dotnet-sdd` |
| Active integration | Codex | `.specify/integration.json`; `integration status` |
| Installed integrations | Copilot and Codex | `integration status` |
| Constitution executions | 1 | `Orders Constitution` v1.0.0 |
| Specify executions | 1 | `specs/001-create-query-orders/spec.md` |
| Clarify executions | 1 | Five entries under `Clarifications` |
| Checklist executions | 1 | `checklists/design.md`; the specification command also created `requirements.md` |
| Analyze executions | 2 | Run 1: 3 findings; run 2: 0 blocking findings |
| Initial implement executions | 1 | 33/33 tasks completed |
| Implement -> converge cycles | 1 | First converge found 0 gaps and added 0 tasks |
| Human interventions during flow | 0 | All five business answers were pre-approved in the initial request |
| Commits / pushes / PRs | 0 / 0 / 0 | No publishing command executed |

### Integration status

Codex is the default active integration and `.agents/skills/` contains all required Speckit Skills.
The five preset-customized Skills declare `source: preset:dotnet-sdd`. The CLI nevertheless reports:

- `ERROR unsafe-multi-install`: Copilot is not declared multi-install safe.
- 5 modified managed files for Copilot and 5 for Codex; these are the preset-composed command files.
- No missing managed files and no invalid manifest paths.

The experiment continued because preset composition for Codex was present and verified; Copilot was
not removed or overwritten.

## B. Specification

| Metric | Result |
|---|---:|
| Functional Requirements | 15 |
| Non-Functional Requirements | 3 |
| User Stories | 2 |
| Acceptance scenarios | 8 |
| Formal clarifications | 5 |
| Specification quality checklist | 16/16 PASS |
| Design quality checklist | 36/36 PASS after 4 source corrections |

### Final scope

- Create an order from one customer identifier and one or more product/quantity pairs.
- Reject the complete request atomically when any input is invalid.
- Reject and identify an exact, case-sensitive duplicate product.
- Create a new GUID for every valid request, including requests with identical data.
- Persist and retrieve an order by exact identifier.
- Allow any requester who knows the exact identifier to query it.
- Consider 25 simultaneous users as a requirement without executing performance testing locally.

### Final out of scope

Payments, inventory, discounts, shipping, cancellation, modification, authentication, external
integrations, idempotency, integration/performance/security-pipeline tests, CI/CD and deployment.

### Clarified and inferred behavior

The five supplied decisions cover query access, non-idempotent identical requests, opaque
non-whitespace customer/product identifiers, atomic duplicate rejection and 25 simultaneous users.
During checklist remediation, Codex resolved two additional minor boundaries: opaque identifiers are
preserved and compared ordinally/case-sensitively, and quantity uses the documented positive
`int32` range 1..2,147,483,647.

## C. Planning

### Final structure and DDD modules

One real DDD module was identified:

| Module | Capability | Reason |
|---|---|---|
| `Orders` | Create and retrieve orders | The order aggregate and its rules are the only business capability in scope |

No `Customers`, `Products`, `Persistence` or transport module was invented. Customer and product
identifiers are opaque values, not independently managed capabilities.

### Main technical decisions

- .NET 10 / ASP.NET Core modular monolith.
- Projects `Domain`, `Application`, `Infrastructure`, `Presentation` for the Orders module.
- Minimal API -> Wolverine `IMessageBus.InvokeAsync` -> Application handler -> Domain ->
  `IOrderRepository` -> EF Core Infrastructure.
- Wolverine 6.24.0 with `DurabilityMode.MediatorOnly`; no durable/distributed messaging.
- FluentValidation in Application.
- Global `IExceptionHandler` fallback plus module-owned `OrdersExceptionHandler`, all with Problem
  Details and `traceId`.
- Serilog console/request logging, OpenTelemetry ASP.NET Core/HttpClient instrumentation and EF
  HealthCheck.
- Azure App Configuration: N/A because no existing remote standard exists and adding one would
  create an excluded external integration.
- Unit tests only with xUnit and Coverlet.

### Persistence

**Selected**: EF Core 10.0.10 with SQL Server.

The order is a stable aggregate, header and items must be saved atomically, duplicate items are
forbidden and retrieval is by exact key. SQL Server represents the structured aggregate and
transaction directly. EF Core + MongoDB was rejected because the feature has no variable document
shape, document-specific query or scale need. Memory/files were not supported durable options, and
a generic repository was rejected as unnecessary abstraction.

### Other alternatives considered

- CLI vs HTTP service.
- MVC controllers vs the required Minimal APIs.
- Direct handler calls vs Wolverine mediator.
- Sequential IDs vs independent GUID generation.
- Custom clock interface vs built-in `TimeProvider`.
- Endpoint-local try/catch vs registered exception handlers.
- A Common handler depending on Orders exceptions vs module-owned mappings.
- Global tools vs versioned local tooling.

## D. Tasks

| Metric | Result |
|---|---:|
| Initial tasks | 33 |
| Tasks added by converge | 0 |
| Final tasks | 33 |
| Completed | 33 |
| Pending / failed | 0 / 0 |
| Parallelizable `[P]` | 5 |

### Distribution by phase

| Phase | Tasks |
|---|---:|
| Setup | 4 |
| Foundational | 3 |
| User Story 1 — create | 12 |
| User Story 2 — query | 4 |
| Local verification / cross-cutting | 10 |

All 15 FRs, 3 NFRs, 2 stories and 5 success criteria map to at least one task. No task lacks a
requirement, plan, contract, Constitution or Definition-of-Done justification.

## E. Implementation

### Final code tree

```text
Orders/
├── Api/
│   └── Orders.Server/
│       ├── Orders.Server.csproj
│       ├── Program.cs
│       ├── appsettings.json
│       ├── appsettings.Development.json
│       └── Properties/launchSettings.json
├── Common/
│   ├── Common.Domain/Common.Domain.csproj
│   ├── Common.Infrastructure/Common.Infrastructure.csproj
│   └── Common.Presentation/
│       ├── Common.Presentation.csproj
│       ├── GlobalExceptionHandler.cs
│       ├── ObservabilityExtensions.cs
│       └── ServiceCollectionExtensions.cs
└── Modules/
    └── Orders/
        ├── Domain/
        │   ├── Orders.Domain.csproj
        │   ├── Order.cs
        │   ├── OrderItem.cs
        │   └── DuplicateProductException.cs
        ├── Application/
        │   ├── Orders.Application.csproj
        │   ├── IOrderRepository.cs
        │   ├── OrderResult.cs
        │   ├── OrderNotFoundException.cs
        │   ├── ServiceCollectionExtensions.cs
        │   ├── CreateOrder/
        │   └── GetOrder/
        ├── Infrastructure/
        │   ├── Orders.Infrastructure.csproj
        │   ├── ServiceCollectionExtensions.cs
        │   └── Persistence/
        │       ├── OrdersDbContext.cs
        │       ├── OrderConfiguration.cs
        │       ├── OrderRepository.cs
        │       └── Migrations/
        ├── Presentation/
        │   ├── Orders.Presentation.csproj
        │   ├── OrdersContracts.cs
        │   ├── OrdersEndpoints.cs
        │   ├── OrdersExceptionHandler.cs
        │   └── ServiceCollectionExtensions.cs
        └── Tests/
            └── Orders.Test/
                ├── Orders.Test.csproj
                ├── TestDoubles.cs
                ├── Domain/OrderTests.cs
                └── Application/
                    ├── CreateOrderTests.cs
                    └── GetOrderTests.cs
```

### Projects, responsibilities and actual references

| Project | Responsibility | Actual project references |
|---|---|---|
| `Common.Domain` | Mandatory common domain boundary; no feature behavior | None |
| `Common.Infrastructure` | Mandatory common infrastructure boundary; no concrete feature persistence | None |
| `Common.Presentation` | Safe unexpected-error fallback and observability registration | None |
| `Orders.Domain` | Order aggregate and invariants | `Common.Domain` |
| `Orders.Application` | Commands, queries, handlers, validators, results and repository contract | `Orders.Domain` |
| `Orders.Infrastructure` | EF Core SQL Server context, mapping, migration and repository | `Orders.Application`, `Common.Infrastructure`, `Orders.Domain` |
| `Orders.Presentation` | Minimal endpoints, HTTP contracts and module exception mapping/composition | `Orders.Infrastructure`, `Common.Presentation` |
| `Orders.Server` | Composition root | `Common.Presentation`, `Orders.Presentation` |
| `Orders.Test` | xUnit unit tests for Domain/Application | `Orders.Domain`, `Orders.Application` |

Search evidence found no forbidden framework/infrastructure dependencies in Domain/Application and
no direct persistence access in Presentation.

## F. Dependencies

### Runtime

| Package | Version | Usage |
|---|---:|---|
| `WolverineFx` | 6.24.0 | Mediator and `IMessageBus` |
| `FluentValidation.DependencyInjectionExtensions` | 12.1.1 | Application validation/registration |
| `Microsoft.EntityFrameworkCore.SqlServer` | 10.0.10 | SQL Server persistence |
| `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` | 10.0.10 | DbContext health |
| `Serilog.AspNetCore` | 10.0.0 | Structured/request logging |
| `OpenTelemetry.Extensions.Hosting` | 1.17.0 | Telemetry host integration |
| `OpenTelemetry.Instrumentation.AspNetCore` | 1.17.0 | HTTP server telemetry |
| `OpenTelemetry.Instrumentation.Http` | 1.17.0 | HttpClient telemetry |

### Testing

| Package | Version |
|---|---:|
| `Microsoft.NET.Test.Sdk` | 18.8.1 |
| `xunit` | 2.9.3 |
| `xunit.runner.visualstudio` | 3.1.5 |
| `coverlet.msbuild` | 10.0.1 |

### Tooling

| Tool/package | Version | Scope |
|---|---:|---|
| `Microsoft.EntityFrameworkCore.Design` | 10.0.10 | Private build/design dependency |
| `dotnet-ef` | 10.0.10 | Local tool manifest |
| `@redocly/cli` | 2.41.1 | Exact-version transient OpenAPI lint |

There are 15 unique external package/tool IDs across runtime, testing and tooling.

## G. Definition of Done

The controls below come from the installed preset/Constitution, not from the experiment prompt.

| Control | Status | Concrete evidence |
|---|---|---|
| All feature tasks complete | PASS | 33/33 `[X]`, 0 pending |
| `dotnet restore` | PASS | `dotnet restore Orders.slnx` |
| Release build | PASS | 0 errors |
| Zero .NET warnings | PASS | Release build: 0 warnings |
| All unit tests pass | PASS | 21 passed, 0 failed, 0 skipped |
| Business logic line coverage >=80% | PASS | 94.48% total; Application 97.4%; Domain 90% |
| xUnit used | PASS | `xunit` 2.9.3 and `Orders.Test` |
| Coverlet used | PASS | `coverlet.msbuild` 10.0.1; `coverage.json` |
| Tests are meaningful | PASS | Domain invariants, validators, handlers, zero-write and not-found behavior |
| OpenAPI exists for HTTP | PASS | `specs/001-create-query-orders/contracts/openapi.yaml` |
| OpenAPI matches endpoints | PASS | POST `/orders`, GET `/orders/{orderId}` |
| OpenAPI represents relevant errors | PASS | 400/404/500 and Problem schemas |
| Clean Architecture | PASS | Actual `.csproj` reference audit |
| Real DDD module | PASS | Single `Orders` business capability |
| Domain/Application/Infrastructure/Presentation exist | PASS | Four module projects |
| Authorized dependency directions | PASS | Actual references in section E |
| Repository Pattern | PASS | `IOrderRepository` + `OrderRepository`; EF only in Infrastructure |
| Wolverine only as mediator | PASS | `DurabilityMode.MediatorOnly`; no transports/durability artifacts |
| Minimal APIs | PASS | `MapPost`/`MapGet` in `OrdersEndpoints` |
| FluentValidation | PASS | Create/query validators and handler validation |
| Serilog | PASS | Server structured console/request logging |
| OpenTelemetry | PASS | ASP.NET Core/HttpClient instrumentation |
| HealthChecks | PASS | `AddDbContextCheck<OrdersDbContext>` and `/health` |
| Azure App Configuration | NOT APPLICABLE | No existing standard; external integration is out of local scope |
| No hardcoded secrets | PASS | Source/config search; connection string supplied externally |
| HTTP errors use Problem Details | PASS | Two `IExceptionHandler` implementations + `AddProblemDetails()` |
| `speckit-converge` clean | PASS | First run: 0 findings, 0 appended tasks |

**Definition-of-Done FAIL controls**: none.

## H. Build and Tests — Audit Rerun

The following commands were rerun after code freeze:

| Audit | Result |
|---|---|
| `dotnet tool restore` | PASS |
| `dotnet restore Orders.slnx` | PASS |
| `dotnet build Orders.slnx -c Release --no-restore` | PASS |
| `dotnet test ... -c Release --no-build` | PASS |
| Coverlet threshold command | PASS |
| Redocly OpenAPI lint | PASS |

- Restore: PASS.
- Release build: PASS.
- Errors: 0.
- .NET warnings: 0.
- Unit tests executed: 21.
- Unit tests passed: 21.
- Unit tests failed: 0.
- Unit tests skipped: 0.
- Total measured line coverage: 94.48%.
- `Orders.Application` line coverage: 97.40%.
- `Orders.Domain` line coverage: 90.00%.
- Coverage report: `artifacts/coverage/coverage.json`.

## I. HTTP Contract

**Location**: `specs/001-create-query-orders/contracts/openapi.yaml`

| Endpoint | Implemented | Documented responses | Result |
|---|---|---|---|
| `POST /orders` | Yes | 201, 400, 500 | PASS |
| `GET /orders/{orderId}` | Yes | 200, 400, 404, 500 | PASS |

The contract documents request/response schemas, int32 quantity boundaries, UUID order IDs,
Location on create, validation errors, not found, unexpected errors, `traceId`, explicitly
anonymous access (`security: []`) and a relative server. Redocly 2.41.1 reports a valid OpenAPI 3.1
document with zero errors and zero warnings.

**Contract/code inconsistencies**: none detected.

## J. Architecture Audit

| Preset / Constitution rule | Status | Evidence |
|---|---|---|
| Specification First and artifact traceability | PASS | spec -> plan -> tasks -> evidence; explicit SDD corrections recorded |
| Modular monolith with real DDD boundaries | PASS | One `Orders` module, no technical modules |
| Four module layers | PASS | Four `.csproj` projects |
| Clean dependency direction | PASS | Actual project references |
| Domain free of upper/framework layers | PASS | Reference and namespace search |
| Application free of concrete persistence/Presentation | PASS | Only Domain reference; repository abstraction |
| Infrastructure owns EF Core | PASS | DbContext/mapping/repository only under Infrastructure |
| Presentation is thin and has no persistence access | PASS | Endpoints only map and invoke Wolverine |
| Server is composition root | PASS | Program registers/mounts shared and module components |
| Simplicity / justified abstractions | PASS | One specific repository; no services/factories/generic repositories/events |
| .NET 10 / nullable / implicit usings | PASS | `global.json`, `Directory.Build.props` |
| Wolverine mediator only | PASS | Explicit mode and handler assembly; no messaging infrastructure |
| EF Core + one supported engine justified | PASS | SQL Server only; Mongo rejected in research |
| FluentValidation | PASS | Application validators |
| HTTP OpenAPI and standardized safe errors | PASS | Contract + Problem Details handlers |
| Unit tests and >=80% business coverage | PASS | Audit results |
| Serilog, OpenTelemetry and HealthChecks considered/applied | PASS | Source/configuration evidence |
| Azure App Configuration considered | NOT APPLICABLE | Concrete plan justification |
| Reproducible local commands/tooling | PASS | Local SDK/tool/package versions and quickstart |
| Later SDLC gates excluded | PASS | No local artifacts for those gates |

## K. Work Outside Scope

A filename/content audit found no generated or executable artifact for:

- Sonar or Veracode;
- SAST or DAST;
- integration testing;
- performance testing;
- CI/CD or deployment;
- collectors, dashboards or Azure resources; or
- queues, brokers, outbox, inbox, sagas or durable messaging.

These terms appear only in specification/plan/task scope guards and audit evidence describing their
exclusion. No unexpected later-SDLC work was implemented.

## L. Deviations, Ambiguities and Agent Inferences

### Preset rules ignored

None detected.

### Deviations and operational issues

1. `specify` was installed at `C:\Users\PC\.local\bin\specify.exe` but that directory was absent
   from the session `PATH`; commands used the existing absolute executable.
2. `integration status` remains ERROR because Copilot is not declared multi-install safe. Codex is
   nevertheless active and correctly composed with the preset. Copilot was preserved as required.
3. Analyze run 1 found an impossible Common-to-module exception dependency, missing local
   `dotnet-ef` reproducibility and an unspecified OpenAPI lint command. Plan/research/quickstart/tasks
   were corrected; analyze run 2 passed.
4. During implementation, `dotnet add package` inherited the repository parent's central package
   file. The parent file was restored byte-for-byte (working hash equals `HEAD`), a local
   `Directory.Packages.props` was created and plan/research/tasks were updated explicitly.
5. Intermediate build, migration and OpenAPI-lint attempts failed before final evidence. Each was
   corrected before code freeze and is recorded in `implementation-evidence.md`.

### Ambiguous preset points

- Azure App Configuration is required only according to an existing applicable standard. This
  greenfield consumer has no such standard and prohibits external integration, so the plan marked it
  N/A. The preset could make this greenfield rule more explicit.
- The core tasks command says tests are optional, while the preset mandates unit tests and coverage.
  The preset override correctly took precedence.
- The generic plan flow describes dispatching research agents, while the preset explicitly forbids
  agents for research. The preset restriction correctly took precedence.

### Decisions inferred by Codex

- HTTP was selected from the required service interface plus the preset's Minimal API baseline.
- SQL Server was selected over MongoDB using aggregate atomicity and stable relational shape.
- Identifier equality/preservation and `int32` quantity range were resolved as minor functional
  boundaries during checklist remediation.
- Redocly CLI was selected as fixed-version local audit tooling because no OpenAPI validator was
  supplied and PyYAML was unavailable.
- A module-owned exception handler plus common fallback was selected to preserve dependency
  direction.

### Template/command conflicts

No unresolved conflict remains in generated artifacts. The two generic-vs-preset tensions above
were resolved by the documented preset override semantics.

## PoC 1 vs PoC 2

This comparison was performed only after PoC 2 had converged, its code had been frozen and its
audit had finished. PoC 1 was read-only throughout this phase.

### Measurement basis

- A normative requirement is an `FR` plus an `SR`/`NFR`; success criteria are reported separately.
- Feature SDD artifacts include the files under the active feature directory, including checklists
  and the OpenAPI contract, but exclude implementation source and repository-level configuration.
- LOC is the approximate count of nonblank C# lines, excluding `bin`/`obj`. Productive LOC excludes
  generated migrations, which are reported separately.
- External package count uses unique direct runtime, test and tooling IDs, not transitive packages.
- Human-intervention counts use the recorded user turns for the experiment. Ordinary phase
  invocations and business answers are shown separately so the number is not subjective.

### Objective metrics

| Metric | PoC 1 | PoC 2 |
|---|---:|---:|
| Normative requirements | 28: 21 FR + 7 SR | 18: 15 FR + 3 NFR |
| Success criteria | 6 | 5 |
| User stories / acceptance scenarios | 3 / 11 | 2 / 8 |
| Initial tasks | 37 | 33 |
| Tasks appended by converge | 2 (`T038`–`T039`) | 0 |
| Final tasks complete | 39/39 | 33/33 |
| Feature SDD artifacts | 9 | 10 |
| Projects | 2 | 9 |
| Productive C# files / nonblank LOC | 5 / ~1,352 | 25 / ~601 |
| Generated migration LOC | 0 | ~175 |
| Unit-test-only LOC | ~98 (`ValidationTests.cs`) | ~256 |
| All automated test-code LOC | ~2,697 | ~256 |
| Unique external package/tool IDs | 3 | 15 |
| Analyze executions | 4 | 2 |
| Implement -> converge cycles | 2 | 1 |
| Follow-up human turns after the experiment request | 23 | 0 |
| Total recorded experiment user turns | 24: 19 commands/continuations + 5 answers | 1 all-in-one instruction |
| Additional environment intervention | Exact .NET 10.0.302 SDK had to be installed between two implement attempts | None |
| Final local DoD | PASS | PASS |

The PoC 1 user-turn count spans repository preparation through its final clean converge. It does not
claim that every turn contained a new design decision: many were explicit commands to advance or
repeat a phase. PoC 2 received the five comparable business decisions in its initial instruction and
needed no follow-up answer, approval or environment change.

### Solution structure

**PoC 1** uses one `Orders.Api` web project and one `Orders.Api.Tests` project. Domain records,
transport contracts, validation, HTTP composition, operational logging and direct SQLite persistence
are concentrated in five productive files. Its test project contains unit, API contract, persistence,
atomicity, restart, real-Kestrel boundary, concurrency, logging/security and load harnesses.

**PoC 2** uses a preset-shaped modular monolith:

- one `Orders.Server` composition root;
- `Common.Domain`, `Common.Infrastructure` and `Common.Presentation`;
- `Orders.Domain`, `Orders.Application`, `Orders.Infrastructure` and `Orders.Presentation`; and
- one `Orders.Test` unit-test project.

PoC 2 therefore has more project/reference/package ceremony but smaller productive and test-code
volumes. PoC 1 has less structural ceremony but substantially more behavioral and operational test
code concentrated in a single test project.

### Analyze, convergence and DoD evidence

- PoC 1 required four read-only analyze executions with directed remediation between runs. Its
  first converge found two MEDIUM partial gaps in per-order load validation and operational logging,
  appended `T038`–`T039`, and its second converge was clean.
- PoC 2 required two analyze executions: the first found three design/tooling inconsistencies and
  the second was clean. Its first converge was clean and did not alter `tasks.md`.
- PoC 1's recorded final `scripts/verify.ps1` gate passed locked restore, Release build with zero
  warnings/errors, 27 test methods across all categories, controlled-data checks and lock-file
  immutability. Preserved TRX evidence independently shows the concurrency test passing and the
  500-operation load test passing with 125 `201`, 375 `200`, zero `503`/timeouts/unexpected errors
  and p95 257.203 ms.
- PoC 2's post-freeze audit reran its local preset DoD: tool restore, solution restore, Release build
  with zero warnings/errors, 21/21 unit tests, 94.48% total line coverage and zero-error/zero-warning
  OpenAPI lint. No DoD control failed.

The DoD results are both PASS, but the gates are not identical. PoC 1's agreed design made real-host
integration, persistence failure, restart, concurrency, logging/security and local load tests part of
its gate. The `dotnet-sdd` preset used by PoC 2 mandated unit coverage and architectural/contract
controls while classifying integration and performance testing as later-SDLC work for this local PoC.

### Interpretation

**Reduced ceremony**: PoC 2 completed clarify, checklist, analyze remediation, implement and
converge from one experiment instruction. It needed fewer analyze and converge iterations and no
follow-up human turn. This is workflow automation, not a claim that nine projects are simpler than
two.

**Coverage loss or scope difference**: PoC 2 has strong unit coverage but does not reproduce PoC 1's
real HTTP/persistence/concurrency/load/logging test breadth. This is an explicit preset/SDLC boundary
and a material difference when comparing confidence, not an unexplained test omission.

**Architectural improvement**: PoC 2 makes domain, application, persistence, presentation and
composition ownership mechanically visible through projects and references. PoC 1 achieves the
behavior with fewer moving parts but relies on file-level boundaries inside one web project.

**Possible overarchitecture**: for only create/query, nine projects, 15 direct package/tool IDs,
Wolverine, EF Core, Serilog, OpenTelemetry and health checks impose noticeably more structural and
dependency cost. The structure is compliant with the preset and suitable as a corporate baseline,
but the experiment does not prove that every layer or package pays for itself at this feature size.

**Explicit decisions**: PoC 1 explicitly specified more HTTP, JSON, persistence, concurrency,
failure, logging, security and load behavior, which explains its 28 normative requirements and large
test harness. PoC 2 explicitly records the preset-derived modular architecture, mediator-only
Wolverine, repository abstraction, SQL Server, observability and local DoD.

**Inferred decisions**: PoC 2 still required Codex to choose SQL Server over MongoDB, interpret Azure
App Configuration as N/A, select Redocly for reproducible OpenAPI lint, establish exact opaque-ID and
quantity boundaries, isolate central package management inside the consumer, and split common versus
module-owned exception handling. These were documented and analyzed, but they were not fully
determined by the preset before execution.

### Attribution of the observed differences

| Source | Material effects |
|---|---|
| Functional input | PoC 1 has 10 more normative requirements, a third error-handling story and explicit host, durability, concurrency, logging/security and load protocols. PoC 2 deliberately keeps performance validation outside the local PoC. |
| Preset behavior | PoC 2 gains the nine-project modular structure, DDD/Clean dependency rules, Wolverine mediator, EF/repository baseline, observability stack, xUnit/Coverlet gate and later-SDLC exclusions. |
| Codex execution | PoC 2 autonomously closed checklist/analyze gaps and the package-boundary incident, selected allowed variable technologies/tooling and completed the loop without follow-up; the remaining inferences are listed above rather than attributed to the preset. |

The comparison therefore does not support a blanket conclusion that fewer artifacts, projects,
packages or LOC is better. PoC 1 optimizes for a narrowly consolidated implementation with unusually
deep local behavioral evidence. PoC 2 optimizes for repeatable corporate architectural governance and
automated SDD progression, at the cost of more structural ceremony and a narrower local test scope.
