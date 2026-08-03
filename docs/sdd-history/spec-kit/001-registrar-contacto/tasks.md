# Tasks: Registrar solicitud de contacto

**Input**: Design documents from `/specs/001-registrar-contacto/`

**Prerequisites**: `plan.md` y `spec.md` obligatorios; `research.md`, `data-model.md`, `contracts/openapi.yaml` y `quickstart.md` disponibles.

**Testing**: Solo unit tests con xUnit + Coverlet (mínimo 80% line coverage sobre lógica de negocio).

**Organization**: Tareas agrupadas por user story para implementación y validación independiente.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Puede ejecutarse en paralelo (archivos distintos, sin dependencia directa).
- **[Story]**: Story propietaria (`[US1]`, `[US2]`) en fases de historia.

## Phase 1: Setup

**Purpose**: Crear estructura mínima de proyectos y configuración base .NET 10 para la feature.

- [X] T001 Crear solución `PoCFinal/PoCFinal.sln` y proyectos del módulo `ContactRequests` (Domain/Application/Infrastructure/Presentation/Tests) en `PoCFinal/Modules/ContactRequests/`
- [X] T002 Configurar `TargetFramework`, `Nullable` e `ImplicitUsings` para .NET 10 en `PoCFinal/Modules/ContactRequests/**/*.csproj`
- [X] T003 [P] Agregar referencias de paquetes requeridos (Wolverine, FluentValidation, EF Core SQL Server, xUnit, Coverlet) en `PoCFinal/Modules/ContactRequests/**/*.csproj`
- [X] T004 [P] Definir referencias entre proyectos respetando capas en `PoCFinal/Modules/ContactRequests/**/*.csproj`
- [X] T005 Ajustar referencia del módulo en `PoCFinal/Api/PoCFinal.Server/PoCFinal.Server.csproj` y agregar proyectos a `PoCFinal/PoCFinal.sln`

**Checkpoint**: Esqueleto del módulo listo sin abstracciones artificiales.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Configuración transversal obligatoria antes de implementar stories.

- [X] T006 Configurar Wolverine como mediator (`DurabilityMode.MediatorOnly`) en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T007 Configurar `AddProblemDetails()` y registro de `IExceptionHandler` transversal en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T008 Implementar fallback inesperado (HTTP 500 Problem Details) en `PoCFinal/Common/Common.Presentation/ExceptionHandling/GlobalExceptionHandler.cs`
- [X] T009 Integrar Azure App Configuration con activación condicional por endpoint y `DefaultAzureCredential` en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T010 Aplicar configuración base de Serilog, OpenTelemetry y HealthChecks para la feature en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T011 Crear contrato de repositorio `IContactRequestRepository` en `PoCFinal/Modules/ContactRequests/Application/Abstractions/IContactRequestRepository.cs`
- [X] T012 Crear composición de módulo (registro DI + mapeo endpoint) en `PoCFinal/Modules/ContactRequests/Presentation/DependencyInjection.cs`

**Checkpoint**: Fundaciones listas para implementar stories sin romper arquitectura.

---

## Phase 3: User Story 1 - Registrar solicitud válida (Priority: P1) 🎯 MVP

**Goal**: Permitir registro válido y devolver `id`, `createdAt`, `status=Pending`, incluyendo duplicados válidos.

**Independent Test**: Enviar payload válido y comprobar alta persistida con respuesta 201 y campos requeridos; enviar duplicado válido y comprobar nuevo `id`.

### Unit Tests for User Story 1

- [X] T013 [P] [US1] Crear pruebas unitarias de entidad/estado inicial `Pending` en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/Domain/ContactRequestTests.cs`
- [X] T014 [P] [US1] Crear pruebas unitarias del handler para alta válida y duplicados permitidos en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/Application/RegisterContactRequestHandlerTests.cs`

### Implementation for User Story 1

- [X] T015 [US1] Implementar entidad `ContactRequest` y estado `Pending` en `PoCFinal/Modules/ContactRequests/Domain/ContactRequest.cs`
- [X] T016 [US1] Implementar command y response de registro válido en `PoCFinal/Modules/ContactRequests/Application/RegisterContactRequest/RegisterContactRequestCommand.cs`
- [X] T017 [US1] Implementar handler de registro con asignación de `id` y `createdAt` en `PoCFinal/Modules/ContactRequests/Application/RegisterContactRequest/RegisterContactRequestHandler.cs`
- [X] T018 [US1] Implementar modelo EF y configuración de persistencia en `PoCFinal/Modules/ContactRequests/Infrastructure/Persistence/Configurations/ContactRequestEntityConfiguration.cs`
- [X] T019 [US1] Implementar repositorio EF Core de alta en `PoCFinal/Modules/ContactRequests/Infrastructure/Repositories/EfContactRequestRepository.cs`
- [X] T020 [US1] Implementar endpoint Minimal API `POST /contact-requests` para flujo exitoso en `PoCFinal/Modules/ContactRequests/Presentation/Endpoints/RegisterContactRequestEndpoint.cs`
- [X] T021 [US1] Registrar servicios del módulo y endpoint en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T022 [US1] Ajustar contrato 201 de éxito en `PoCFinal/specs/001-registrar-contacto/contracts/openapi.yaml`

