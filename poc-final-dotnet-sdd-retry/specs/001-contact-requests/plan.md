# Implementation Plan: Registro y consulta de solicitudes de contacto

**Branch**: `001-contact-requests` | **Date**: 2026-07-29 | **Spec**:
[spec.md](./spec.md)

**Input**: Feature specification from `specs/001-contact-requests/spec.md`

## Summary

Construir una API HTTP en .NET 10 para registrar solicitudes de contacto y recuperarlas por su
identificador exacto. La solución será un monolito modular con un único módulo DDD
`ContactRequests`; ASP.NET Core Minimal APIs delegará mediante Wolverine a handlers de Application,
el Domain protegerá las invariantes y EF Core con SQL Server conservará cada solicitud mediante un
repositorio específico.

Cada alta válida genera un UUID v7 y un instante UTC nuevos, incluso si el contenido ya existe. La
validación es atómica con FluentValidation y guardas de Domain. Nombre, asunto y mensaje se
recortan y sus límites cuentan valores escalares Unicode. El correo se conserva sin normalización y
se valida mediante la política ASCII observable de FR-007. La consulta no requiere
autenticación y, mientras ese comportamiento continúe, solo admite datos sintéticos o no sensibles
en un entorno controlado.

## Technical Context

**Language/Version**: .NET 10 SDK `10.0.302` / C# correspondiente a .NET 10

**Compiler Defaults**: Nullable enabled; ImplicitUsings enabled

**Application Type**: Monolito modular ASP.NET Core

**Affected DDD Modules**: Nuevo módulo `ContactRequests`, límite único para la capacidad de registrar
y consultar la misma raíz de agregado

**Primary Dependencies**: ASP.NET Core Minimal APIs, Wolverine en
`DurabilityMode.MediatorOnly`, FluentValidation, EF Core SQL Server, Serilog, OpenTelemetry,
HealthChecks, `Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`, xUnit y Coverlet

**Storage**: EF Core + SQL Server; clave única, inserción atómica y consulta exacta por identificador

**External Interfaces**: HTTP JSON con
`POST /contact-requests`, `GET /contact-requests/{contactRequestId}` y endpoint operativo
`GET /health`

**Testing**: Solo unit tests xUnit + Coverlet sobre Domain, Application y las políticas HTTP con
comportamiento verificable de Presentation

**Target Platform**: Runtime ASP.NET Core .NET 10 multiplataforma; validación local en Windows con
SDK fijado por `global.json`; hosting y deployment fuera de alcance

**Performance Goals**: En el gate posterior, 25 usuarios simultáneos durante 10 minutos con mezcla
50% POST válidos y 50% GET exactos, cero `5xx` y cero pérdida, mezcla, corrupción o duplicación
involuntaria; no se agrega prueba de performance en esta fase

**Security/Privacy Constraints**: Sin autenticación ni autorización por requisito; únicamente datos
sintéticos o no sensibles en entorno controlado; identificadores no secuenciales. Las respuestas
funcionales GET contienen los datos exigidos por FR-012; errores, respuestas operativas, logs,
trazas y métricas no contienen datos de contacto, secretos, tokens, connection strings, SQL ni
stack traces

**Scale/Scope**: Una entidad, dos operaciones funcionales y un health endpoint; sin update, delete,
notificaciones, adjuntos, clasificación, deduplicación, idempotencia ni integraciones funcionales
externas

## Constitution Check

*GATE inicial ejecutado antes de Phase 0 y revalidado después de Phase 1.*

- [x] `spec.md` define qué y por qué sin introducir decisiones técnicas no requeridas.
- [x] El módulo afectado representa una capacidad DDD real.
- [x] La estructura y las referencias respetan Clean Architecture.
- [x] Cada abstracción adicional tiene una necesidad concreta.
- [x] La solución usa .NET 10, Minimal APIs y Wolverine solo como mediator.
- [x] El acceso a persistencia pasa por Repository Pattern.
- [x] La estrategia contempla únicamente unit tests y coverage de lógica de negocio.
- [x] Los endpoints y errores relevantes se mantienen en OpenAPI.
- [x] Redocly CLI `2.41.1` valida OpenAPI con exit code cero.
- [x] Los fallos conocidos se traducen en `ContactRequests.Presentation` y el fallback inesperado
  permanece en `Common.Presentation` sin dependencias hacia módulos.
