---
description: "Lista de tareas para crear y consultar órdenes"
---

# Tasks: Crear y consultar órdenes

**Input**: Design documents from `/specs/001-create-query-orders/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/openapi.yaml` and `quickstart.md`

**Testing**: Solo unit tests xUnit significativos. Coverlet mide Domain y Application con umbral
de 80%. TDD no es obligatorio y los tests siguen a la implementación de cada comportamiento.

**Organization**: El trabajo se agrupa por las dos user stories y conserva el flujo de capas del
preset. Una task se marca `[X]` solo después de obtener evidencia.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Puede ejecutarse en paralelo después de sus dependencias porque usa archivos distintos.
- **[Story]**: User story propietaria.
- Todas las rutas son relativas a la raíz de `poc2-tuya-dotnet-sdd`.

## Phase 1: Setup

**Purpose**: Materializar la solución .NET 10 y las referencias permitidas por el plan.

- [X] T001 Crear `global.json`, `Directory.Build.props`, `Directory.Packages.props`, `.gitignore`, `.config/dotnet-tools.json`, `Orders.slnx` y los proyectos `Orders/Api/Orders.Server/Orders.Server.csproj`, `Orders/Common/Common.Domain/Common.Domain.csproj`, `Orders/Common/Common.Infrastructure/Common.Infrastructure.csproj`, `Orders/Common/Common.Presentation/Common.Presentation.csproj`, `Orders/Modules/Orders/Domain/Orders.Domain.csproj`, `Orders/Modules/Orders/Application/Orders.Application.csproj`, `Orders/Modules/Orders/Infrastructure/Orders.Infrastructure.csproj`, `Orders/Modules/Orders/Presentation/Orders.Presentation.csproj` y `Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj`
- [X] T002 Configurar únicamente las referencias autorizadas entre todos los `.csproj` de `Orders/` y agregar los proyectos a `Orders.slnx` según `plan.md` §Dependency Direction Check
- [X] T003 [P] Agregar las dependencias runtime/tooling y versiones aprobadas a `Directory.Packages.props` y los `.csproj` de `Orders/Api/`, `Orders/Common/` y `Orders/Modules/Orders/`, incluyendo EF Design con `PrivateAssets=all`, y fijar dotnet-ef 10.0.10 en `.config/dotnet-tools.json`
- [X] T004 [P] Configurar xUnit 2.9.3, Microsoft.NET.Test.Sdk 18.8.1, xunit.runner.visualstudio 3.1.5 y Coverlet MSBuild 10.0.1 en `Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj`

**Checkpoint**: El esqueleto compila por diseño, usa .NET 10, nullable/implicit usings y no contiene
módulos o abstracciones fuera del plan.

---

## Phase 2: Foundational

**Purpose**: Preparar composición, errores y telemetría que bloquean ambas stories.

- [X] T005 Implementar el fallback `IExceptionHandler` para 500, `AddProblemDetails()` y respuesta segura con `traceId` en `Orders/Common/Common.Presentation/GlobalExceptionHandler.cs` y `Orders/Common/Common.Presentation/ServiceCollectionExtensions.cs`
- [X] T006 [P] Configurar Serilog y OpenTelemetry ASP.NET Core/HttpClient sin exporters externos ni datos sensibles en `Orders/Common/Common.Presentation/ObservabilityExtensions.cs`
- [X] T007 Configurar `Orders.Server` como composition root con Wolverine `DurabilityMode.MediatorOnly`, Problem Details, Serilog, OpenTelemetry y `/health` en `Orders/Api/Orders.Server/Program.cs` y `Orders/Api/Orders.Server/appsettings.json`

**Checkpoint**: La aplicación tiene composition root y políticas compartidas sin lógica de negocio,
mensajería distribuida ni secretos hardcoded.

---

## Phase 3: User Story 1 - Crear una orden válida (Priority: P1) 🎯 MVP

**Goal**: Crear atómicamente una orden válida, devolver un identificador nuevo y rechazar la
solicitud completa cuando cualquier dato sea inválido.

**Independent Test**: Invocar el handler con un repositorio unitario y comprobar creación, nuevo ID,
datos conservados y ausencia de escritura ante cada rechazo.

### Implementation for User Story 1

