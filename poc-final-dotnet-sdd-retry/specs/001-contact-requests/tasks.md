---
description: "Lista de tareas para registrar y consultar solicitudes de contacto"
---

# Tasks: Registro y consulta de solicitudes de contacto

**Input**: Design documents from `/specs/001-contact-requests/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`,
`contracts/openapi.yaml` y `quickstart.md`.

**Testing**: Solo unit tests significativos con xUnit y Coverlet sobre Domain, Application y las
políticas HTTP con comportamiento verificable de Presentation.
No se generan integration, contract ni performance tests. TDD no es obligatorio.

**Organization**: El trabajo se agrupa por user story y conserva el módulo DDD
`ContactRequests` con sus capas Domain, Application, Infrastructure y Presentation.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Puede ejecutarse en paralelo después de satisfacer sus dependencias explícitas porque
  usa archivos distintos.
- **[Story]**: Identifica la user story propietaria (`[US1]`, `[US2]` o `[US3]`).
- Cada tarea incluye rutas o comandos exactos y solo se marca `[X]` cuando exista evidencia.

## Phase 1: Setup

**Purpose**: Crear la solución y los proyectos mínimos definidos por el plan.

- [X] T001 Crear `ContactRequests.slnx` y los proyectos `src/Api/ContactRequests.Server/ContactRequests.Server.csproj`, `src/Common/Common.Infrastructure/Common.Infrastructure.csproj`, `src/Common/Common.Presentation/Common.Presentation.csproj`, `src/Modules/ContactRequests/Domain/ContactRequests.Domain.csproj`, `src/Modules/ContactRequests/Application/ContactRequests.Application.csproj`, `src/Modules/ContactRequests/Infrastructure/ContactRequests.Infrastructure.csproj`, `src/Modules/ContactRequests/Presentation/ContactRequests.Presentation.csproj` y `src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj`
- [X] T002 [P] Configurar .NET 10, nullable, implicit usings y cero warnings esperados en `Directory.Build.props`, preservando el SDK `10.0.302` fijado en `global.json`
- [X] T003 Configurar las versiones y referencias de ASP.NET Core, Wolverine, FluentValidation, EF Core SQL Server, Serilog, OpenTelemetry, HealthChecks, Azure App Configuration, Azure Identity, xUnit y Coverlet en `Directory.Packages.props` y en los archivos `.csproj` creados por T001
- [X] T004 Configurar en `ContactRequests.slnx` y los archivos `.csproj` las referencias permitidas por `specs/001-contact-requests/plan.md`, incluyendo el acceso de `src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj` solo a Domain, Application y Presentation del mismo módulo

**Checkpoint**: La solución contiene únicamente los proyectos necesarios y refleja las direcciones
de dependencia aprobadas.

---

## Phase 2: Foundational

**Purpose**: Implementar los prerrequisitos compartidos que bloquean las tres historias.

- [X] T005 Definir la firma mínima de `ContactRequest`, el repositorio específico con `AddAsync`/`GetByIdAsync` y `ContactRequestIdentifierCollisionException` independiente de EF en `src/Modules/ContactRequests/Domain/ContactRequest.cs` y `src/Modules/ContactRequests/Application/Persistence/`
- [X] T006 [P] Implementar la integración condicional de Azure App Configuration mediante una URI externa y `DefaultAzureCredential`, sin refresh ni secretos hardcoded, en `src/Common/Common.Infrastructure/Configuration/AzureAppConfigurationExtensions.cs`
- [X] T007 [P] Configurar Serilog y OpenTelemetry para ASP.NET Core y EF Core sin capturar payloads ni datos de contacto en `src/Common/Common.Infrastructure/Observability/ObservabilityExtensions.cs`
- [X] T008 [P] Implementar el fallback inesperado `IExceptionHandler` con Problem Details `500` y `traceId` seguro en `src/Common/Common.Presentation/Errors/UnexpectedExceptionHandler.cs` y registrarlo en `src/Common/Common.Presentation/DependencyInjection.cs`
- [X] T009 Configurar `AddProblemDetails()`, los exception handlers, Wolverine con `DurabilityMode.MediatorOnly`, observabilidad, Azure App Configuration condicional y el módulo `ContactRequests` en `src/Api/ContactRequests.Server/Program.cs`