- [x] Serilog, OpenTelemetry, HealthChecks y Azure App Configuration están considerados.
- [x] El versionado y despliegue del esquema físico permanecen fuera del alcance.
- [x] El plan no agrega controles o herramientas fuera del alcance V1.

**Gate Result**: PASS antes de Phase 0; PASS después de Phase 1

**Violations requiring explicit approval**: Ninguna

La advertencia recomendada de Redocly para que `/health` declare una respuesta `4XX` no es una
violación: el endpoint no recibe entrada ni define un resultado funcional `4XX`. No se inventa una
respuesta imposible solo para silenciar el advisory; el lint finaliza con exit code cero.

## Architecture Compliance

### DDD Module Boundaries

| Module | Domain capability / bounded context | Existing or new | Why this boundary is real |
|---|---|---|---|
| `ContactRequests` | Registrar solicitudes y recuperarlas por identidad exacta | New | Ambos casos de uso operan sobre la misma raíz, reglas, identidad y persistencia |

No se crean módulos de escritura/lectura separados ni módulos para HTTP, SQL Server,
observabilidad o configuración.

### Layer Responsibilities

| Module / concern | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| `ContactRequests` | Entidad, factory, normalización, invariantes y error de dominio cuando aplique | Commands/queries, handlers, validators, resultados e interfaz del repositorio | `DbContext`, mapping EF Core, repositorio SQL Server y registro DI | Minimal API, contratos HTTP, delegación a Wolverine y mapeo de fallos conocidos |
| Cross-cutting | Sin tipos compartidos por ahora | Sin servicios de caso de uso comunes | Serilog, OpenTelemetry, HealthChecks y Azure App Configuration | Problem Details y fallback inesperado |

### Dependency Direction Check

| Project | Intended references | Evidence / project path | Result |
|---|---|---|---|
| `ContactRequests.Domain` | Ninguna referencia a capas; `Common.Domain` no se crea porque no hay concepto compartido | `src/Modules/ContactRequests/Domain/ContactRequests.Domain.csproj` | PASS by design |
| `ContactRequests.Application` | `ContactRequests.Domain` | `src/Modules/ContactRequests/Application/ContactRequests.Application.csproj` | PASS by design |
| `ContactRequests.Infrastructure` | `ContactRequests.Application`, `ContactRequests.Domain`, `Common.Infrastructure` | `src/Modules/ContactRequests/Infrastructure/ContactRequests.Infrastructure.csproj` | PASS by design |
| `ContactRequests.Presentation` | Infrastructure, Application y Domain del mismo módulo; `Common.Presentation` | `src/Modules/ContactRequests/Presentation/ContactRequests.Presentation.csproj` | PASS by design |
| `Common.Presentation` | ASP.NET Core transversal; ninguna referencia `Modules.*` | `src/Common/Common.Presentation/Common.Presentation.csproj` | PASS by design |
| `ContactRequests.Server` | `Common.Infrastructure`, `Common.Presentation`, `ContactRequests.Presentation` | `src/Api/ContactRequests.Server/ContactRequests.Server.csproj` | PASS by design |
| `ContactRequests.Tests` | Domain, Application y Presentation del mismo módulo; sin referencia a Infrastructure ni Server | `src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj` | PASS by design |

`Common.Domain` no se crea vacío: no existe una abstracción de dominio compartida. Si aparece una
necesidad real en otra feature, deberá justificarse entonces.

### Request Flow and Mediation

```text
Minimal API
  -> ContactRequests.Presentation
  -> Wolverine mediator
  -> ContactRequests.Application handler
  -> ContactRequests.Domain
  -> IContactRequestRepository
  -> ContactRequests.Infrastructure
  -> SQL Server
```