- [X] T008 [US1] Implementar el agregado `Order`, `OrderItem` y la excepción de producto duplicado con igualdad ordinal sensible a mayúsculas en `Orders/Modules/Orders/Domain/Order.cs`, `Orders/Modules/Orders/Domain/OrderItem.cs` y `Orders/Modules/Orders/Domain/DuplicateProductException.cs`
- [X] T009 [US1] Definir `CreateOrderCommand`, items de entrada, `OrderResult`, items de resultado e `IOrderRepository` específico en `Orders/Modules/Orders/Application/CreateOrder/CreateOrderCommand.cs`, `Orders/Modules/Orders/Application/OrderResult.cs` y `Orders/Modules/Orders/Application/IOrderRepository.cs`
- [X] T010 [US1] Implementar FluentValidation para cliente, lista, identificadores y cantidades 1..2147483647 en `Orders/Modules/Orders/Application/CreateOrder/CreateOrderValidator.cs`
- [X] T011 [US1] Implementar `CreateOrderHandler` con validación previa, `TimeProvider`, nuevo GUID por solicitud y una única escritura del agregado en `Orders/Modules/Orders/Application/CreateOrder/CreateOrderHandler.cs`
- [X] T012 [P] [US1] Implementar `OrdersDbContext` y el mapping EF Core SQL Server con `LineNumber` shadow key en `Orders/Modules/Orders/Infrastructure/Persistence/OrdersDbContext.cs` y `Orders/Modules/Orders/Infrastructure/Persistence/OrderConfiguration.cs`
- [X] T013 [US1] Implementar `OrderRepository.AddAsync`/`GetByIdAsync` y el registro scoped de EF/repository/HealthCheck en `Orders/Modules/Orders/Infrastructure/Persistence/OrderRepository.cs` y `Orders/Modules/Orders/Infrastructure/ServiceCollectionExtensions.cs`
- [X] T014 [US1] Ejecutar `dotnet tool restore` y generar la migración inicial con `dotnet tool run dotnet-ef migrations add InitialCreate --project Orders/Modules/Orders/Infrastructure/Orders.Infrastructure.csproj --startup-project Orders/Api/Orders.Server/Orders.Server.csproj --output-dir Persistence/Migrations`
- [X] T015 [P] [US1] Definir contratos HTTP de creación y respuesta sin lógica duplicada en `Orders/Modules/Orders/Presentation/OrdersContracts.cs`
- [X] T016 [US1] Implementar `POST /orders` como Minimal API delgada que delega con `IMessageBus.InvokeAsync`, devuelve 201/Location y mapea validación/duplicados mediante `OrdersExceptionHandler` en `Orders/Modules/Orders/Presentation/OrdersEndpoints.cs`, `Orders/Modules/Orders/Presentation/OrdersExceptionHandler.cs` y `Orders/Modules/Orders/Presentation/ServiceCollectionExtensions.cs`
- [X] T017 [US1] Crear unit tests xUnit del agregado para creación válida, lista vacía, identificadores opacos, cantidades inválidas, duplicados identificados e IDs distintos en `Orders/Modules/Orders/Tests/Orders.Test/Domain/OrderTests.cs`
- [X] T018 [US1] Crear unit tests xUnit del validator y handler para escritura única y cero escritura ante rechazo en `Orders/Modules/Orders/Tests/Orders.Test/Application/CreateOrderTests.cs`
- [X] T019 [US1] Comparar y ajustar la operación `POST /orders` 201/400/500 y sus schemas en `specs/001-create-query-orders/contracts/openapi.yaml` contra `OrdersEndpoints.cs`

**Checkpoint**: US1 crea una orden completa, rechaza toda entrada inválida y sus unit tests pasan.

---

## Phase 4: User Story 2 - Consultar una orden por identificador (Priority: P2)

**Goal**: Recuperar por identificador exacto los datos conservados o devolver resultados
diferenciados para identificador inválido y orden inexistente.

**Independent Test**: Invocar la query con un repositorio unitario que contiene una orden conocida y
comprobar respuesta; repetir con GUID inválido y GUID inexistente.

### Implementation for User Story 2

- [X] T020 [US2] Implementar `GetOrderQuery`, FluentValidation textual de GUID y `GetOrderHandler` con resultado 404 para ausencia en `Orders/Modules/Orders/Application/GetOrder/GetOrderQuery.cs`, `Orders/Modules/Orders/Application/GetOrder/GetOrderValidator.cs`, `Orders/Modules/Orders/Application/GetOrder/GetOrderHandler.cs` y `Orders/Modules/Orders/Application/OrderNotFoundException.cs`, extendiendo `Orders/Modules/Orders/Presentation/OrdersExceptionHandler.cs` con el mapeo 404
- [X] T021 [US2] Implementar `GET /orders/{orderId}` mediante Wolverine en `Orders/Modules/Orders/Presentation/OrdersEndpoints.cs` con respuestas 200/400/404/500 Problem Details
- [X] T022 [US2] Crear unit tests xUnit para query válida, formato inválido, orden existente e inexistente en `Orders/Modules/Orders/Tests/Orders.Test/Application/GetOrderTests.cs`
- [X] T023 [US2] Comparar y ajustar la operación `GET /orders/{orderId}` 200/400/404/500 y sus schemas en `specs/001-create-query-orders/contracts/openapi.yaml` contra `OrdersEndpoints.cs`

**Checkpoint**: US1 y US2 funcionan con handlers independientes y contratos HTTP consistentes.

---

## Phase 5: Local Verification and Cross-Cutting Completion

**Purpose**: Producir evidencia del Definition of Done local antes de convergencia.