**Checkpoint**: La composición transversal existe sin referencias de `Common.Presentation` hacia
`Modules.*` y sin depender de Azure durante restore, build o unit tests.

---

## Phase 3: User Story 1 - Registrar una solicitud de contacto (Priority: P1)

**Goal**: Crear exactamente una solicitud nueva por cada entrada válida y devolver su identificador
UUID v7 y su instante UTC, aun cuando el contenido ya exista.

**Independent Test**: Ejecutar los unit tests de US1 con datos válidos, límites inclusivos,
espacios exteriores y dos entradas idénticas; cada alta debe persistirse una sola vez y producir un
identificador distinto.

### Domain for User Story 1

- [X] T010 [US1] Completar la factory e invariantes de `ContactRequest`, incluyendo recorte de Unicode `White_Space`, conteo por valores escalares y política de correo FR-007, en `src/Modules/ContactRequests/Domain/ContactRequest.cs` y `src/Modules/ContactRequests/Domain/ContactRequestRules.cs`

### Unit Tests for User Story 1

- [X] T011 [P] [US1] Probar longitudes mínimas/máximas por valores escalares, recorte de espacios ASCII y Unicode `White_Space`, conservación exacta del correo y estado inmutable en `src/Modules/ContactRequests/Tests/Domain/ContactRequestTests.cs`

### Application, Infrastructure and Presentation for User Story 1

- [X] T012 [US1] Definir `CreateContactRequestCommand` y `CreateContactRequestResult` sin tipos HTTP en `src/Modules/ContactRequests/Application/Create/CreateContactRequestCommand.cs` y `src/Modules/ContactRequests/Application/Create/CreateContactRequestResult.cs`
- [X] T013 [US1] Implementar `CreateContactRequestHandler` con un `CreatedAtUtc`, hasta tres intentos totales, UUID v7 nuevo y exactamente una llamada `AddAsync` por intento; definir y lanzar `ContactRequestIdentifierAllocationException` desde `src/Modules/ContactRequests/Application/Create/` al agotar los tres intentos
- [X] T014 [US1] Probar creación, IDs distintos, timestamp único, tres intentos y agotamiento sin alta en `src/Modules/ContactRequests/Tests/Application/CreateContactRequestHandlerTests.cs` y `src/Modules/ContactRequests/Tests/TestDoubles/InMemoryContactRequestRepository.cs`
- [X] T015 [P] [US1] Implementar `ContactRequestsDbContext` y mapping con PK `uniqueidentifier`, `datetimeoffset`, Email `nvarchar(320)` y Name/Subject/Message `nvarchar(300/400/4000)` en `src/Modules/ContactRequests/Infrastructure/Persistence/ContactRequestsDbContext.cs` y `Configurations/ContactRequestConfiguration.cs`, sin migrations ni `EnsureCreated()`
- [X] T016 [US1] Implementar `SqlContactRequestRepository` en `src/Modules/ContactRequests/Infrastructure/Persistence/SqlContactRequestRepository.cs`: un `SaveChangesAsync` por llamada, reconocer solo colisión de PK, descartar la entidad fallida, traducirla a `ContactRequestIdentifierCollisionException`, propagar otros fallos y permitir contenido duplicado
- [X] T017 [US1] Registrar `ContactRequestsDbContext` scoped con SQL Server y `IContactRequestRepository` en `src/Modules/ContactRequests/Infrastructure/DependencyInjection.cs`, usando únicamente `ConnectionStrings:ContactRequests` suministrada externamente
- [X] T018 [US1] Implementar POST y una política de tamaño verificable que acepte hasta 8192 bytes y rechace 8193 antes de invocar Wolverine, con handler `413`, en `src/Modules/ContactRequests/Presentation/Endpoints/CreateContactRequestEndpoint.cs`, `Policies/RequestBodySizePolicy.cs`, `Contracts/CreateContactRequestContracts.cs`, `Errors/RequestBodyTooLargeExceptionHandler.cs` y `DependencyInjection.cs`
- [X] T019 [US1] Implementar `src/Modules/ContactRequests/Presentation/Errors/ContactRequestIdentifierAllocationExceptionHandler.cs` para `503`/`Retry-After: 1`; alinear `201`, `400`, `413`, `500`, `503`, headers y schemas con `specs/001-contact-requests/contracts/openapi.yaml`