- **Wolverine configuration**:
  `options.Durability.Mode = DurabilityMode.MediatorOnly` en el composition root.
- **Messages and handlers**:
  `CreateContactRequestCommand`/`CreateContactRequestHandler` y
  `GetContactRequestQuery`/`GetContactRequestHandler` bajo
  `src/Modules/ContactRequests/Application`.
- **Presentation delegation**: cada endpoint construye un message y usa `IMessageBus.InvokeAsync`;
  no invoca handlers, repositorios ni `DbContext` directamente.
- **Explicitly excluded**: queues, brokers, outbox, inbox, sagas, domain events para mensajería y
  durable messaging.

### Persistence Decision

- **Persistence needed**: Yes.
- **Selected option**: EF Core + SQL Server.
- **Requirement-driven rationale**: persistencia durable, clave única, alta de una sola raíz
  atómica, lectura exacta y comportamiento seguro bajo concurrencia.
- **Alternative rejected**: EF Core + MongoDB es viable para un documento aislado, pero no aporta
  una capacidad requerida frente al modelo relacional estable y sus restricciones de clave.
- **Repository abstractions**: `IContactRequestRepository` con solo `AddAsync` y `GetByIdAsync`;
  no repositorio genérico.
- **Infrastructure implementations**:
  `ContactRequestsDbContext`, `ContactRequestConfiguration` y
  `SqlContactRequestRepository` bajo
  `src/Modules/ContactRequests/Infrastructure/Persistence`.
- **Direct access audit**: Application solo referencia la interfaz; Presentation solo envía
  messages; EF Core y SQL Server aparecen únicamente en Infrastructure y composición DI.
- **Atomicity**: cada intento ejecuta una inserción y un `SaveChangesAsync`; hay como máximo tres
  intentos por command y cualquier agotamiento deja cero registros.
- **Identifier collision**: ante una colisión de clave, el handler genera un UUID v7 nuevo y reintenta
  hasta completar un máximo de tres intentos totales; cada intento usa el mismo `CreatedAtUtc`,
  genera un UUID nuevo y realiza exactamente una llamada `AddAsync`. Si los tres colisionan, falla
  sin creación parcial mediante `ContactRequestIdentifierAllocationException`, fallo conocido que
  `ContactRequests.Presentation` traduce a `503` Problem Details con `Retry-After: 1`.
  Infrastructure reconoce exclusivamente la violación de la PK, descarta la entidad
  fallida del change tracker y lanza `ContactRequestIdentifierCollisionException`, definida junto al
  contrato del repositorio sin referencias a EF Core; otros fallos no se traducen. Los unit tests
  fuerzan colisiones para verificar ambos resultados.
- **Concurrency**: un `DbContext` scoped por solicitud HTTP; UUID v7 por alta y PK única; contenido
  duplicado permitido.
- **Physical schema lifecycle**: fuera del alcance; sin EF Core Migrations, `dotnet-ef`, snapshots,
  database update ni `EnsureCreated()` como política sustituta.

### Simplicity Review

| Added abstraction or pattern | Requirement / technical need | Simpler option considered |
|---|---|---|
| Repositorio específico | Clean Architecture y persistencia desacoplada en handlers | Acceso directo a `DbContext`, rechazado por dependencia concreta |
| Factory de `ContactRequest` | Normalizar y proteger invariantes atómicamente | Constructor público, rechazado porque permite estado inválido |
| `TimeProvider` del framework | Instante UTC determinista en unit tests | Servicio de reloj propio, rechazado por wrapper innecesario |
| Error `ContactRequestNotFound` | Resultado conocido que Presentation mapea a `404` | `null` propagado al endpoint, rechazado porque dispersa el mapeo |

No se crean generic repositories, factories externas, base classes, mappers, domain events, value
objects, servicios vacíos, DTOs duplicados ni CQRS ceremonial. Commands y queries son mensajes
concretos para Wolverine, no dos modelos de persistencia.

## Project Structure

### Feature Artifacts

