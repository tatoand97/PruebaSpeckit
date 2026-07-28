---

description: "Executable task list for creation and query of orders"
---

# Tasks: Creación y consulta de órdenes

**Input**: Design documents from `/specs/001-create-query-orders/`

**Authoritative sources**: `.specify/memory/constitution.md`, `spec.md`, `plan.md`, `research.md`,
`data-model.md`, `contracts/openapi.yaml`, `quickstart.md` and the closed 40/40
`checklists/pre-tasks.md`.

**Tests**: Automated tests are mandatory for the relevant behavior defined by the Constitution and
plan. Tasks place tests after the corresponding implementation; TDD is not implied.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified as
an increment. `[P]` means only that tasks have no direct execution dependency and use different
files; it does not authorize subagents or multi-agent execution.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because the task uses different files and has no dependency on an
  incomplete task in the same parallel set
- **[Story]**: User story served by the task (`[US1]`, `[US2]` or `[US3]`)
- Every task names the exact file or files to create or modify

## Approved project paths

```text
Orders.slnx
global.json
Directory.Build.props
Directory.Packages.props
src/Orders.Api/
tests/Orders.Api.Tests/
scripts/verify.ps1
```

No other project, architectural layer or implementation path is authorized by this task list.

## Phase 1: Setup

**Purpose**: Establish only the solution, projects, dependencies and reproducible build
configuration approved by `plan.md`.

- [ ] T001 Pin the .NET SDK exactly to `10.0.302` in `global.json` (Plan §Technical Context; Constitution III/VII)
- [ ] T002 [P] Configure C# 14, nullable reference types, reproducible Release builds, Release warnings-as-errors and NuGet lock-file generation in `Directory.Build.props` (Plan §Technical Context/Automation; Constitution III/VII)
- [ ] T003 [P] Enable central package management and pin `Microsoft.Data.Sqlite` `10.0.10`, `MSTest` `4.3.2` and `Microsoft.AspNetCore.Mvc.Testing` `10.0.10` in `Directory.Packages.props` without adding other packages (Plan §Primary Dependencies)
- [ ] T004 Create `Orders.slnx` and `src/Orders.Api/Orders.Api.csproj` targeting `net10.0`, reference only `Microsoft.Data.Sqlite`, and add the web project to the solution (Plan §Project Structure)
- [ ] T005 Create `tests/Orders.Api.Tests/Orders.Api.Tests.csproj`, reference `src/Orders.Api/Orders.Api.csproj`, reference only the two approved test packages, and add the test project to `Orders.slnx` (Plan §Project Structure/Testing)
- [ ] T006 Restore the completed solution once to generate `src/Orders.Api/packages.lock.json` and `tests/Orders.Api.Tests/packages.lock.json`, then prove `dotnet restore .\Orders.slnx --locked-mode` succeeds without changing either lock file (Plan §Automation; Constitution VII)

**Checkpoint**: The approved two-project solution restores reproducibly and contains no
unapproved dependency or project.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement only the shared runtime, persistence, error and logging foundation required
before any user story.

**CRITICAL**: All tasks in this phase block every user story.