**Checkpoint**: US1 registra entradas válidas como recursos independientes y sus unit tests pasan
sin SQL Server ni Azure.

---

## Phase 4: User Story 2 - Rechazar solicitudes inválidas de forma completa (Priority: P2)

**Goal**: Rechazar todos los incumplimientos aplicables con errores por campo y sin crear un
agregado ni invocar persistencia.

**Independent Test**: Ejecutar los unit tests de US2 para campos ausentes, vacíos,
whitespace-only, límites excedidos, correo inválido y múltiples fallos; todos deben informar las
reglas aplicables y dejar cero altas.

### Application Validation for User Story 2

- [X] T020 [US2] Implementar validator en `src/Modules/ContactRequests/Application/Create/CreateContactRequestValidator.cs`, una política JSON camelCase case-sensitive verificable que rechace propiedades desconocidas antes de invocar Wolverine en `src/Modules/ContactRequests/Presentation/Policies/StrictJsonInputPolicy.cs`, y registrarla junto con `Errors/UnknownJsonPropertyExceptionHandler.cs` en `src/Modules/ContactRequests/Presentation/DependencyInjection.cs`

### Unit Tests for User Story 2

- [X] T021 [US2] Probar campos ausentes/vacíos, whitespace-only, excesos, correo inválido, límites inclusivos y acumulación de errores en `src/Modules/ContactRequests/Tests/Application/CreateContactRequestValidatorTests.cs`
- [X] T022 [P] [US2] Probar que la factory rechaza atómicamente cada regla inválida y no produce un agregado parcial en `src/Modules/ContactRequests/Tests/Domain/ContactRequestInvalidInputTests.cs`

### Pipeline and Presentation for User Story 2

- [X] T023 [US2] Registrar FluentValidation antes del handler de creación y probar como unidad que el límite Application no invoque `IContactRequestRepository` ante entrada inválida en `src/Modules/ContactRequests/Application/DependencyInjection.cs` y `src/Modules/ContactRequests/Tests/Application/CreateContactRequestInvalidInputHandlerTests.cs`
- [X] T024 [US2] Implementar y registrar el `IExceptionHandler` de validación del módulo con Validation Problem Details `400`, extensión `errors` y `traceId`, sin repetir nombres, correos, asuntos, mensajes ni valores rechazados, en `src/Modules/ContactRequests/Presentation/Errors/ContactRequestValidationExceptionHandler.cs` y `src/Modules/ContactRequests/Presentation/DependencyInjection.cs`; probar como unidad en `src/Modules/ContactRequests/Tests/Presentation/CreateContactRequestHttpPolicyTests.cs` propiedad desconocida, 8192/8193 bytes, `400`/`413` y que los rechazos ocurran antes de mediación o persistencia
- [X] T025 [US2] Verificar y ajustar el rechazo HTTP completo contra el schema `ValidationProblemDetails` y la respuesta `400` de POST en `specs/001-contact-requests/contracts/openapi.yaml` y `src/Modules/ContactRequests/Presentation/Errors/ContactRequestValidationExceptionHandler.cs`

**Checkpoint**: US2 rechaza entradas inválidas antes de persistir y produce Problem Details seguro
y comprensible.

---

## Phase 5: User Story 3 - Consultar una solicitud por su identificador (Priority: P3)

**Goal**: Recuperar la solicitud que coincide exactamente con el identificador entregado y devolver
el mismo resultado `404` para identificadores desconocidos, incompletos, alterados o malformados.

