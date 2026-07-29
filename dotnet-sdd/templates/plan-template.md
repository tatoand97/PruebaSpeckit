# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: Este template es completado por `__SPECKIT_COMMAND_PLAN__`.

## Summary

[Requisito principal y enfoque técnico en dos o tres párrafos. No agregue alcance que no exista en
spec.md.]

## Technical Context

**Language/Version**: .NET 10 / C# correspondiente a .NET 10

**Compiler Defaults**: Nullable enabled; ImplicitUsings enabled

**Application Type**: Monolito modular ASP.NET Core

**Affected DDD Modules**: [Módulos existentes o nuevos, capacidad de dominio y razón del límite]

**Primary Dependencies**: [Wolverine mediator, FluentValidation y dependencias realmente usadas]

**Storage**: [EF Core + SQL Server / EF Core + MongoDB / N/A, con razón basada en requisitos]

**External Interfaces**: [HTTP u otras interfaces; N/A cuando no existan]

**Testing**: xUnit unit tests + Coverlet

**Target Platform**: [Sistema operativo/runtime/hosting esperado o NEEDS CLARIFICATION]

**Performance Goals**: [Objetivos derivados de spec.md o N/A con razón]

**Security/Privacy Constraints**: [Límites de confianza, datos sensibles, authN/authZ y secretos]

**Scale/Scope**: [Volumen, concurrencia y alcance funcional relevantes]

## Constitution Check

*GATE: Debe pasar antes de Phase 0 research y volver a comprobarse después de Phase 1 design.*

- [ ] `spec.md` define qué y por qué sin introducir decisiones técnicas no requeridas.
- [ ] Los módulos afectados representan límites o capacidades DDD reales.
- [ ] La estructura y las referencias respetan Clean Architecture.
- [ ] Cada abstracción adicional tiene una necesidad concreta.
- [ ] La solución usa .NET 10, Minimal APIs y Wolverine solo como mediator.
- [ ] El acceso a persistencia pasa por Repository Pattern.
- [ ] La estrategia contempla únicamente unit tests y coverage de lógica de negocio.
- [ ] Los contratos HTTP y errores relevantes se mantienen en OpenAPI cuando aplican.
- [ ] Los estándares transversales aplicables están considerados.
- [ ] El plan no agrega controles o herramientas fuera del alcance V1.

**Gate Result**: [PASS / FAIL]

**Violations requiring explicit approval**: [Ninguna o tabla en Complexity and Exceptions]

## Architecture Compliance

### DDD Module Boundaries

| Module | Domain capability / bounded context | Existing or new | Why this boundary is real |
|---|---|---|---|
| [Module] | [Capability] | [Existing/New] | [Domain rationale] |

No cree un módulo para una base de datos, protocolo, framework o preocupación transversal.

### Layer Responsibilities

| Module / concern | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| [Module] | [Entities, VOs, rules, domain exceptions/events only when needed] | [Use cases, handlers, validators, contracts] | [Repositories, EF Core, adapters] | [Minimal API, HTTP mapping, module composition] |

### Dependency Direction Check

| Project | Intended references | Evidence / project path | Result |
|---|---|---|---|
| `[Module].Domain` | `Common.Domain` only when needed | [path and references] | [PASS/FAIL] |
| `[Module].Application` | `[Module].Domain` | [path and references] | [PASS/FAIL] |
| `[Module].Infrastructure` | `[Module].Application`, `Common.Infrastructure`, Domain if needed | [path and references] | [PASS/FAIL] |
| `[Module].Presentation` | `[Module].Infrastructure`, `Common.Presentation` | [path and references] | [PASS/FAIL] |
| `<ProjectName>.Server` | `Common.Presentation`, module Presentation projects | [path and references] | [PASS/FAIL] |

Domain MUST NOT reference Application, Infrastructure, Presentation or Api. Application MUST NOT
reference concrete persistence or Presentation. Presentation MUST NOT access repositories,
`DbContext` or MongoDB directly.

### Request Flow and Mediation

```text
Minimal API
  -> Presentation
  -> Wolverine mediator
  -> Application handler
  -> Domain
  -> Repository abstraction
  -> Infrastructure implementation
```

- **Wolverine configuration**: `DurabilityMode.MediatorOnly`
- **Messages and handlers**: [Commands/queries and owning Application paths]
- **Presentation delegation**: [How endpoints invoke Wolverine without direct handler calls]
- **Explicitly excluded**: queues, brokers, outbox, inbox, sagas and durable messaging

### Persistence Decision

- **Persistence needed**: [Yes/No]
- **Selected option**: [EF Core + SQL Server / EF Core + MongoDB / N/A]
- **Requirement-driven rationale**: [Consistency, query model, data shape, scale, operations]
- **Alternative rejected**: [Other supported option and why it is not appropriate]
- **Repository abstractions**: [Only the interfaces required by actual use cases]
- **Infrastructure implementations**: [Concrete projects and paths]
- **Direct access audit**: [Evidence that handlers and Presentation do not use concrete storage]

Do not add both supported engines unless the specification requires both. Do not introduce a
generic repository by default.

### Simplicity Review

| Added abstraction or pattern | Requirement / technical need | Simpler option considered |
|---|---|---|
| [Only non-obvious additions] | [Traceable reason] | [Why insufficient] |

Confirm that the design does not create single-use interfaces without reason, empty services,
trivial wrappers, generic repositories, ceremonial CQRS, duplicate DTOs, unnecessary mappers or
domain events/value objects without domain meaning.