- [ ] T007 Define the confirmed `Order` and `OrderItem` records, the only `Pending` state and the exact identifier/quantity preservation invariants in `src/Orders.Api/OrderModels.cs` (Data Model §Order/OrderItem; FR-012/FR-017)
- [ ] T008 Define nullable transport inputs, closed success responses and the stable closed Problem Details catalog/factory—including logical `instance`, safe details, validation error keys and `traceId`—in `src/Orders.Api/OrderContracts.cs` (Plan §JSON policy/Problem Details; SR-004/SR-005)
- [ ] T009 [P] Configure native JSON console logging so only the `Orders.Api` application category is enabled and unsafe ASP.NET Core, SQLite and hosting-lifetime categories are suppressed in `src/Orders.Api/appsettings.json` (Plan §Logging contract; SR-007)
- [ ] T010 Implement configurable persistent SQLite startup and per-connection invariants in `src/Orders.Api/SqliteOrderStore.cs`: transactional schema v1 creation/validation, `user_version=1`, required tables/columns, `STRICT`, binary keys, checks, foreign key, `quick_check`, `foreign_key_check`, WAL, `synchronous=FULL`, `busy_timeout=500`, non-shared connections and parameterized SQL (Plan §Persistence; Data Model §Relational mapping; FR-014, SR-001)
- [ ] T011 Compose the shared host in `src/Orders.Api/Program.cs`: require `Orders:DatabasePath`, set Kestrel `MaxRequestBodySize=1_048_576`, configure camel-case/case-sensitive/strict JSON with duplicate-property rejection and unknown-member skipping, register Problem Details and the safe exception handler, register one writer `SemaphoreSlim(1,1)` with a 1-second wait budget, initialize SQLite at startup, expose `partial Program` for tests and emit only the approved structured event fields (Plan §Create flow/JSON/Logging; FR-021, SR-002/SR-007)
- [ ] T012 Verify schema creation and reuse, exact columns/constraints, `STRICT`, WAL, foreign keys, `synchronous=FULL`, `busy_timeout=500`, `quick_check`, empty `foreign_key_check`, one connection per operation and fail-fast startup for incompatible/corrupt/unwritable storage in `tests/Orders.Api.Tests/PersistenceTests.cs` (Plan §Persistence/Failure boundaries; FR-014, SC-007)

**Checkpoint**: The host starts only with valid persistent storage, enforces the HTTP/JSON
foundation and exposes no story endpoint yet.

---

## Phase 3: User Story 1 — Crear una orden válida (Priority: P1) 🎯 MVP

**Goal**: Accept one valid request, commit exactly one complete `Pending` order with a unique UUID
v4 and return the closed `201` response and relative `Location`.

**Independent Test**: With a temporary SQLite file and synthetic identifiers, POST a valid order
and verify one complete committed aggregate, `201 application/json`, canonical unique UUID v4,
`Pending`, exact `Location`, all accepted values and a second distinct ID for an identical request.

### Implementation for User Story 1

- [ ] T013 [P] [US1] Implement one-pass deterministic semantic validation for customer, item collection, null items, product identifiers, positive `Int64?` quantities and ordinal duplicate detection with all detectable errors accumulated and no input echo in `src/Orders.Api/OrderValidator.cs` (FR-003–FR-008, SR-001)
- [ ] T014 [P] [US1] Implement atomic creation in `src/Orders.Api/SqliteOrderStore.cs`: acquire the supplied writer gate within 1 second, use a dedicated connection and `BEGIN IMMEDIATE`, insert `orders` plus every `order_items` row in one transaction, commit before returning, use canonical UUID v4 `D`, retry primary-key collisions with exactly three total attempts and retain test-replaceable UUID generation as required by the plan (FR-009–FR-014/FR-020, SR-003)
- [ ] T015 [US1] Map the valid `POST /orders` path in `src/Orders.Api/Program.cs`: require supported JSON media type before reading, deserialize the nullable contract, validate before opening storage, invoke atomic creation, return exactly `orderId` and `status` as `201 application/json` with relative `Location`, and emit the safe `create_order` completion event only after the commit (FR-001–FR-013, SR-007)

### Automated verification for User Story 1

- [ ] T016 [P] [US1] Verify valid single/multi-item creation, unknown but usable IDs, `Int64.MaxValue`, closed `201` schema/media type, canonical UUID v4, `Pending`, exact relative `Location` and a new ID for an identical repeated request in `tests/Orders.Api.Tests/ApiContractTests.cs` (FR-001–FR-005/FR-009–FR-013, SC-001)
- [ ] T017 [P] [US1] Verify exactly one `orders` row and one `order_items` row per accepted item, binary/exact preservation of identifiers and quantities, no extra data and committed visibility in `tests/Orders.Api.Tests/PersistenceTests.cs` (FR-007/FR-009/FR-012/FR-017, SC-001)
- [ ] T018 [P] [US1] Verify commit precedes construction of `201`, independent requests get unique IDs, UUID collisions on attempts 1 and 2 rollback then retry, and collision on attempt 3 returns no confirmed order in `tests/Orders.Api.Tests/AtomicityTests.cs` (FR-010/FR-020, SR-003, SC-001)

**Checkpoint**: US1 is demonstrable through `POST /orders` without requiring US2 or US3 tests.

---

