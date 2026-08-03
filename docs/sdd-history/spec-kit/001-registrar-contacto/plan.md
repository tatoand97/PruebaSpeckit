# Implementation Plan: Registrar solicitud de contacto

**Branch**: `[001-registrar-contacto]` | **Date**: 2026-07-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-registrar-contacto/spec.md`

## Summary

La feature implementará un endpoint HTTP para registrar solicitudes de contacto de visitantes, con
validaciones explícitas de nombre, correo y mensaje, y persistencia solo cuando los datos sean
válidos. La respuesta de éxito incluirá identificador único, fecha/hora de creación y estado inicial
`Pending`; en errores de validación se devolverá detalle por campo y sin persistencia.

El diseño seguirá el preset `dotnet-sdd`: monolito modular en .NET 10, Minimal APIs, mediación con
Wolverine (`DurabilityMode.MediatorOnly`), validación con FluentValidation y patrón Repository para
persistencia. Dado que la feature es HTTP, se define contrato OpenAPI y validación estática con
Redocly `2.41.1`.

## Technical Context

**Language/Version**: .NET 10 / C#

**Compiler Defaults**: Nullable enabled; ImplicitUsings enabled

**Application Type**: Monolito modular ASP.NET Core

**Affected DDD Modules**: `ContactRequests` (nuevo módulo para capacidad de registrar y validar
solicitudes de contacto)

**Primary Dependencies**: Wolverine (mediator), FluentValidation, EF Core provider (SQL Server),
Serilog, OpenTelemetry, ASP.NET Core HealthChecks, Azure App Configuration (`Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`)

**Storage**: EF Core + SQL Server (se requiere persistencia transaccional simple de solicitudes y
consultas por id/estado inicial)

**External Interfaces**: HTTP (POST de registro de solicitud)

**Testing**: xUnit unit tests + Coverlet

**Target Platform**: ASP.NET Core service en hosting Linux/Windows con runtime .NET 10

**Performance Goals**: Registro exitoso o validación rechazada en <= 2 segundos para carga nominal
de la aplicación

**Security/Privacy Constraints**: Sin autenticación (visitante), pero con sanitización y validación
de entrada; no exponer secretos, stack traces ni detalles internos en respuestas; PII mínima:
nombre/correo/mensaje

**Scale/Scope**: Alcance limitado a crear solicitudes nuevas; duplicados válidos permitidos;
sin consulta/actualización/eliminación; sin integración con CRM ni correo

## Constitution Check

*GATE: Debe pasar antes de Phase 0 research y volver a comprobarse después de Phase 1 design.*

- [x] `spec.md` define qué y por qué sin introducir decisiones técnicas no requeridas.
- [x] Los módulos afectados representan límites o capacidades DDD reales.
- [x] La estructura y las referencias respetan Clean Architecture.
- [x] Cada abstracción adicional tiene una necesidad concreta.
- [x] La solución usa .NET 10, Minimal APIs y Wolverine solo como mediator.
- [x] El acceso a persistencia pasa por Repository Pattern.
- [x] La estrategia contempla únicamente unit tests y coverage de lógica de negocio.
- [x] Los contratos HTTP y errores relevantes se mantienen en OpenAPI cuando aplican.
- [x] Redocly CLI `2.41.1` valida estáticamente OpenAPI con una ejecución reproducible.
- [x] Los fallos conocidos se traducen en `Module.Presentation` y el fallback inesperado permanece
  en `Common.Presentation` sin dependencias hacia módulos.
- [x] Los estándares transversales aplicables están considerados y Azure App Configuration está
  integrado obligatoriamente en código.
- [x] El versionado y despliegue del esquema físico permanecen fuera del alcance del preset.
- [x] El plan no agrega controles o herramientas fuera del alcance V1.

**Gate Result**: PASS (pre-Phase 0) / PASS (post-Phase 1 design)

**Violations requiring explicit approval**: Ninguna

## Architecture Compliance

### DDD Module Boundaries

| Module | Domain capability / bounded context | Existing or new | Why this boundary is real |
|---|---|---|---|
| ContactRequests | Registro y validación de solicitudes de contacto entrantes | New | Encapsula reglas de negocio y flujo de vida de contacto sin mezclarlo con otros procesos comerciales |

No cree un módulo para una base de datos, protocolo, framework o preocupación transversal.

### Layer Responsibilities

| Module / concern | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| ContactRequests | Entidad `ContactRequest`, invariantes de estado inicial `Pending`, reglas de identidad | Command `RegisterContactRequest`, handler, validator y contratos de entrada/salida | Repositorio EF Core para guardar solicitudes y mapear entidad | Minimal API endpoint HTTP, mapeo de errores a Problem Details y envío a Wolverine |

### Dependency Direction Check

| Project | Intended references | Evidence / project path | Result |
|---|---|---|---|
| `ContactRequests.Domain` | `Common.Domain` only when needed | `PoCFinal/Modules/ContactRequests/Domain` | PASS (planned) |
| `ContactRequests.Application` | `ContactRequests.Domain` | `PoCFinal/Modules/ContactRequests/Application` | PASS (planned) |
| `ContactRequests.Infrastructure` | `ContactRequests.Application`, `Common.Infrastructure`, Domain if needed | `PoCFinal/Modules/ContactRequests/Infrastructure` | PASS (planned) |
| `ContactRequests.Presentation` | Infrastructure/Application/Domain del mismo módulo cuando sean necesarios; `Common.Presentation` | `PoCFinal/Modules/ContactRequests/Presentation` | PASS (planned) |
| `Common.Presentation` | Manejo HTTP transversal sin referencias `Modules.*` | `PoCFinal/Common/Common.Presentation` | PASS (planned) |
| `PoCFinal.Server` | `Common.Presentation`, module Presentation projects | `PoCFinal/Api/PoCFinal.Server` | PASS (planned) |

### Request Flow and Mediation

```text
POST /contact-requests
  -> ContactRequests.Presentation endpoint
  -> Wolverine mediator (DurabilityMode.MediatorOnly)
  -> ContactRequests.Application handler
  -> ContactRequests.Domain rules
  -> IContactRequestRepository
  -> ContactRequests.Infrastructure EF Core repository