## Project Structure

### Feature Artifacts

```text
specs/[###-feature-name]/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml      # Required only for an HTTP feature
└── tasks.md              # Created by __SPECKIT_COMMAND_TASKS__
```

### Source Code

Reemplace los placeholders con nombres y rutas reales. El nombre raíz proviene del aplicativo.

```text
<ProjectName>/
├── Api/
│   └── <ProjectName>.Server/
├── Common/
│   ├── Common.Domain/
│   ├── Common.Infrastructure/
│   └── Common.Presentation/
└── Modules/
    └── <DDDModule>/
        ├── Domain/
        ├── Application/
        ├── Infrastructure/
        ├── Presentation/
        └── Tests/
            └── <Module>.Test/
```

**Concrete paths touched by this feature**:

```text
[List only the files/directories the feature will create or modify]
```

**Structure Decision**: [Cómo se integra la feature sin crear módulos o abstracciones artificiales]

## API, OpenAPI, and Error Handling

Complete esta sección para features HTTP; de lo contrario marque `N/A` con razón.

- **Minimal API endpoints**: [Operation, route, owning Presentation project]
- **Wolverine message per endpoint**: [Command/query and expected response]
- **HTTP request/response contracts**: [Presentation-owned types when useful]
- **OpenAPI artifact**: `specs/[###-feature-name]/contracts/openapi.yaml`
- **Success responses**: [Statuses and schemas]
- **Relevant error responses**: [400/401/403/404/409/500 and justified variations]
- **Problem Details**: [Mapping through `IExceptionHandler` and `AddProblemDetails()`]
- **Validation errors**: [FluentValidation and optional `errors` extension]
- **Safe diagnostics**: [Trace/correlation; no internal or sensitive response details]
- **Consistency method**: [How spec, plan, OpenAPI and implementation will be compared]

OpenAPI is mandatory for HTTP but contract-first is not. The final artifact must represent the
implemented endpoints and their relevant errors.

## Cross-Cutting Standards

| Concern | Applicability and implementation | Evidence path | Sensitive-data guard |
|---|---|---|---|
| FluentValidation | [How/where or N/A] | [path] | [No unsafe input echo] |
| Serilog | [Existing standard reused or required change] | [path] | [No secrets/tokens] |
| OpenTelemetry | [Traces/metrics relevant to feature] | [path] | [Cardinality/data guard] |
| HealthChecks | [Dependency health or no new check needed] | [path] | [Safe output] |
| Azure App Configuration | [Configuration source/refresh or no feature change] | [path] | [No hardcoded secret] |

No collectors, dashboards, external infrastructure or Azure resources are created in this stage.

## Unit Testing and Coverage Strategy

- **Business logic in scope**: [Domain/Application types and any legitimate rule elsewhere]
- **Unit test projects**: [Exact `<Module>.Test` paths]
- **Meaningful behaviors**: [Rules, branches, failures and regression cases]
- **Test ordering**: [Before/after implementation; TDD is not mandatory]
- **xUnit command**: [Reproducible command]
- **Coverlet command/report**: [Reproducible command and report path]
- **Line coverage threshold**: `>= 80%` for business logic
- **Justified exclusions**: [DTOs without logic, bootstrap, DI, migrations, generated code, etc.]

Do not generate integration, performance, DAST, SAST or coverage-padding tests.

## Traceability

| Source | Design decision / artifact | Planned evidence |
|---|---|---|
| [FR/NFR/US acceptance] | [Layer, endpoint, contract or test] | [Path/command/result] |

## Complexity and Exceptions

> Complete solo cuando exista una desviación o complejidad no obvia.

| Deviation / complexity | Why required | Simpler compliant alternative rejected | Approval |
|---|---|---|---|
| [None by default] | [Reason] | [Alternative] | [Status] |

## Local Definition of Done

- [ ] Todas las tasks de la feature están completadas con evidencia.
- [ ] `dotnet restore` es exitoso.
- [ ] `dotnet build -c Release` es exitoso con cero errores y cero warnings .NET.
- [ ] Todos los unit tests xUnit pasan.
- [ ] Coverlet demuestra al menos 80% de line coverage sobre lógica de negocio con tests
  significativos.
- [ ] `contracts/openapi.yaml` existe para HTTP y coincide con endpoints y errores implementados.
- [ ] Los módulos corresponden a límites DDD y contienen Domain/Application/Infrastructure/
  Presentation.
- [ ] Las referencias entre proyectos respetan la dirección autorizada.
- [ ] Repository Pattern, Wolverine mediator y Minimal APIs están respetados.
- [ ] FluentValidation está aplicado donde existe validación.
- [ ] Serilog, OpenTelemetry, HealthChecks y Azure App Configuration cumplen el estándar aplicable.
- [ ] No existen secretos hardcoded ni respuestas/logs con información sensible innecesaria.
- [ ] Los errores HTTP usan Problem Details.
- [ ] `speckit.converge` finaliza sin brechas pendientes.

**Evidence commands and locations**: [Restore/build/test/coverage commands, reports and contract path]

## Later SDLC Gates — Not Generated Here

Sonar, Veracode, SAST, DAST, performance testing, integration testing, CI/CD y deployment están
fuera de esta V1. Pueden existir como requisitos o gates organizacionales posteriores, pero este
plan no crea sus herramientas, pipelines, suites ni tareas de ejecución.