**Independent Test**: Ejecutar los unit tests de US3 con un identificador existente, uno
desconocido y strings malformados; solo el exacto devuelve los seis campos y ninguna consulta
devuelve coincidencias aproximadas.

### Application for User Story 3

- [X] T026 [US3] Definir `GetContactRequestQuery`, `GetContactRequestResult`, `GetContactRequestQueryValidator` con error code `ExactIdentifierNotFound` y `ContactRequestNotFoundException` en `src/Modules/ContactRequests/Application/GetById/`
- [X] T027 [US3] Mantener `GetContactRequestQuery.ContactRequestId` como string; validarlo con FluentValidation, parsearlo dentro de `GetContactRequestHandler.cs` solo tras pipeline exitoso y mapear `ExactIdentifierNotFound` al mismo `404` en `Presentation/Errors/ContactRequestValidationExceptionHandler.cs`

### Unit Tests for User Story 3

- [X] T028 [US3] Probar consulta exacta, retorno de los seis campos, `404` lógico uniforme para identificadores malformados/desconocidos y propagación de fallos inesperados del repositorio en `src/Modules/ContactRequests/Tests/Application/GetContactRequestHandlerTests.cs`

### Presentation for User Story 3

- [X] T029 [US3] Implementar y registrar los records HTTP, el Minimal API `GET /contact-requests/{contactRequestId}` que delega a Wolverine y el `IExceptionHandler` not-found del módulo en `src/Modules/ContactRequests/Presentation/Endpoints/GetContactRequestEndpoint.cs`, `src/Modules/ContactRequests/Presentation/Contracts/GetContactRequestContracts.cs`, `src/Modules/ContactRequests/Presentation/Errors/ContactRequestNotFoundExceptionHandler.cs` y `src/Modules/ContactRequests/Presentation/DependencyInjection.cs`; el `404` solo puede exponer estado, título seguro y `traceId`, sin eco del identificador ni datos de contacto
- [X] T030 [US3] Alinear parámetro string, respuesta con seis campos, `200`, `404`, `500` y content types entre `src/Modules/ContactRequests/Presentation/Endpoints/GetContactRequestEndpoint.cs` y `specs/001-contact-requests/contracts/openapi.yaml`

**Checkpoint**: US3 recupera únicamente la coincidencia exacta sin autenticación ni divulgación de
otra solicitud.

---

## Final Phase: Local Verification and Cross-Cutting Completion

**Purpose**: Completar las obligaciones transversales y producir evidencia local del Definition of
Done antes de implementación convergente.