```

- **Wolverine configuration**: `DurabilityMode.MediatorOnly`
- **Messages and handlers**: `RegisterContactRequest` + `RegisterContactRequestHandler`
- **Presentation delegation**: endpoint solo arma request DTO, envía command a Wolverine y traduce resultado
- **Explicitly excluded**: queues, brokers, outbox, inbox, sagas and durable messaging

### Persistence Decision

- **Persistence needed**: Yes
- **Selected option**: EF Core + SQL Server
- **Requirement-driven rationale**: requiere almacenar cada solicitud válida (incluyendo duplicados)
  con identificador y fecha/hora de creación para auditoría funcional básica
- **Alternative rejected**: EF Core + MongoDB (no aporta ventaja para este modelo transaccional simple)
- **Repository abstractions**: `IContactRequestRepository` (solo operación de alta)
- **Infrastructure implementations**: `EfContactRequestRepository` en
  `PoCFinal/Modules/ContactRequests/Infrastructure`
- **Direct access audit**: handlers y Presentation no acceden a `DbContext` directamente
- **Physical schema lifecycle**: Fuera del alcance; no EF Core Migrations, `dotnet-ef`, snapshots,
  database update ni `EnsureCreated()` como política sustituta

### Simplicity Review

| Added abstraction or pattern | Requirement / technical need | Simpler option considered |
|---|---|---|
| `IContactRequestRepository` | cumplir patrón Repository y desacoplar Application de EF Core | usar `DbContext` en handler (rechazado por violar Clean Architecture) |
| Validator dedicado de command | reglas explícitas y errores por campo | validación inline en endpoint (rechazado por dispersión y menor testabilidad) |

## Project Structure

### Feature Artifacts

```text
specs/001-registrar-contacto/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