**Checkpoint**: US1 funcional y validable de forma independiente.

---

## Phase 4: User Story 2 - Informar errores de validación (Priority: P2)

**Goal**: Rechazar entradas inválidas con Problem Details + `errors` por campo y sin persistencia.

**Independent Test**: Enviar payload inválido y comprobar HTTP 400 con errores de campos; verificar que repositorio no persiste.

### Unit Tests for User Story 2

- [X] T023 [P] [US2] Crear pruebas unitarias de FluentValidation (vacíos, formato, límites) en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/Application/RegisterContactRequestValidatorTests.cs`
- [X] T024 [P] [US2] Crear pruebas unitarias de no persistencia ante validación fallida en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/Application/RegisterContactRequestInvalidFlowTests.cs`
- [X] T025 [P] [US2] Crear pruebas unitarias de mapeo Problem Details 400 en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/Presentation/ContactRequestExceptionHandlerTests.cs`

### Implementation for User Story 2

- [X] T026 [US2] Implementar `RegisterContactRequestValidator` con reglas de nombre/correo/mensaje en `PoCFinal/Modules/ContactRequests/Application/RegisterContactRequest/RegisterContactRequestValidator.cs`
- [X] T027 [US2] Implementar error de validación del módulo y metadatos de campo en `PoCFinal/Modules/ContactRequests/Application/Errors/ContactRequestValidationException.cs`
- [X] T028 [US2] Implementar `IExceptionHandler` del módulo para devolver 400 Problem Details con `errors` en `PoCFinal/Modules/ContactRequests/Presentation/ExceptionHandling/ContactRequestExceptionHandler.cs`
- [X] T029 [US2] Actualizar endpoint para propagar fallos de validación sin persistencia en `PoCFinal/Modules/ContactRequests/Presentation/Endpoints/RegisterContactRequestEndpoint.cs`
- [X] T030 [US2] Actualizar contrato de errores 400/500 en `PoCFinal/specs/001-registrar-contacto/contracts/openapi.yaml`

**Checkpoint**: US2 funcional y validable de forma independiente.

---

## Final Phase: Local Verification and Cross-Cutting Completion

**Purpose**: Generar evidencia local del Definition of Done del preset dotnet-sdd.

- [X] T031 Ejecutar `dotnet restore` desde `PoCFinal/PoCFinal.sln` y registrar resultado en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T032 Ejecutar `dotnet build -c Release` desde `PoCFinal/PoCFinal.sln` y registrar cero errores/cero warnings .NET en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T033 Ejecutar `dotnet test` para `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/ContactRequests.UnitTests.csproj` y registrar resultado en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T034 Ejecutar `dotnet test /p:CollectCoverage=true /p:CoverletOutput=TestResults\\coverage-business\\ /p:CoverletOutputFormat=cobertura /p:Include='[ContactRequests.Application*]*%2c[ContactRequests.Domain*]*' /p:Threshold=80 /p:ThresholdType=line /p:ThresholdStat=total` en `PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/ContactRequests.UnitTests.csproj` y registrar cobertura en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T035 Ejecutar `npx --yes @redocly/cli@2.41.1 lint specs/001-registrar-contacto/contracts/openapi.yaml` desde `PoCFinal/` y registrar exit code 0 en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T036 Auditar coherencia OpenAPI vs endpoint/errores implementados en `PoCFinal/specs/001-registrar-contacto/contracts/openapi.yaml` y `PoCFinal/Modules/ContactRequests/Presentation/Endpoints/RegisterContactRequestEndpoint.cs`
- [X] T037 Auditar dirección de dependencias y flujo Presentation->Wolverine->Application->Repository en `PoCFinal/Modules/ContactRequests/**/*.csproj` y `PoCFinal/specs/001-registrar-contacto/plan.md`
- [X] T038 Validar ownership de excepciones (módulo para conocidos, common para inesperados) en `PoCFinal/Modules/ContactRequests/Presentation/ExceptionHandling/ContactRequestExceptionHandler.cs` y `PoCFinal/Common/Common.Presentation/ExceptionHandling/GlobalExceptionHandler.cs`
- [X] T039 Validar integración de Azure App Configuration condicional y ausencia de secretos hardcoded en `PoCFinal/Api/PoCFinal.Server/Program.cs`
- [X] T040 Registrar cierre de verificación local y pendientes para `speckit.converge` en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`
- [X] T041 Ejecutar muestra de 20 intentos válidos (quickstart) y registrar cumplimiento de SC-003 (>=19 exitosos en primer intento) en `PoCFinal/specs/001-registrar-contacto/implementation-evidence.md`