- [X] T031 Implementar health mediado en `src/Modules/ContactRequests/Application/Health/`, `src/Modules/ContactRequests/Infrastructure/Health/`, `src/Api/ContactRequests.Server/Health/HealthEndpoint.cs` y `src/Api/ContactRequests.Server/Program.cs`
- [X] T032 Ejecutar `dotnet restore ContactRequests.slnx` desde la raíz y registrar el resultado en `specs/001-contact-requests/tasks.md`
- [X] T033 Ejecutar `dotnet build ContactRequests.slnx -c Release --no-restore` desde la raíz y registrar cero errores y cero warnings .NET en `specs/001-contact-requests/tasks.md`
- [X] T034 Ejecutar `dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build` y registrar todos los unit tests xUnit exitosos en `specs/001-contact-requests/tasks.md`
- [X] T035 Definir `$coverageOutput = Join-Path (Get-Location) 'artifacts\coverage\contact-requests\'`, ejecutar `dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build /p:CollectCoverage=true /p:CoverletOutput="$coverageOutput" /p:CoverletOutputFormat=cobertura /p:Threshold=80 /p:ThresholdType=line` y conservar `artifacts/coverage/contact-requests/coverage.cobertura.xml`
- [X] T036 [P] Auditar el módulo DDD, las cuatro capas, referencias de proyectos, Repository Pattern y el flujo Minimal API → Wolverine → Application → Domain → repository contra `specs/001-contact-requests/plan.md` y `ContactRequests.slnx`
- [X] T037 Ejecutar `npx --yes @redocly/cli@2.41.1 lint specs/001-contact-requests/contracts/openapi.yaml` y registrar exit code cero en `specs/001-contact-requests/tasks.md`
- [X] T038 Comparar uno a uno rutas, parámetros, request/response records, status codes, content types y handlers de `src/Modules/ContactRequests/Presentation/` y `src/Api/ContactRequests.Server/Health/HealthEndpoint.cs` con `specs/001-contact-requests/contracts/openapi.yaml`
- [X] T039 [P] Auditar que los fallos conocidos y Validation Problem Details pertenezcan a `src/Modules/ContactRequests/Presentation/Errors/` y que el fallback `500` pertenezca a `src/Common/Common.Presentation/Errors/` sin referencias `Modules.*`
- [X] T040 [P] Verificar la activación condicional por URI externa, `DefaultAzureCredential`, ausencia de refresh y ausencia de secretos hardcoded en `src/Common/Common.Infrastructure/Configuration/AzureAppConfigurationExtensions.cs` y `src/Api/ContactRequests.Server/Program.cs`
- [X] T041 Verificar, después de T031, Serilog, OpenTelemetry y HealthChecks sin nombres, correos, asuntos, mensajes, payloads, tokens, connection strings, SQL ni stack traces en `src/Common/Common.Infrastructure/Observability/`, `src/Modules/ContactRequests/Infrastructure/Health/` y `src/Api/ContactRequests.Server/`
- [X] T042 Verificar ausencia de auth y `security: []`; registrar la declaración operacional y dataset sintético en `specs/001-contact-requests/tasks.md` Completion Evidence
- [X] T043 Auditar `Application/Create/CreateContactRequestHandler.cs` e `Infrastructure/Persistence/`; registrar en `specs/001-contact-requests/tasks.md` el handoff de performance QA: dataset sintético, 25 usuarios, 10 minutos, mezcla 50/50, cero `5xx` y cero corrupción, sin presentarlo como prueba ejecutada
- [X] T044 Confirmar la ausencia de update, delete, notificaciones, adjuntos, clasificación, deduplicación, idempotencia, mensajería distribuida, integration/performance tests, CI/CD, deployment, recursos Azure, EF Core Migrations y `EnsureCreated()` en `ContactRequests.slnx`, `src/` y `specs/001-contact-requests/tasks.md`
- [ ] T045 Ejecutar manualmente OpenAPI/`quickstart.md` POST→GET y consolidar toda la evidencia sanitizada en `specs/001-contact-requests/tasks.md` bajo `## Completion Evidence`

## Dependencies and Execution Order

### Phase Dependencies

- **Setup (T001–T004)**: no depende de otras fases.
- **Foundational (T005–T009)**: depende de Setup y bloquea todas las stories.
- **US1 (T010–T019)**: depende de Foundational y entrega el MVP.
- **US2 (T020–T025)**: depende de la creación de US1, pero su validación y rechazo se prueban de
  forma independiente.
- **US3 (T026–T030)**: depende del agregado y repositorio establecidos por US1; no depende de US2.
- **Final (T031–T045)**: depende de todas las stories implementadas.

### User Story Dependency Graph

```text
Setup -> Foundational -> US1 (MVP)
                         |-> US2 --|
                         |-> US3 --|-> Final Verification
```

US2 y US3 pueden avanzar en paralelo después de completar US1 porque modifican casos de uso,
tests, endpoints y handlers diferentes. Los cambios compartidos en
`ContactRequests.Presentation/DependencyInjection.cs`, `Program.cs`,
`contracts/openapi.yaml` y `tasks.md` deben mantenerse secuenciales.

### Within Each User Story

- **US1**: Domain → messages/handler e Infrastructure → endpoint → OpenAPI.
- **US2**: validator y tests de Domain/Application → pipeline → handler HTTP → OpenAPI.
- **US3**: query/result/fallo → handler y tests → endpoint/handler HTTP → OpenAPI.
- Las tareas de unit tests se ejecutan junto con la unidad correspondiente; TDD no es obligatorio.

## Parallel Execution Examples

### US1

Después de T010, pueden ejecutarse en paralelo:

