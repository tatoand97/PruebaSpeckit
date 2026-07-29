# Implementation Plan: Crear y consultar órdenes

**Branch**: `001-create-query-orders` | **Date**: 2026-07-29 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-create-query-orders/spec.md`

**Note**: Este plan aplica la línea base instalada por `dotnet-sdd` sin argumentos técnicos
adicionales.

## Summary

La feature permitirá registrar una orden válida y recuperarla posteriormente por su identificador
exacto. Se implementará en el único límite de dominio identificado, `Orders`, con persistencia
relacional para guardar atómicamente el agregado y sus productos.

La solución seguirá el monolito modular del preset: Minimal APIs delgadas delegan por Wolverine a
handlers de Application, el dominio protege las reglas de la orden y un repositorio implementado en
Infrastructure usa EF Core con SQL Server. El contrato HTTP, los errores Problem Details, la
observabilidad local y los unit tests forman parte de la evidencia del Definition of Done.

## Technical Context

**Language/Version**: .NET 10 SDK 10.0.302 / C# correspondiente a .NET 10

**Compiler Defaults**: Nullable enabled; ImplicitUsings enabled; warnings treated as errors

**Application Type**: Monolito modular ASP.NET Core

**Affected DDD Modules**: Un módulo nuevo `Orders`, responsable exclusivamente de crear y consultar
órdenes; no existen capacidades de clientes o catálogo porque los identificadores son opacos y no
se validan externamente.

**Primary Dependencies**: WolverineFx 6.24.0 como mediator; FluentValidation 12.1.1; EF Core SQL
Server 10.0.10; Serilog.AspNetCore 10.0.0; OpenTelemetry 1.17.0; HealthChecks para EF Core 10.0.10;
dotnet-ef 10.0.10 y Redocly CLI 2.41.1 como tooling reproducible

**Storage**: EF Core 10.0.10 + SQL Server, por la escritura atómica de un agregado con colección
estructurada y la consulta exacta por clave

**External Interfaces**: HTTP con `POST /orders` y `GET /orders/{orderId}`

**Testing**: xUnit 2.9.3 + Coverlet MSBuild 10.0.1, únicamente unit tests

**Target Platform**: ASP.NET Core sobre runtime .NET 10, independiente de Windows o Linux; la PoC se
valida localmente en Windows

**Performance Goals**: Considerar 25 usuarios simultáneos sin ejecutar performance testing en esta
etapa

**Security/Privacy Constraints**: Sin autenticación por alcance; quien conozca el identificador
exacto puede consultar. Las respuestas y la telemetría no exponen secretos, SQL, connection strings,
stack traces ni datos de otras órdenes.

**Scale/Scope**: Primera feature local con dos operaciones, un agregado y sin pagos, inventario,
descuentos, envío, modificación, cancelación o integraciones externas

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
- [x] Los estándares transversales aplicables están considerados.
- [x] El plan no agrega controles o herramientas fuera del alcance V1.

**Gate Result**: PASS antes de research y PASS después del diseño

**Violations requiring explicit approval**: Ninguna

## Architecture Compliance

### DDD Module Boundaries

| Module | Domain capability / bounded context | Existing or new | Why this boundary is real |
|---|---|---|---|
| Orders | Registrar y recuperar órdenes | New | La orden y sus reglas forman la única capacidad de negocio de la feature |

No se crean módulos `Customers`, `Products` o `Persistence`: no existen capacidades propias para
ellos en el alcance y los identificadores externos se tratan como valores opacos.

### Layer Responsibilities

| Module / concern | Domain | Application | Infrastructure | Presentation |
|---|---|---|---|---|
| Orders | Agregado `Order`, productos y reglas de integridad | Commands, queries, handlers, validators, resultados y `IOrderRepository` | `OrdersDbContext`, configuración EF, migración y `OrderRepository` | Minimal APIs, contratos HTTP y mapeo de respuestas |
| Common | Marcadores compartidos mínimos | N/A | Proyecto común disponible sin persistencia concreta compartida | Fallback inesperado con `IExceptionHandler` y registro de observabilidad reutilizable |

### Dependency Direction Check

| Project | Intended references | Evidence / project path | Result |
|---|---|---|---|
| `Orders.Domain` | `Common.Domain` | `Orders/Modules/Orders/Domain/Orders.Domain.csproj` | PASS planned |
| `Orders.Application` | `Orders.Domain` | `Orders/Modules/Orders/Application/Orders.Application.csproj` | PASS planned |
| `Orders.Infrastructure` | `Orders.Application`, `Common.Infrastructure`, `Orders.Domain` | `Orders/Modules/Orders/Infrastructure/Orders.Infrastructure.csproj` | PASS planned |
| `Orders.Presentation` | `Orders.Infrastructure`, `Common.Presentation` | `Orders/Modules/Orders/Presentation/Orders.Presentation.csproj` | PASS planned |
| `Orders.Server` | `Common.Presentation`, `Orders.Presentation` | `Orders/Api/Orders.Server/Orders.Server.csproj` | PASS planned |

Domain no referenciará Application, Infrastructure, Presentation o Api. Application solo verá la
abstracción `IOrderRepository`; Presentation no verá `DbContext` ni invocará handlers directamente.

### Request Flow and Mediation

```text
Minimal API
  -> Orders.Presentation
  -> Wolverine mediator
  -> Orders.Application handler
  -> Orders.Domain
  -> IOrderRepository
  -> Orders.Infrastructure