- [X] T024 Completar la composición del módulo, registro de `TimeProvider`, DbContext HealthCheck y mapping de endpoints en `Orders/Modules/Orders/Presentation/ServiceCollectionExtensions.cs` y `Orders/Api/Orders.Server/Program.cs`
- [X] T025 Ejecutar `dotnet restore Orders.slnx` desde la raíz y registrar resultado exitoso
- [X] T026 Ejecutar `dotnet build Orders.slnx -c Release --no-restore` y registrar cero errores y cero warnings .NET
- [X] T027 Ejecutar `dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj -c Release --no-build` y registrar todos los unit tests aprobados
- [X] T028 Medir Domain/Application con Coverlet usando el comando reproducible de `specs/001-create-query-orders/quickstart.md` y registrar al menos 80% line coverage en `artifacts/coverage/coverage.json`
- [X] T029 Auditar los `ProjectReference` de todos los `.csproj` y el flujo Minimal API -> Wolverine -> Application -> Domain -> repository contra `specs/001-create-query-orders/plan.md`
- [X] T030 Ejecutar `npx --yes @redocly/cli@2.41.1 lint specs/001-create-query-orders/contracts/openapi.yaml` y comparar el contrato con métodos, rutas, schemas y errores implementados
- [X] T031 Auditar Problem Details, ausencia de secretos y datos sensibles, `MediatorOnly`, Serilog, OpenTelemetry, HealthChecks y Azure App Configuration N/A en `Orders/` y `specs/001-create-query-orders/plan.md`
- [X] T032 Verificar que no existan artefactos de Sonar, Veracode, SAST, DAST, integration/performance testing, CI/CD, deployment, collectors, dashboards, recursos Azure o mensajería distribuida dentro de `poc2-tuya-dotnet-sdd`
- [X] T033 Registrar comandos, resultados, coverage, arquitectura, OpenAPI y controles transversales en `specs/001-create-query-orders/implementation-evidence.md`

## Dependencies and Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 -> T002; T003 y T004 pueden ejecutarse en paralelo después de T001.
- **Foundational (Phase 2)**: depende de Setup; T005 y T006 usan archivos distintos y T007 los
  compone.
- **US1 (Phase 3)**: depende de Foundational. T008 precede T009–T018; T012 y T015 pueden avanzar en
  archivos distintos cuando existan sus tipos requeridos. T019 ocurre después de T016.
- **US2 (Phase 4)**: depende de la persistencia/resultados creados para US1, pero su query y tests no
  dependen del endpoint POST. T023 ocurre después de T021.
- **Verification (Phase 5)**: T024 precede restore/build/test; T025 -> T026 -> T027 -> T028. Las
  auditorías T029–T032 ocurren sobre el estado construido y T033 consolida su evidencia.

### Parallel Opportunities

- T003 y T004 modifican proyectos productivos y de tests distintos.
- T005 y T006 crean archivos compartidos distintos antes de su composición en T007.
- T012 y T015 crean Infrastructure y contratos Presentation distintos después de T008/T009.
- Las marcas `[P]` describen independencia de archivos; no autorizan orquestación multiagente.

## Requirement Coverage

| Requirement / Acceptance | Task IDs | Evidence |
|---|---|---|
| FR-001, FR-004, FR-005, US1/AC1, US1/AC3 | T009–T011, T017–T018 | Command/handler and unit tests |
| FR-002, FR-003, FR-013 | T008, T010, T017–T018 | Domain/validator behavior and errors |
| FR-006, US1/AC2, US1/AC4 | T011, T013, T018–T019 | Zero-write tests, repository transaction, OpenAPI 400 |
| FR-007, US1/AC5 | T011, T017–T018 | Distinct-ID tests |
| FR-008 | T008, T012–T014 | Aggregate, mapping and migration |
| FR-009, FR-010, FR-011, US2/AC1 | T020–T023 | Query, endpoint, tests and OpenAPI 200 |
| FR-012, US2/AC2 | T020–T023 | Not-found exception/test and OpenAPI 404 |
| FR-014 | T008, T017–T019 | Duplicate domain rule/test and OpenAPI 400 |
| FR-015 | T001–T024, T032 | Single-module tree and out-of-scope audit |
| NFR-001 | T007, T012–T013, T024 | Stateless request composition and scoped DbContext |
| NFR-002 | T005–T007, T019, T023, T031 | Safe Problem Details/logs/traces |
| NFR-003 | T032 | Explicit absence of local performance suite |
| SC-001–SC-005 | T017–T023, T025–T030 | Unit behavior, build/test/coverage and contract evidence |
| Constitution II–VII | T001–T007, T024–T033 | Project references, stack and full local DoD evidence |

All 15 Functional Requirements, all 3 Non-Functional Requirements, both user stories and all 5
Success Criteria have at least one implementation or evidence task.

## Scope Guard

This `tasks.md` does not authorize Sonar, Veracode, SAST, DAST, performance testing, integration
testing, CI/CD, deployment, external infrastructure, distributed messaging or unjustified
abstractions. `speckit.converge` runs after implementation and is not a circular task.

## Completion Evidence

At completion, `implementation-evidence.md` records tasks, restore/build/test/coverage results,
coverage scope and percentage, architecture/OpenAPI audits, applicable cross-cutting standards and
the handoff to `speckit-converge`.