### Source Code

```text
PoCFinal/
├── Api/
│   └── PoCFinal.Server/
├── Common/
│   ├── Common.Domain/
│   ├── Common.Infrastructure/
│   └── Common.Presentation/
└── Modules/
    └── ContactRequests/
        ├── Domain/
        ├── Application/
        ├── Infrastructure/
        ├── Presentation/
        └── Tests/
            └── ContactRequests.Test/
```

**Concrete paths touched by this feature**:

```text
PoCFinal/Api/PoCFinal.Server/Program.cs
PoCFinal/Modules/ContactRequests/Domain/**
PoCFinal/Modules/ContactRequests/Application/**
PoCFinal/Modules/ContactRequests/Infrastructure/**
PoCFinal/Modules/ContactRequests/Presentation/**
PoCFinal/Modules/ContactRequests/Tests/ContactRequests.Test/**
specs/001-registrar-contacto/contracts/openapi.yaml
```

**Structure Decision**: Se crea un único módulo `ContactRequests` alineado al bounded context de
registro de contacto; sin capas nuevas fuera del patrón Domain/Application/Infrastructure/Presentation.

## API, OpenAPI, and Error Handling

- **Minimal API endpoints**: `POST /contact-requests` en `ContactRequests.Presentation`
- **Wolverine message per endpoint**: `RegisterContactRequest` -> `RegisterContactRequestResult`
- **HTTP request/response contracts**:
  - Request: `name`, `email`, `message`
  - 201 response: `id`, `createdAt`, `status`
  - 400 response: Problem Details con `errors` por campo
- **OpenAPI artifact**: `specs/001-registrar-contacto/contracts/openapi.yaml`
- **Success responses**: `201 Created`
- **Relevant error responses**: `400` (validación), `500` (inesperado)
- **Module exception ownership**: fallos de validación y reglas de negocio mapeados en
  `ContactRequests.Presentation`
- **Common fallback**: `500` inesperado en `Common.Presentation` sin referencias a `Modules.*`
- **Problem Details**: uso con `AddProblemDetails()` y `IExceptionHandler`
- **Validation errors**: FluentValidation + extensión `errors` por campo
- **Safe diagnostics**: incluir correlación/traza; no exponer stack trace ni secretos
- **Static validator**:
  `npx --yes @redocly/cli@2.41.1 lint specs/001-registrar-contacto/contracts/openapi.yaml`
- **Validator prerequisites**: npm `>=10`; Node.js `>=22.12.0` o `>=20.19.0 <21.0.0`
- **Lint evidence**: se registrará en implementación/converge (exit code 0)
- **Consistency method**: trazabilidad FR -> endpoint -> OpenAPI -> tests unitarios de validación/handler

## Cross-Cutting Standards

| Concern | Applicability and implementation | Evidence path | Sensitive-data guard |
|---|---|---|---|
| FluentValidation | Requerido para reglas de nombre/correo/mensaje en command | `Modules/ContactRequests/Application/**` | Sin eco inseguro de payload completo |
| Serilog | Reusar configuración base del server, con eventos de alta y fallo validación | `Api/PoCFinal.Server/Program.cs` | Sin correo/mensaje en texto plano completo |
| OpenTelemetry | Trazas de request y handler; métrica de intentos válidos/inválidos | `Api/PoCFinal.Server/Program.cs` | Sin etiquetas con PII |
| HealthChecks | Sin dependencia externa nueva aparte de DB usada por módulo | `Api/PoCFinal.Server/Program.cs` | Salida segura sin secretos |
| Azure App Configuration | Integración obligatoria con endpoint externo opcional y `DefaultAzureCredential`; activar provider solo si existe endpoint | `Api/PoCFinal.Server/Program.cs` | Sin connection strings/secretos hardcoded |

## Unit Testing and Coverage Strategy