## Phase 4: User Story 2 — Consultar una orden existente (Priority: P2)

**Goal**: Retrieve exactly one complete committed order using the opaque identifier returned by
creation.

**Independent Test**: Seed a complete committed aggregate directly in a temporary schema, without
calling the US1 endpoint, then GET its exact identifier and verify only that order and all of its
stored values are returned as the closed `200` response.

### Implementation for User Story 2

- [ ] T019 [US2] Implement exact binary order lookup in `src/Orders.Api/SqliteOrderStore.cs` using one dedicated reader connection, no writer gate, no enumeration and parameterized SQL that materializes only a complete committed aggregate (FR-015–FR-018, SR-001/SR-004)
- [ ] T020 [US2] Map the successful `GET /orders/{orderId}` path in `src/Orders.Api/Program.cs`, preserve the route value without trim/case-fold/Unicode normalization, call exact lookup, return the closed `200 application/json` order response and emit a safe `get_order` completion event (FR-015–FR-017, SR-004/SR-007)

### Automated verification for User Story 2

- [ ] T021 [P] [US2] Verify `GET /orders/{orderId}` returns the exact seeded order with its ID, customer, every product/quantity and `Pending`, uses `application/json`, has no additional fields and never returns another order in `tests/Orders.Api.Tests/ApiContractTests.cs` (FR-015–FR-017, SR-004, SC-003)
- [ ] T022 [P] [US2] Verify reader lookup uses binary equality, preserves case/whitespace/distinct Unicode values, does not enumerate, uses no writer gate and returns a complete aggregate from committed SQLite state in `tests/Orders.Api.Tests/PersistenceTests.cs` (FR-015–FR-018, SC-003)

**Checkpoint**: US2 can be verified with a seeded database independently of the US1 HTTP creation
flow.

---

## Phase 5: User Story 3 — Recibir errores claros sin alterar las órdenes (Priority: P3)

**Goal**: Return the approved safe error classifications for invalid creation, missing/invalid or
unknown query identifiers and persistence failures, while never exposing or confirming a partial
order.

**Independent Test**: Start from known database counts, exercise every invalid-body and semantic
case plus missing, whitespace and unknown order IDs and deterministic storage failures, then verify
the exact Problem Details class and unchanged/complete persisted state.

### Implementation for User Story 3

- [ ] T023 [US3] Complete the invalid `POST /orders` branches in `src/Orders.Api/Program.cs` and `src/Orders.Api/OrderContracts.cs`: `415` takes precedence for absent/unsupported Content-Type, supported media-type parameters are accepted, absent/empty/null/malformed/type/range/fraction/exponent/repeated-property bodies become `400 invalid-body`, semantic failures become accumulated `400 validation`, unknown properties are ignored and no invalid request reaches a transaction (FR-003–FR-008, SR-001/SR-005)
- [ ] T024 [US3] Complete deterministic persistence failure classification and rollback in `src/Orders.Api/SqliteOrderStore.cs` and `src/Orders.Api/Program.cs`: proven pre-commit gate timeout/busy/temporary-storage failures become `503` without commit or `Retry-After`; permanent/unexpected/constraint/third-collision and uncertain commit outcomes become generic `500`; cancellation before acquisition starts no transaction; post-commit response failure never rolls back (FR-007/FR-008/FR-010, SR-005)
- [ ] T025 [US3] Map `GET /orders` to stable `400 missing-order-id` with no database enumeration, and complete `GET /orders/{orderId}` handling for whitespace `400`, usable unknown values `404`, temporary pre-read `503` and unexpected `500` in `src/Orders.Api/Program.cs` and `src/Orders.Api/OrderContracts.cs`, always using logical route templates and safe `reject_missing_order_id`/`get_order` events (FR-018/FR-019, SR-001/SR-005/SR-007)

### Automated verification for User Story 3