```text
specs/001-contact-requests/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
│   └── requirements.md
└── contracts/
    └── openapi.yaml
```

`tasks.md` fue generado por `/speckit-tasks` y debe mantenerse alineado con estos artefactos.

### Source Code

```text
ContactRequests.slnx
src/
├── Api/
│   └── ContactRequests.Server/
│       ├── ContactRequests.Server.csproj
│       └── Program.cs
├── Common/
│   ├── Common.Infrastructure/
│   │   └── Common.Infrastructure.csproj
│   └── Common.Presentation/
│       └── Common.Presentation.csproj
└── Modules/
    └── ContactRequests/
        ├── Domain/
        │   └── ContactRequests.Domain.csproj
        ├── Application/
        │   └── ContactRequests.Application.csproj
        ├── Infrastructure/
        │   └── ContactRequests.Infrastructure.csproj
        ├── Presentation/
        │   └── ContactRequests.Presentation.csproj
        └── Tests/
            └── ContactRequests.Tests.csproj
```

**Concrete paths touched by this feature**:

```text
ContactRequests.slnx
Directory.Build.props
Directory.Packages.props
src/Api/ContactRequests.Server/
src/Common/Common.Infrastructure/
src/Common/Common.Presentation/
src/Modules/ContactRequests/Domain/
src/Modules/ContactRequests/Application/
src/Modules/ContactRequests/Infrastructure/
src/Modules/ContactRequests/Presentation/
src/Modules/ContactRequests/Tests/
```

**Structure Decision**: un solo módulo funcional con cuatro capas. Las preocupaciones transversales
con implementación real viven en los dos proyectos Common aplicables. No se crea `Common.Domain`
vacío ni otro módulo artificial.

## API, OpenAPI, and Error Handling

- **Minimal API endpoints**:
  - `POST /contact-requests`, propiedad de `ContactRequests.Presentation`.
  - `GET /contact-requests/{contactRequestId}`, propiedad de
    `ContactRequests.Presentation`.
  - `GET /health`, endpoint transversal registrado por el composition root.
- **Wolverine message per endpoint**:
  - POST → `CreateContactRequestCommand` → identificador e instante UTC.
  - GET by id → `GetContactRequestQuery` → snapshot completo o fallo conocido not-found.
  - Health → `GetContactRequestsHealthQuery`; el handler de Application usa
    `IContactRequestsHealthProbe` y su implementación Infrastructure consulta el estado agregado.
- **HTTP request/response contracts**: records propios de Presentation; Application devuelve
  resultados de caso de uso y no tipos HTTP.
- **OpenAPI artifact**:
  `specs/001-contact-requests/contracts/openapi.yaml`.
- **Success responses**:
  - POST `201 Created`, body con `id`/`createdAtUtc` y header `Location`.
  - GET by id `200` con los seis campos.
  - Health `200` con estado agregado seguro.
- **Relevant error responses**:
  - `400` Validation Problem Details para campos ausentes, vacíos, fuera de longitud o correo
    inválido.
  - `404` Problem Details para identificador desconocido, incompleto, alterado o malformado.
  - `500` Problem Details para fallo inesperado.
  - POST `503` con `Retry-After: 1` cuando se agotan tres colisiones de identidad.
  - POST `413` Problem Details cuando el cuerpo supera 8192 bytes, antes de binding/persistencia.
  - Health `503` cuando SQL Server o la aplicación no estén saludables.
  - No se declaran `401`, `403` ni `409`: no hay autenticación, autorización ni conflicto por
    duplicidad en el alcance.
- **Module exception ownership**: validación y not-found se traducen en
  `ContactRequests.Presentation` mediante handlers del módulo.
- **Common fallback**: el handler inesperado/transversal de `Common.Presentation` produce `500` y
  no referencia ningún assembly `Modules.*`.
- **Problem Details**: `AddProblemDetails()` y `IExceptionHandler` en todos los handlers; cada
  respuesta de error tiene `application/problem+json`.
- **Validation errors**: FluentValidation genera una extensión `errors` por campo sin eco
  innecesario del valor.