```text
T011: unit tests de Domain en Tests/Domain/ContactRequestTests.cs
T012-T014: command, handler y unit tests de Application
T015-T017: mapping, DbContext y repositorio de Infrastructure
```

T018 y T019 permanecen secuenciales porque el endpoint debe existir antes de la comparación final
de su operación OpenAPI.

### US2 and US3

Después de completar US1:

```text
US2: T020-T025 en Application/Tests/Presentation de creación
US3: T026-T030 en Application/Tests/Presentation de consulta
```

La actualización de `specs/001-contact-requests/contracts/openapi.yaml` se serializa entre T025 y
T030.

## Implementation Strategy

### MVP First

1. Completar Setup y Foundational.
2. Completar US1 y demostrar altas válidas, atómicas y siempre nuevas.
3. Detenerse y validar los unit tests de US1 como incremento mínimo.

### Incremental Delivery

1. Añadir US2 para cerrar el rechazo completo y seguro.
2. Añadir US3 para recuperar exclusivamente por identificador exacto.
3. Completar health, verificaciones transversales y evidencia local.

## Requirement Coverage

| Requirement / Acceptance | Task IDs | Evidence |
|---|---|---|
| US1.1, FR-001, FR-008, SC-001 | T010, T012–T018 | Factory, handler, repository, POST y unit tests |
| US1.2, FR-009, SC-004 | T013, T014, T016 | IDs distintos y contenido duplicado permitido |
| US1.3, FR-003, FR-004, FR-005, FR-006 | T010, T011, T020–T022 | Reglas compartidas y tests de bordes |
| US2.1–US2.3, FR-002, FR-007, FR-010, SC-002 | T020–T025 | Validator, pipeline, Domain tests y `400` |
| US3.1, FR-011, FR-012, SC-003, SC-005 | T026–T030, T045 | Query/handler, GET, unit tests y recorrido manual publicado |
| US3.2, FR-013 | T026–T030 | Fallo uniforme exacto/desconocido/malformado y `404` |
| US3.3, FR-014 | T018, T029, T042 | Endpoints abiertos y auditoría de ausencia de auth |
| FR-015 | T044 | Auditoría negativa de capacidades excluidas |
| FR-016 | T020, T024, T025, T038 | Política JSON estricta, prueba sin mediación y contrato `400` |
| FR-017 | T005, T013, T014, T016, T019, T038 | Tres intentos totales, excepción de agotamiento, `503` y fallo atómico |
| FR-018 | T018, T019, T024, T038 | Política 8192/8193, prueba sin mediación, `413` y contrato |
| NFR-001, SC-006 | T013, T015–T017, T043 | Cobertura diferida: performance QA, gate posterior y reporte futuro |
| NFR-002 | T043, T044 | Revisión de diseño sin performance tests en esta fase |
| NFR-003 | T008, T024, T029, T038, T039, T041 | Problem Details seguro y no divulgación |
| NFR-004, NFR-005 | T006–T009, T040–T042, T045 | Configuración segura, declaración operacional y restricción de datos |
| HTTP y health | T018, T019, T024, T025, T029–T031, T037, T038 | Minimal APIs, OpenAPI, Redocly y health |
| Constitución II–V | T001–T009, T015–T019, T023–T031, T036, T039 | Capas, referencias, Wolverine, repositorio y errores |
| Constitución VI | T004, T011, T014, T021–T023, T028, T034, T035 | xUnit y Coverlet >= 80% |
| Constitución VII | T006–T009, T031, T032–T045 | Reproducibilidad, observabilidad, Azure y seguridad |

## Scope Guard

Este `tasks.md` no incluye Sonar, Veracode, SAST, DAST, integration testing, performance testing,
CI/CD, deployment, collectors, dashboards, recursos Azure, provisioning, versionado o despliegue
del esquema físico, EF Core Migrations, `dotnet-ef`, snapshots, `database update`,
`EnsureCreated()`, colas, brokers, outbox, inbox, sagas ni durable messaging.

`speckit.converge` es el gate posterior a `speckit.implement` y no forma parte de estas tareas.