- [ ] T026 [P] [US3] Cover every semantic rule and accumulation combination in `tests/Orders.Api.Tests/ValidationTests.cs`: absent/null/whitespace customer and product IDs, null/empty items, null elements, absent/null/zero/negative quantities, distinct ordinal IDs, multiple duplicate groups and second/third duplicate occurrences keyed by index without echoing the product ID (FR-003–FR-008, SC-002)
- [ ] T027 [P] [US3] Cover HTTP binding and error behavior in `tests/Orders.Api.Tests/ApiContractTests.cs`: absent/empty/null/truncated/malformed bodies, wrong types, strings as numbers, overflow/fraction/exponent, repeated/case-mismatched/unknown properties, `415` precedence, duplicated products, missing/whitespace/nonexistent query IDs, safe closed `400/404/415/500/503` Problem Details, exact `traceId`, no stack/data leakage and no `Retry-After` (FR-005/FR-006/FR-008/FR-018/FR-019, SR-005, SC-002/SC-004)
- [ ] T028 [P] [US3] Inject every approved failure boundary and verify atomicity in `tests/Orders.Api.Tests/AtomicityTests.cs`: validation opens no transaction; gate timeout and proven pre-commit open/BEGIN failures return `503`; order/item/constraint/collision failures fully rollback; no `503` confirms data; third collision gives safe `500`; ambiguous commit/post-commit disconnect is never `503` and a completed commit remains complete (FR-007/FR-008/FR-010/FR-021, SC-002)

**Checkpoint**: All three stories are functional, and every controlled application error preserves
the approved storage and disclosure guarantees.

---

## Phase 6: Polish & Cross-Cutting Verification

**Purpose**: Prove behavior spanning multiple stories, performance, security, reproducibility and
the complete OpenAPI contract without adding features or infrastructure.

- [ ] T029 [P] Verify an order survives application restart with the same SQLite path, including process termination after commit and WAL recovery, and distinguish a new/lost database as outside the guarantee in `tests/Orders.Api.Tests/RestartTests.cs` (FR-014, SC-003)
- [ ] T030 [P] Verify writer/writer and reader/writer behavior in `tests/Orders.Api.Tests/ConcurrencyTests.cs`: 25 simultaneous creates have unique IDs and no partials; pre-commit read may be `404`; post-commit read is complete; readers bypass the gate; 1-second writer wait and over-500-ms SQLite lock return pre-commit `503`; no general retry/FIFO assumption; external SQLite access still enforces keys/atomicity (FR-014/FR-018/FR-020, SC-001/SC-003/SC-006)
- [ ] T031 [P] Add runtime contract assertions derived from `specs/001-create-query-orders/contracts/openapi.yaml` to `tests/Orders.Api.Tests/ApiContractTests.cs` for exactly two paths/three operations, every documented status/header/media type, closed success/error schemas, stable Problem Details catalog, `Location`, no listing and the explicit host-boundary exclusions, without adding an OpenAPI test package (FR-001–FR-021, SR-004/SR-005)
- [ ] T032 Start real Kestrel on loopback and verify the 1,048,576-byte host boundary in `tests/Orders.Api.Tests/ApiContractTests.cs`: a valid body within the limit reaches the app; oversized `Content-Length` and chunked bodies return `413`; absent/inconsistent length cannot bypass the limit; input is never truncated; database counts stay unchanged; no Problem Details/media-type assumption is made for `413` (FR-021, SC-002)
- [ ] T033 [P] Capture native JSON console output and verify the closed fields, value vocabularies, levels, monotonic non-negative duration and exact Problem Details `traceId` correlation for startup/create/get/reject and all failure categories in `tests/Orders.Api.Tests/LoggingTests.cs`; inject canaries for bodies, IDs, raw route/query, headers, connection string, DB path, SQL/parameters and exception/stack details and prove neither errors nor logs expose them or any suppressed provider event (SR-005–SR-007, SC-007)
- [ ] T034 [P] Implement the in-project SC-006 harness in `tests/Orders.Api.Tests/LoadTests.cs`: separate disposable warm-up with 25 users and two unmeasured cycles; fresh measured DB with 25 seeds; 25 users synchronized before each of five cycles; exact POST+3 GET cycle for 125/375 and 500 measured operations; send-through-full-body monotonic timing; 5-second harness fail-safe; nearest-rank p95; separate `201`, `200`, `503`, timeout and unexpected counts; fail unless p95 is strictly below 2,000 ms with zero `503`, timeouts, unexpected errors and duplicate/incomplete orders (SC-006)
- [ ] T035 [P] Create `scripts/verify.ps1` to run locked restore, Release build with `--no-restore -warnaserror`, all applicable Release tests with `--no-build` and every automatic validation documented in `specs/001-create-query-orders/quickstart.md`, stopping immediately and returning a nonzero exit code for any failure (Constitution III/IV/VII; Plan §Automation)
- [ ] T036 Execute the SC-005 usability procedure and SC-007 synthetic/preclassified-data gate exactly as documented in `specs/001-create-query-orders/quickstart.md`, recording participant timing/assistance and data-classification evidence before accepting results; do not substitute automated agents for human participants (SC-005/SC-007)
- [ ] T037 Run `scripts/verify.ps1`, re-run the applicable manual HTTP flows from `specs/001-create-query-orders/quickstart.md`, confirm zero relevant compiler/analyzer warnings, unchanged lock files, no prohibited data in SQLite/evidence/logs and successful independent checkpoints for US1, US2 and US3 (FR-001–FR-021, SR-001–SR-007, SC-001–SC-007)