- **Business logic in scope**: validaciones de entrada, reglas de estado inicial y flujo de registro
  en Application/Domain
- **Unit test projects**: `Modules/ContactRequests/Tests/ContactRequests.Test`
- **Meaningful behaviors**:
  - acepta longitudes límite válidas (100, 10, 1000)
  - rechaza campos inválidos y no persiste
  - asigna `Pending` siempre en altas válidas
  - permite duplicados válidos como registros independientes
- **Test ordering**: primero tests de validator y handler, luego implementación final
- **xUnit command**: `dotnet test`
- **Coverlet command/report**:
  `dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura`
- **Line coverage threshold**: `>= 80%` para lógica de negocio
- **Justified exclusions**: bootstrap, DI, tipos triviales sin lógica

## Traceability

| Source | Design decision / artifact | Planned evidence |
|---|---|---|
| FR-001..FR-005 | Endpoint POST + command/validator/handler | tests unitarios validator/handler + OpenAPI |
| FR-006..FR-007 | Generación `id`, `createdAt`, `Pending` en flujo de alta | tests unitarios handler + contrato 201 |
| FR-008..FR-009 | Error de validación con campos y sin persistencia | tests unitarios de errores + contrato 400 |
| FR-010 | Exclusión de funcionalidades fuera de alcance | ausencia de endpoints/tareas fuera de alta |
| FR-012 | Duplicados válidos permitidos | test unitario de altas consecutivas iguales |
| SC-001..SC-004 | resultados medibles de alta/validación/estado | evidencia de tests y comportamiento del contrato |

## Complexity and Exceptions

Sin desviaciones ni excepciones aprobables en esta fase.

## Local Definition of Done

- [ ] Todas las tasks de la feature están completadas con evidencia.
- [ ] `dotnet restore` es exitoso.
- [ ] `dotnet build -c Release` es exitoso con cero errores y cero warnings .NET.
- [ ] Todos los unit tests xUnit pasan.
- [ ] Coverlet demuestra al menos 80% de line coverage sobre lógica de negocio con tests
  significativos.
- [x] `contracts/openapi.yaml` existe para HTTP.
- [ ] Redocly CLI `2.41.1` lint finaliza con código cero para el contrato.
- [ ] OpenAPI coincide con endpoints y errores implementados.
- [ ] Los módulos corresponden a límites DDD y contienen Domain/Application/Infrastructure/
  Presentation.
- [ ] Las referencias entre proyectos respetan la dirección autorizada.
- [ ] Repository Pattern, Wolverine mediator y Minimal APIs están respetados.
- [ ] FluentValidation está aplicado donde existe validación.
- [ ] Serilog, OpenTelemetry y HealthChecks cumplen el estándar aplicable.
- [ ] Azure App Configuration está integrado en código y no está marcado `N/A`.
- [ ] No existen secretos hardcoded ni respuestas/logs con información sensible innecesaria.
- [ ] Los errores HTTP usan Problem Details.
- [ ] Los errores conocidos pertenecen a `Module.Presentation`; el fallback inesperado pertenece a
  `Common.Presentation`, que no referencia `Modules.*`.
- [ ] `speckit.converge` finaliza sin brechas pendientes.

**Evidence commands and locations**:
- `dotnet restore`
- `dotnet build -c Release`
- `dotnet test`
- `dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura`
- `npx --yes @redocly/cli@2.41.1 lint specs/001-registrar-contacto/contracts/openapi.yaml`
- Contract path: `specs/001-registrar-contacto/contracts/openapi.yaml`

## Later SDLC Gates — Not Generated Here

Sonar, Veracode, SAST, DAST, performance testing, integration testing, CI/CD, deployment,
provisioning de recursos Azure y versionado o despliegue del esquema físico están fuera de esta
V1. Pueden existir como requisitos o gates organizacionales posteriores, pero este plan no crea
sus herramientas, pipelines, suites ni tareas de ejecución.