## Completion Evidence

### Estado de tasks

- T001–T044 completadas con evidencia local.
- T045 bloqueada: no hay una instancia SQL Server con el esquema físico administrado externamente.
  La feature no puede provisionar la base, crear migrations ni ejecutar `EnsureCreated()`. Se
  verificó manualmente el arranque y los rechazos HTTP que no requieren persistencia, pero no se
  afirma un recorrido POST válido→GET.

### Comandos reproducibles

- `dotnet restore ContactRequests.slnx`: exit code 0. En el sandbox se apuntó `NUGET_PACKAGES` a
  la caché local existente y se desactivó únicamente el audit remoto de NuGet porque la red está
  bloqueada.
- `dotnet build ContactRequests.slnx -c Release --no-restore`: exit code 0, 0 errores y
  0 warnings .NET.
- `dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build`:
  40 superados, 0 fallidos, 0 omitidos.
- Comando Coverlet de T035: exit code 0; line coverage total 93.61% sobre
  `ContactRequests.Domain` y `ContactRequests.Application`
  (`Application` 94.78%, `Domain` 91.78%). Reporte:
  `artifacts/coverage/contact-requests/coverage.cobertura.xml`.
- `npx --yes @redocly/cli@2.41.1 lint specs/001-contact-requests/contracts/openapi.yaml`:
  exit code 0, contrato válido y un advisory no bloqueante `operation-4xx-response` en `/health`.

### Arquitectura, HTTP y seguridad

- Auditoría de referencias: Domain no tiene referencias; Application solo referencia Domain;
  Infrastructure referencia Application, Domain y Common.Infrastructure; Presentation referencia
  las capas de su módulo y Common.Presentation; Server compone Common y Module.Presentation; Tests
  solo referencia Domain, Application y Presentation.
- Flujo verificado: Minimal APIs → `IMessageBus.InvokeAsync` → Wolverine
  `DurabilityMode.MediatorOnly` → handlers Application → Domain → repositorio Infrastructure.
- Comparación OpenAPI/código: coinciden POST, GET exacto y health; records, parámetros, content
  types, `201/200`, `400/404/413/500/503`, `Location`, `Retry-After: 1` y Problem Details.
- Comprobación HTTP manual sin SQL: ID malformado `404`, entrada inválida `400`, propiedad
  desconocida `400` y cuerpo de 8193 bytes `413`; todos con `application/problem+json`.
- Los cinco fallos conocidos viven en `ContactRequests.Presentation`; el único fallback transversal
  `500` vive en `Common.Presentation`, con cero referencias `Modules.*`.
- Azure App Configuration usa el paquete oficial, URI HTTPS externa y
  `DefaultAzureCredential`; si el endpoint falta no conecta. No hay refresh, secretos hardcoded,
  datos de contacto en observabilidad ni detalles sensibles en health o errores.
- No hay autenticación/autorización y OpenAPI declara `security: []`. Declaración operacional:
  evaluación local restringida a esta sesión y dataset exclusivamente sintético
  (`Ada Lovelace`, `ada@example.test`, asunto y mensaje marcados como sintéticos).
- Auditoría negativa: no existen update, delete, notificaciones, adjuntos, clasificación,
  deduplicación, idempotencia, mensajería distribuida, integration/performance tests, CI/CD,
  deployment, recursos Azure, migrations, `dotnet-ef`, snapshots ni `EnsureCreated()`.

### Gates pendientes

- Performance QA conserva el handoff de NFR-001/SC-006: dataset sintético, 25 usuarios
  simultáneos, 10 minutos, mezcla 50% POST válidos/50% GET exactos, cero `5xx` y cero pérdida,
  mezcla, corrupción o duplicación involuntaria. Esta evidencia no fue ejecutada ni se presenta
  como capacidad validada.
- Para cerrar T045: suministrar `ConnectionStrings:ContactRequests` hacia SQL Server con esquema
  compatible y ejecutar manualmente `quickstart.md` POST válido→GET exacto.
- Después de cerrar T045, ejecutar `speckit.converge`.