```

- **Wolverine configuration**: `DurabilityMode.MediatorOnly`
- **Messages and handlers**: `CreateOrderCommand`/`CreateOrderHandler` y
  `GetOrderQuery`/`GetOrderHandler` en `Orders.Application`; la query conserva el texto de ruta
  hasta que FluentValidation comprueba el formato GUID
- **Presentation delegation**: cada endpoint construye un mensaje y usa `IMessageBus.InvokeAsync`;
  no resuelve ni llama handlers directamente
- **Explicitly excluded**: queues, brokers, outbox, inbox, sagas and durable messaging

### Persistence Decision

- **Persistence needed**: Sí; una orden aceptada debe sobrevivir a la solicitud de creación para
  permitir una consulta posterior.
- **Selected option**: EF Core + SQL Server.
- **Requirement-driven rationale**: `Order` es un agregado de estructura estable; crear cabecera y
  productos requiere una única transacción; la consulta es por clave exacta. El modelo relacional
  representa estas reglas sin introducir flexibilidad documental innecesaria.
- **Alternative rejected**: EF Core + MongoDB. No existen documentos variables, consultas
  documentales ni escala que justifiquen elegir el modelo documental.
- **Repository abstractions**: solo `IOrderRepository.AddAsync` y `GetByIdAsync`, utilizados por los
  dos casos de uso.
- **Infrastructure implementations**: `OrderRepository` y `OrdersDbContext` en
  `Orders/Modules/Orders/Infrastructure`.
- **Direct access audit**: los `.csproj` y búsquedas de `DbContext` se comprobarán durante
  implementación y convergencia.

No se agrega generic repository ni una abstracción de Unit of Work separada; `AddAsync` guarda el
agregado en una única unidad transaccional de EF Core.

### Simplicity Review

| Added abstraction or pattern | Requirement / technical need | Simpler option considered |
|---|---|---|
| `IOrderRepository` | Repository Pattern obligatorio y dos casos de uso necesitan persistir/leer el agregado | Acceso directo desde handlers viola Application/Infrastructure |
| Contratos HTTP separados de resultados Application | Evitar acoplar Application a ASP.NET y mantener respuestas explícitas | Exponer tipos HTTP en Application rompe el límite |
| Fallback común + `OrdersExceptionHandler` | Problem Details uniforme sin hacer que Common dependa de excepciones del módulo | Un handler Common para tipos Orders invertiría dependencias; manejo por endpoint duplica política |

No se planean services vacíos, factories, mappers, domain events, wrappers ni value objects
adicionales.

## Project Structure

### Feature Artifacts

```text
specs/001-create-query-orders/
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
Orders/
├── Api/
│   └── Orders.Server/
├── Common/
│   ├── Common.Domain/
│   ├── Common.Infrastructure/
│   └── Common.Presentation/
└── Modules/
    └── Orders/
        ├── Domain/
        ├── Application/
        ├── Infrastructure/
        ├── Presentation/
        └── Tests/
            └── Orders.Test/