**Checkpoint**: Automated gates are reproducible, manual acceptance evidence is explicit and the
implemented feature matches the entire approved contract.

---

## Dependencies & Execution Order

### Dependency graph

```text
Phase 1 Setup (T001-T006)
          |
          v
Phase 2 Foundational (T007-T012)
          |
          +--------------------+
          |                    |
          v                    v
US1 Create (T013-T018)   US2 Query (T019-T022)
          |                    |
          +---------+----------+
                    |
                    v
          US3 Errors (T023-T028)
                    |
                    v
Cross-Cutting (T029-T037)
```

US1 and US2 have no direct implementation dependency after Foundational: US2 tests seed their own
committed aggregate. US3 deliberately follows both because it completes the error behavior of the
create and query operations. Cross-cutting restart requires US1+US2; the full concurrency,
contract, logging and load gates require all three stories.

### Task-level blocking dependencies

- `T004` depends on `T001`–`T003`; `T005` depends on `T004`; `T006` depends on `T004`–`T005`.
- `T008` depends on `T007`; `T010` depends on the buildable Setup and shared model; `T011` depends
  on `T008`–`T010`; `T012` depends on `T010`–`T011`.
- `T013` and `T014` can start after `T012`; `T015` depends on both; `T016`–`T018` depend on `T015`.
- `T019` can start after `T012`; `T020` depends on `T019`; `T021`–`T022` depend on `T020`.
- `T023` depends on US1; `T024`–`T025` depend on the completed US1/US2 operations and are
  sequential because they overlap `Program.cs`; `T026`–`T028` start after `T025`.
- `T029` depends on US1+US2. `T030`–`T034` depend on all stories. `T035` can be authored alongside
  those different-file verification tasks. `T036` requires a working complete feature and human
  participants. `T037` is the final gate and depends on `T029`–`T036`.

### Blocking tasks

- Setup blockers: `T001`, `T004`, `T005`, `T006`.
- Foundation blockers: `T007`–`T012`; no story work begins before `T012`.
- Story integration blockers: `T015` for valid creation, `T020` for successful query and
  `T023`–`T025` for the complete error matrix.
- Release blocker: `T037`.

## Real Parallel Opportunities

- Setup: `T002` and `T003` use different root configuration files.
- Foundational: `T009` can proceed independently of model/contract work.
- US1 after Foundation: `T013` and `T014`; after `T015`, `T016`, `T017` and `T018`.
- US2 after `T020`: `T021` and `T022`.
- US3 after `T025`: `T026`, `T027` and `T028`.
- Cross-cutting after the stories: `T029`, `T030`, `T031`, `T033`, `T034` and `T035`; `T032`
  remains after `T031` because both modify `ApiContractTests.cs`.
- At story level, US1 and US2 may progress independently after Foundational. Recommended execution
  remains sequential by priority unless parallel work has been separately authorized.

### Parallel example: User Story 1

```text
After T012:
  T013 -> src/Orders.Api/OrderValidator.cs
  T014 -> src/Orders.Api/SqliteOrderStore.cs

After T015:
  T016 -> tests/Orders.Api.Tests/ApiContractTests.cs
  T017 -> tests/Orders.Api.Tests/PersistenceTests.cs
  T018 -> tests/Orders.Api.Tests/AtomicityTests.cs
```