---

## Dependencies and Execution Order

### Phase Dependencies

- Phase 1 (Setup) inicia inmediatamente.
- Phase 2 (Foundational) depende de T001-T005.
- US1 (Phase 3) depende de T006-T012.
- US2 (Phase 4) depende de T006-T012; dentro de US2, T029 se ejecuta después de T020 por compartir archivo de endpoint.
- Final Phase depende de T013-T030.

### User Story Dependencies

- **US1 (P1)**: independiente tras Foundational; define base funcional MVP.
- **US2 (P2)**: independiente tras Foundational para validaciones y manejo de errores; la actualización final del endpoint (T029) se secuencia después de T020.

### Within User Stories

- US1: tests (T013-T014) -> Domain/Application (T015-T017) -> Infrastructure (T018-T019) -> Presentation/OpenAPI (T020-T022).
- US2: tests (T023-T025) -> validation/error model (T026-T027) -> exception/endpoint mapping (T028-T029) -> OpenAPI (T030).

### Parallel Opportunities

- Phase 1: T003 y T004 en paralelo.
- US1: T013 y T014 en paralelo.
- US2: T023, T024 y T025 en paralelo.
- Final Phase: T036, T037, T038 y T039 pueden ejecutarse en paralelo tras T031-T035.

---

## Parallel Example: User Story 2

```text
Task: T023 [US2] RegisterContactRequestValidatorTests.cs
Task: T024 [US2] RegisterContactRequestInvalidFlowTests.cs
Task: T025 [US2] ContactRequestExceptionHandlerTests.cs
```

---

## Implementation Strategy

### MVP First (US1)

1. Completar Setup + Foundational.
2. Completar US1 (T013-T022).
3. Validar criterio independiente de US1 (alta válida + duplicados válidos).

### Incremental Delivery

1. Agregar US2 (T023-T030) para cerrar invalidaciones y Problem Details.
2. Ejecutar verificación local final (T031-T041).
3. Continuar con `speckit.converge`.

---

## Requirement Coverage

| Requirement / Acceptance | Task IDs | Evidence |
|---|---|---|
| FR-001, FR-005, US1 escenario válido | T016, T017, T020 | `RegisterContactRequestCommand.cs`, `RegisterContactRequestHandler.cs`, `RegisterContactRequestEndpoint.cs` |
| FR-002, FR-003, FR-004 | T023, T026 | `RegisterContactRequestValidatorTests.cs`, `RegisterContactRequestValidator.cs` |
| FR-006, FR-007, SC-004 | T013, T015, T017, T022 | pruebas de dominio/handler + contrato 201 |
| FR-008, FR-009, US2 escenario inválido | T024, T027, T028, T029, T030 | pruebas de no persistencia + Problem Details 400 + OpenAPI |
| FR-010 (scope guard) | T037, T040 | auditoría de arquitectura y evidencia de cierre |
| FR-011 (privacidad de respuesta) | T028, T038, T039 | handler de errores + auditoría de seguridad |
| FR-012 (duplicados válidos) | T014, T017 | tests handler + implementación de alta |
| SC-001, SC-002 | T014, T024, T033 | tests de flujo válido/inválido |
| SC-003 | T041 | evidencia de muestra mínima (20 intentos válidos, >=19 exitosos) |
| Setup módulo y baseline .NET 10 | T001, T002, T003, T004, T005 | proyectos, referencias y configuración inicial |
| Foundation de errores y observabilidad | T008, T010, T012 | fallback global, estándares transversales y composición del módulo |
| Persistencia y modelo técnico de US1 | T018, T019 | configuración EF + repositorio de alta |
| Definition of Done de build Release | T031, T032 | evidencia de restore/build sin warnings |
| Constitución II, IV, V | T006, T007, T011, T020, T037 | configuración Wolverine, capas, endpoint, auditoría |
| Constitución VI (xUnit/Coverlet >=80%) | T033, T034 | salida de comandos de test/cobertura |
| Constitución VII (Azure App Configuration) | T009, T039 | integración condicional + auditoría |
| OpenAPI + Redocly 2.41.1 | T022, T030, T035, T036 | contrato actualizado + lint + comparación |

---

## Scope Guard

Este `tasks.md` excluye explícitamente tareas de CI/CD, deployment, infraestructura externa,
performance testing, integration testing, EF Core Migrations, `dotnet-ef`, snapshots y mensajería
distribuida (colas/brokers/outbox/inbox/sagas).