```

**Concrete paths touched by this feature**:

```text
global.json
Directory.Build.props
Directory.Packages.props
.gitignore
.config/dotnet-tools.json
Orders.slnx
Orders/Api/Orders.Server/
Orders/Common/Common.Domain/
Orders/Common/Common.Infrastructure/
Orders/Common/Common.Presentation/
Orders/Modules/Orders/Domain/
Orders/Modules/Orders/Application/
Orders/Modules/Orders/Infrastructure/
Orders/Modules/Orders/Presentation/
Orders/Modules/Orders/Tests/Orders.Test/
artifacts/coverage/
```

**Structure Decision**: La capacidad se integra como un único módulo `Orders` con las cuatro capas
obligatorias. Los tres proyectos `Common` materializan la estructura corporativa; solo
`Common.Presentation` contiene comportamiento compartido requerido por esta feature. Un
`Directory.Packages.props` local fija versiones e impide heredar o modificar la administración de
paquetes del repositorio padre.

## API, OpenAPI, and Error Handling

- **Minimal API endpoints**: `POST /orders` y `GET /orders/{orderId}`, propiedad de
  `Orders.Presentation`
- **Wolverine message per endpoint**: `CreateOrderCommand -> OrderResult` y
  `GetOrderQuery -> OrderResult`
- **HTTP request/response contracts**: `CreateOrderRequest`, `CreateOrderItemRequest`,
  `OrderResponse` y `OrderItemResponse` en Presentation
- **OpenAPI artifact**: `specs/001-create-query-orders/contracts/openapi.yaml`
- **Success responses**: `201 Created` con `Location` para crear; `200 OK` para consultar
- **Relevant error responses**: `400` para validación, identificador inválido y producto duplicado;
  `404` para orden inexistente; `500` para error inesperado. `401`, `403` y `409` no aplican porque
  no hay autenticación, autorización, idempotencia ni conflicto aceptado en esta feature.
- **Problem Details**: un fallback común de error inesperado y `OrdersExceptionHandler` del módulo,
  ambos mediante `IExceptionHandler`, más `AddProblemDetails()`; extensión `errors` para validación
  y `traceId` para correlación
- **Validation errors**: FluentValidation valida comandos y queries; una regla de dominio conserva
  la defensa contra productos duplicados antes de persistir
- **Safe diagnostics**: respuestas sin stack trace, SQL, connection strings ni secretos; logs solo
  registran operación, identificador de orden cuando existe y trace
- **Consistency method**: comparación de rutas, métodos, schemas y statuses entre spec, plan,
  OpenAPI y endpoints durante implementación, analyze y converge

## Cross-Cutting Standards

| Concern | Applicability and implementation | Evidence path | Sensitive-data guard |
|---|---|---|---|
| FluentValidation | Aplicable a comandos y query | `Orders/Modules/Orders/Application` | No registrar el cuerpo inválido |
| Serilog | Logging estructurado de consola y request logging | `Orders/Common/Common.Presentation`, `Orders.Server/Program.cs` | Sin cuerpos, secretos o connection strings |
| OpenTelemetry | Instrumentación ASP.NET Core y HttpClient; sin collector externo | `Orders/Common/Common.Presentation` | Sin tags de cliente/producto; cardinalidad limitada |
| HealthChecks | Check del `OrdersDbContext` y endpoint `/health` | `Orders.Infrastructure`, `Orders.Server/Program.cs` | Salida pública solo con estado |
| Azure App Configuration | N/A: no existe estándar/configuración remota previa y agregarla sería una integración externa excluida | `plan.md` | Configuración y secretos se obtienen de variables/configuración local, no se hardcodean |

No se crean collectors, dashboards, recursos Azure ni infraestructura externa.

## Unit Testing and Coverage Strategy

- **Business logic in scope**: `Order`, validación de comandos/query, handlers de creación y consulta
- **Unit test projects**: `Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj`
- **Meaningful behaviors**: creación válida, identificadores opacos no vacíos, cantidad positiva,
  lista vacía, duplicados con producto identificado, solicitudes idénticas con IDs distintos,
  persistencia atómica a nivel de handler, consulta existente e inexistente
- **Test ordering**: implementación de reglas seguida por sus unit tests dentro de la misma fase;
  TDD no se impone
- **xUnit command**:
  `dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj -c Release --no-build`
- **Coverlet command/report**: desde la raíz, definir
  `$coveragePrefix = Join-Path (Get-Location) 'artifacts\coverage\coverage'` y ejecutar
  `dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj -c Release --no-build
  /p:CollectCoverage=true "/p:CoverletOutput=$coveragePrefix" /p:CoverletOutputFormat=json
  /p:Threshold=80 /p:ThresholdType=line /p:ThresholdStat=total`
- **Line coverage threshold**: `>= 80%` para Domain y Application, que son las únicas referencias
  productivas del proyecto de tests
- **Justified exclusions**: contratos sin lógica, `Program.cs`, DI, migrations, configuración EF,
  bootstrap, assembly markers y OpenAPI

No se generan integration, performance, DAST, SAST ni tests para rellenar coverage.

## Traceability

| Source | Design decision / artifact | Planned evidence |
|---|---|---|
| US1, FR-001–FR-008, FR-011, FR-013–FR-014 | `POST /orders`, command, dominio y repositorio | Endpoint, unit tests, OpenAPI 201/400/500 |
| US2, FR-009–FR-013 | `GET /orders/{orderId}`, query y repositorio | Endpoint, unit tests, OpenAPI 200/400/404/500 |
| FR-005–FR-007 | Creación atómica y nuevo GUID por solicitud | Domain/Application tests y `OrderRepository` |
| FR-015 | Un solo módulo y ninguna capacidad excluida | Árbol de código y revisión de tasks |
| NFR-001 | Diseño stateless por request y `DbContext` scoped para 25 usuarios | Configuración; performance testing explícitamente posterior |
| NFR-002 | Problem Details seguro y telemetría sin datos sensibles | Exception handler, Serilog y OpenTelemetry |
| NFR-003 | Ausencia de performance suites/tasks | tasks.md y árbol final |
| Constitution II–VII | Estructura, referencias, stack y DoD | `.csproj`, comandos locales, coverage y converge |

## Complexity and Exceptions

No existen desviaciones ni excepciones aprobadas. La estructura de proyectos es obligatoria por la
Constitution y no representa una excepción.

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

**Evidence commands and locations**: `dotnet tool restore`; `dotnet restore Orders.slnx`;
`dotnet build Orders.slnx -c Release --no-restore`; los comandos de test/coverage anteriores;
`npx --yes @redocly/cli@2.41.1 lint specs/001-create-query-orders/contracts/openapi.yaml`;
`specs/001-create-query-orders/contracts/openapi.yaml`; `.csproj`; y el resultado de converge.

## Later SDLC Gates — Not Generated Here

Sonar, Veracode, SAST, DAST, performance testing, integration testing, CI/CD y deployment están
fuera de esta V1. Pueden existir como requisitos o gates organizacionales posteriores, pero este
plan no crea sus herramientas, pipelines, suites ni tareas de ejecución.