### Parallel example: User Story 2

```text
After T020:
  T021 -> tests/Orders.Api.Tests/ApiContractTests.cs
  T022 -> tests/Orders.Api.Tests/PersistenceTests.cs
```

### Parallel example: User Story 3

```text
After T025:
  T026 -> tests/Orders.Api.Tests/ValidationTests.cs
  T027 -> tests/Orders.Api.Tests/ApiContractTests.cs
  T028 -> tests/Orders.Api.Tests/AtomicityTests.cs
```

## Implementation Strategy

### Recommended MVP: User Story 1

1. Complete Setup (`T001`–`T006`).
2. Complete Foundational (`T007`–`T012`).
3. Complete US1 (`T013`–`T018`).
4. Stop and run the US1 independent test.

US1 is the recommended MVP because the specification assigns it P1 and identifies valid creation
as the origin of feature value; the recommendation is based on the story's independent business
outcome, not on its task count. US2 is the next increment and completes the create/query cycle.

### Incremental delivery

1. Setup + Foundational establish a reproducible and safe platform but deliver no business
   capability.
2. US1 delivers valid creation.
3. US2 adds exact retrieval without changing US1.
4. US3 closes invalid input, not-found and failure behavior for both operations.
5. Cross-cutting tasks prove restart, concurrency, contract, privacy, load and reproducibility.

## Requirement Coverage

| Requirement | Tasks providing implementation or evidence |
|---|---|
| FR-001–FR-002 | T008, T015–T017, T031, T037 |
| FR-003–FR-008 | T013, T015, T023, T026–T028, T031–T032, T037 |
| FR-009 | T014–T017, T031, T037 |
| FR-010 | T014, T018, T024, T028, T030, T031, T037 |
| FR-011–FR-013 | T007–T008, T014–T018, T031, T037 |
| FR-014 | T010, T012, T014, T017, T029–T030, T037 |
| FR-015–FR-017 | T007, T019–T022, T029–T031, T037 |
| FR-018–FR-019 | T019–T025, T027, T030–T031, T037 |
| FR-020 | T014, T018, T030–T031, T034, T037 |
| FR-021 | T011, T023, T028, T031–T032, T034, T037 |
| SR-001 | T010, T013, T019, T023, T025–T027, T037 |
| SR-002 | T011, T031, T033, T036–T037 |
| SR-003 | T014, T016, T018, T030, T037 |
| SR-004 | T008, T019–T022, T031, T037 |
| SR-005 | T008, T023–T025, T027, T031, T033, T037 |
| SR-006 | T008, T023, T033, T036–T037 |
| SR-007 | T009, T011, T015, T020, T023–T025, T027, T033, T037 |
| SC-001 | T016–T018, T030, T034, T037 |
| SC-002 | T023, T026–T028, T032, T037 |
| SC-003 | T021–T022, T029–T031, T037 |
| SC-004 | T025, T027, T031, T037 |
| SC-005 | T036–T037 |
| SC-006 | T030, T034–T035, T037 |
| SC-007 | T012, T033, T036–T037 |

Setup tasks `T001`–`T006` and automation task `T035` trace to the approved Technical Context,
Project Structure and Constitution III/VII. Foundation tasks `T007`–`T012` trace to the shared
Design, Data Model, security and operability decisions. No task lacks a source in the approved
artifacts, and the closed checklist items are used only as evidence that those decisions are
ready—not as new functionality.

## Task Inventory Validation

- **Total tasks**: 37
- **Setup**: 6 (`T001`–`T006`)
- **Foundational**: 6 (`T007`–`T012`)
- **US1**: 6 (`T013`–`T018`)
- **US2**: 4 (`T019`–`T022`)
- **US3**: 6 (`T023`–`T028`)
- **Polish/Cross-Cutting**: 9 (`T029`–`T037`)
- **Marked `[P]`**: 19
- **Requirements without a task**: none
- **Tasks without clear traceability**: none
- **New technical or functional decisions introduced**: none
- **Format**: all 37 tasks use `- [ ] T### [P?] [US?] Description with exact path`; story labels
  appear only in user-story phases and are present on every user-story task