- **Safe diagnostics**: `traceId`/correlación; sin stack traces, SQL, connection strings, nombres,
  correos, asuntos, mensajes, secretos o tokens.
- **Static validator**:
  `npx --yes @redocly/cli@2.41.1 lint specs/001-contact-requests/contracts/openapi.yaml`.
- **Validator prerequisites**: npm `>=10`; Node.js `>=22.12.0` o
  `>=20.19.0 <21.0.0`.
- **Lint evidence**: ejecutado el 2026-07-29 con Redocly CLI `2.41.1`; exit code `0`; contrato
  válido. Redocly conserva un advisory no bloqueante porque `/health` no inventa un resultado
  `4XX`.
- **Consistency method**: durante `implement` y `converge`, comparar uno a uno rutas, parámetros,
  messages, request/response records, status codes, content types y handlers contra `spec.md`,
  `plan.md` y OpenAPI. El lint no sustituye esta revisión.

No se impone contract-first: el contrato puede ajustarse durante implementación, pero el resultado
final debe coincidir con el código y volver a pasar Redocly.

La deserialización POST usa nombres camelCase sensibles a mayúsculas y
`JsonUnmappedMemberHandling.Disallow`. `UnknownJsonPropertyExceptionHandler` pertenece a
`ContactRequests.Presentation` y devuelve Validation Problem Details `400`, `errors.$ =
["Unknown properties are not allowed."]` y `traceId`, sin repetir nombre ni valor. El límite
`MaxRequestBodySize` de 8192 bytes se aplica antes del binding y se traduce a `413` Problem Details.

## Cross-Cutting Standards

| Concern | Applicability and implementation | Evidence path | Sensitive-data guard |
|---|---|---|---|
| FluentValidation | Validators obligatorios de create y get query; el fallo de formato de `ContactRequestId` usa error code `ExactIdentifierNotFound` y el handler del módulo lo traduce al mismo `404` seguro que ausencia | `src/Modules/ContactRequests/Application` y `ContactRequests.Presentation/Errors` | Mensajes por campo sin repetir valores |
| Serilog | Bootstrap y request logging estructurado reutilizable | `src/Common/Common.Infrastructure/Observability` y `src/Api/ContactRequests.Server/Program.cs` | Excluir body, correo, nombre, asunto, mensaje, tokens y secretos |
| OpenTelemetry | Trazas ASP.NET Core y EF Core; métricas de request/duración con resultado | `src/Common/Common.Infrastructure/Observability` | Sin payloads; rutas normalizadas y cardinalidad acotada |
| HealthChecks | `AddDbContextCheck<ContactRequestsDbContext>` y `/health` con estado mínimo | `src/Modules/ContactRequests/Infrastructure` y Server | Sin exception details, connection string ni SQL |
| Azure App Configuration | Provider oficial con endpoint externo y `DefaultAzureCredential`; activación condicional a URI configurada; sin refresh | `src/Common/Common.Infrastructure/Configuration` y Server | Sin endpoint sensible, connection string o credencial hardcoded |

Paquetes obligatorios para Azure:
`Microsoft.Azure.AppConfiguration.AspNetCore` y `Azure.Identity`. El composition root consulta
`AzureAppConfiguration:Endpoint` desde fuentes locales/entorno y solo ejecuta
`builder.Configuration.AddAzureAppConfiguration(options => options.Connect(endpoint,
new DefaultAzureCredential()))` cuando el valor es una URI absoluta.

No se selecciona refresh. Por ello no se agregan
`builder.Services.AddAzureAppConfiguration()` ni `app.UseAzureAppConfiguration()`; esos métodos
solo se requieren cuando el diseño usa el refresh que los necesita. Restore, build y unit tests
locales no contactan Azure.

No se crean collectors, dashboards, infraestructura externa, recursos Azure, credenciales,
secretos ni pipelines.

## Unit Testing and Coverage Strategy

- **Business logic in scope**:
  factory/invariantes de `ContactRequest`, recorte de campos, límites inclusivos, política de
  correo, creación siempre nueva, timestamps, handlers, validadores, consulta exacta, not-found y
  coordinación atómica con el repositorio.
- **Unit test projects**:
  `src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj`.
- **Meaningful behaviors**:
  - acepta mínimos y máximos exactos;
  - recorta solo nombre, asunto y mensaje;
  - rechaza vacío, whitespace-only, exceso y correo inválido;
  - múltiples fallos no crean agregado ni invocan persistencia;
  - dos commands idénticos producen IDs distintos;
  - el handler usa un único timestamp y una llamada/commit por intento, hasta tres intentos;
  - consulta devuelve el recurso exacto;
  - identificador inválido/desconocido produce el fallo conocido;
  - JSON con propiedades desconocidas y cuerpos de 8193 bytes se rechazan antes de mediación,
    mientras 8192 bytes atraviesan la política de tamaño;
  - los Problem Details conocidos no repiten valores rechazados ni datos de contacto;
  - excepciones del repositorio no se convierten en éxito.
- **Test ordering**: implementar tests junto con cada unidad; TDD no es obligatorio.
- **xUnit command**:
  `dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build`.
- **Coverlet command/report**: desde la raíz, definir
  `$coverageOutput = Join-Path (Get-Location) 'artifacts\coverage\contact-requests\'` y ejecutar
  `dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build /p:CollectCoverage=true /p:CoverletOutput="$coverageOutput" /p:CoverletOutputFormat=cobertura /p:Threshold=80 /p:ThresholdType=line`.
- **Line coverage threshold**: `>= 80%` para lógica de negocio.
- **Manual acceptance gate**: el operador ejecuta el recorrido reproducible de `quickstart.md`
  (POST válido seguido de GET exacto) y conserva resultado, identificador y timestamps sanitizados;
  esto verifica SC-005 sin convertirlo en una suite de integration tests.
- **Deferred capacity gate**: SC-006/NFR-001 se transfieren a la etapa posterior de performance
  testing; la evidencia futura debe identificar entorno, dataset sintético, 25 usuarios simultáneos,
  10 minutos, mezcla 50/50, cero `5xx` y ausencia de pérdida, mezcla o corrupción. La revisión de diseño de esta V1
  no se presenta como prueba de capacidad.
- **Justified exclusions**: DTOs sin lógica, `Program.cs`, DI, mapping EF, assembly markers,
  bootstrap trivial, código generado y OpenAPI.

No se generan integration tests, performance tests, SAST, DAST ni pruebas artificiales para
elevar coverage.

## Traceability

| Source | Design decision / artifact | Planned evidence |
|---|---|---|
| US1, FR-001, FR-008 | POST → command → factory → repositorio → `201` | OpenAPI POST, unit tests de handler y escenario quickstart 6 |
| US1.2, FR-009, SC-004 | UUID v7 nuevo por cada command, sin deduplicación/idempotencia | Tests con contenido idéntico e IDs distintos |
| US1.3, FR-003–FR-006 | Recorte y límites protegidos en validator y Domain | `data-model.md` y tests de bordes |
| US2, FR-002, FR-007, FR-010 | Validation Problem Details `400`; cero persistencia | OpenAPI `400`, tests de validator/handler y quickstart 8 |
| US3, FR-011–FR-013 | GET exacto; desconocido/malformado → `404` | OpenAPI GET, tests de query y quickstart 7–8 |
| FR-014, NFR-004, NFR-005 | `security: []`; sin auth; solo datos sintéticos/no sensibles | OpenAPI, configuración sin auth y declaración operacional del operador |
| FR-015 | Sin update/delete/notificaciones/adjuntos/clasificación | Ausencia de endpoints, messages y dependencias |
| SC-001–SC-003 | Un solo commit, unicidad PK, lectura exacta y rechazo atómico | Unit tests y quickstart |
| NFR-001, SC-006 | Diseño scoped y sin estado compartido para 25 usuarios | Cobertura diferida: performance QA, gate posterior y reporte de ejecución |
| NFR-002 | Sin suite de performance en V1 | Sección Later SDLC Gates |
| NFR-003 | Problem Details seguro y no divulgación | OpenAPI, handlers y revisión de observabilidad |
| FR-016 | JSON camelCase case-sensitive y propiedades desconocidas rechazadas | JsonOptions, handler del módulo, OpenAPI y tests |
| FR-017 | Tres intentos totales y agotamiento conocido `503` | Handler, repositorio, Problem Details y unit tests |
| FR-018 | Límite técnico de cuerpo 8192 bytes y `413` sin persistencia | Endpoint filter/configuración, OpenAPI y tests de unidad del límite |
| SC-005 | Recorrido POST→GET solo con OpenAPI y quickstart | Evidencia manual sanitizada |
| Constitución IV–V | Minimal APIs, Wolverine mediator, repositorio, EF Core SQL Server, OpenAPI | Reference audit, Redocly exit `0` |
| Constitución VI–VII | xUnit/Coverlet, observabilidad, health y Azure App Configuration | Comandos Local DoD y paths cross-cutting |

## Complexity and Exceptions

No existen desviaciones ni excepciones que requieran aprobación.

## Local Definition of Done

- [ ] Todas las tasks de la feature están completadas con evidencia.
- [ ] `dotnet restore ContactRequests.slnx` es exitoso.
- [ ] `dotnet build ContactRequests.slnx -c Release --no-restore` termina con cero errores y cero
  warnings .NET.
- [ ] Todos los unit tests xUnit pasan.
- [ ] Coverlet demuestra al menos 80% de line coverage sobre lógica de negocio con tests
  significativos.
- [x] `contracts/openapi.yaml` existe para HTTP.
- [x] Redocly CLI `2.41.1` lint finaliza con código cero para el contrato de diseño.
- [ ] OpenAPI coincide con endpoints y errores implementados.
- [ ] El módulo corresponde al límite DDD y contiene Domain/Application/Infrastructure/
  Presentation.
- [ ] Las referencias entre proyectos respetan la dirección autorizada.
- [ ] Repository Pattern, Wolverine mediator y Minimal APIs están respetados.
- [ ] FluentValidation está aplicado donde existe validación.
- [ ] Serilog, OpenTelemetry y HealthChecks cumplen el estándar aplicable.
- [ ] Azure App Configuration está integrado en código y no está marcado `N/A`.
- [ ] No existen secretos hardcoded ni respuestas/logs con información sensible innecesaria.
- [ ] Los errores HTTP usan Problem Details.
- [ ] Los errores conocidos pertenecen a `ContactRequests.Presentation`; el fallback inesperado
  pertenece a `Common.Presentation`, que no referencia `Modules.*`.
- [ ] `speckit.converge` finaliza sin brechas pendientes.

**Evidence commands and locations**:

```powershell
dotnet restore ContactRequests.slnx
dotnet build ContactRequests.slnx -c Release --no-restore
dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build
 $coverageOutput = Join-Path (Get-Location) 'artifacts\coverage\contact-requests\'
dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build `
  /p:CollectCoverage=true `
  /p:CoverletOutput="$coverageOutput" `
  /p:CoverletOutputFormat=cobertura `
  /p:Threshold=80 `
  /p:ThresholdType=line
npx --yes @redocly/cli@2.41.1 lint specs/001-contact-requests/contracts/openapi.yaml
```

Artifacts:

- `artifacts/coverage/contact-requests/coverage.cobertura.xml`
- `specs/001-contact-requests/contracts/openapi.yaml`
- evidencia de tasks en `specs/001-contact-requests/tasks.md` cuando se ejecute la fase
  correspondiente

## Later SDLC Gates — Not Generated Here

Sonar, Veracode, SAST, DAST, performance testing, integration testing, CI/CD, deployment,
provisioning de recursos Azure y versionado o despliegue del esquema físico están fuera de esta
V1. Este plan no crea sus herramientas, pipelines, suites ni tareas de ejecución.
