# Implementation Plan: Creación y consulta de órdenes

**Branch**: `001-create-query-orders` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-create-query-orders/spec.md`

## Summary

La feature se expondrá como una API HTTP JSON de ASP.NET Core 10 mediante Minimal APIs. Un único
proyecto desplegable validará las solicitudes, ejecutará SQL parametrizado directamente contra un
archivo SQLite local y devolverá contratos explícitos basados en Problem Details. La creación de la
orden y todos sus elementos se confirmará en una sola transacción; la clave primaria de SQLite será
la salvaguarda definitiva contra identificadores duplicados.

El diseño mantiene una sola unidad de despliegue y un solo proyecto de pruebas. No introduce
Controllers, ORM, capas arquitectónicas, CQRS, MediatR, Repository, Unit of Work, AutoMapper ni un
framework externo de validación.

## Technical Context

**Language/Version**: .NET 10 LTS, SDK `10.0.302`, C# 14

**Primary Dependencies**:

- ASP.NET Core desde el shared framework `Microsoft.AspNetCore.App`, sin paquete NuGet directo.
- `Microsoft.Data.Sqlite` `10.0.10`: única dependencia directa de runtime; aporta el proveedor
  ADO.NET y SQLite embebido necesarios para persistencia durable y transaccional.
- `MSTest` `4.3.2` y `Microsoft.AspNetCore.Mvc.Testing` `10.0.10`, sólo en pruebas; aportan el
  framework/runner/analyzers de pruebas y `WebApplicationFactory`/`TestServer`.

**Storage**: un archivo SQLite configurable en almacenamiento local persistente, con tablas
`orders` y `order_items`, claves y restricciones declarativas, foreign keys habilitadas y modo WAL.
No se usa Entity Framework ni un servidor de base de datos.

**Testing**: un proyecto MSTest con pruebas unitarias de validación y pruebas de integración/contrato
contra Minimal API y un archivo SQLite temporal real. Incluye categorías para aceptación,
atomicidad, concurrencia y carga de 25 usuarios. Comandos: `dotnet build`, `dotnet test` y el futuro
script reproducible `scripts/verify.ps1`.

**Target Platform**: proceso ASP.NET Core único sobre un sistema operativo soportado por .NET 10,
con filesystem local que permita escribir el archivo SQLite. Despliegue de PoC en entorno controlado.

**Project Type**: servicio web HTTP JSON sin frontend.

**Performance Goals**: hasta 25 usuarios simultáneos; al menos el 95 % de creaciones y consultas
debe completar en menos de 2 segundos.

**Constraints**: toda creación es atómica; las cantidades se representan exactamente como enteros
con signo de 64 bits y se rechazan si no pueden representarse sin pérdida; no se normalizan los
identificadores; no hay máximos de negocio para elementos o cantidades; no hay autenticación,
integraciones externas ni escalado horizontal en alcance.

**Scale/Scope**: dos operaciones (`POST /orders`, `GET /orders/{orderId}`), dos entidades
persistentes, una instancia de aplicación, un archivo de datos y 25 usuarios simultáneos.

**Security**: toda entrada se valida en el límite HTTP y todo SQL es parametrizado. La API no
implementa autenticación por mandato de la especificación y se limita a red/entorno controlado con
datos sintéticos o no sensibles. No se registran cuerpos, identificadores de cliente/producto ni el
identificador de orden, que se trata como capacidad de consulta. Errores 5xx no exponen excepciones
ni detalles de SQLite. No existen secretos requeridos por la feature; la aplicación y el directorio
de datos operan con permisos mínimos.

**Observability**: logging estructurado JSON mediante `ILogger` y el proveedor de consola nativo.
Cada solicitud registra nombre de operación, resultado, código HTTP, duración y `traceId`, pero no
la ruta cruda ni datos de la orden. No se añade exportador de métricas: el harness de carga mide
conteos, errores y percentil 95, y no existen servicios downstream que justifiquen trazabilidad
distribuida. El `traceId` nativo permite correlacionar problemas y respuestas.

**Automation**: `global.json` fijará SDK `10.0.302`; restore bloqueado mediante lock files; build
Release con warnings como errores; pruebas categorizadas y script PowerShell `scripts/verify.ps1`
que termina con código distinto de cero ante cualquier fallo. Estos archivos se crearán en fases
posteriores, no durante este plan.

## Constitution Check — Initial (before Phase 0)

| Principle | Result | Evidence before research |
|---|---|---|
| Specification First | PASS | `spec.md` contiene alcance, 21 requisitos funcionales, seguridad, aceptación y criterios medibles; la única corrección previa fue la definición de Cliente autorizada por el usuario. |
| Simplicity and Justified Architecture | PASS | El punto de partida fue una unidad desplegable y capacidades nativas; toda tecnología adicional quedó como pregunta de research, no como supuesto. |
| .NET Engineering Standards | PASS | El baseline solicitado y constitucional es .NET 10; el research debe fijar un servicing level soportado y preferir BCL/shared framework. Nullable permanecerá habilitado. |
| Testing and Quality | PASS | La especificación ofrece escenarios verificables, incluida atomicidad, concurrencia y carga; el plan debe convertirlos en pruebas automatizadas. |
| Security by Design | PASS | `SR-001`–`SR-007` definen límite de confianza, ausencia deliberada de auth, datos no sensibles y prohibiciones de logging. |
| Observability and Operability | PASS | La Constitution exige decidir logs, métricas y trazas proporcionalmente durante research; no hay proveedor preseleccionado. |
| Automation and Reproducibility | PASS | Build/test/ejecución reproducibles son salida obligatoria; PowerShell es el estándar del repositorio. |
| AI-Assisted Development | PASS | La planificación es single-agent y no usa MCP, Context7, Codebase Memory ni agentes adicionales. |

**Initial gate**: PASS. No hay violaciones ni aclaraciones que bloqueen Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-create-query-orders/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── checklists/
    └── requirements.md
```

No se crea `tasks.md`; corresponde exclusivamente a `/speckit-tasks`, fuera de este encargo.

### Proposed source code (repository root)

```text
Orders.slnx
global.json
Directory.Build.props
Directory.Packages.props
src/
└── Orders.Api/
    ├── Orders.Api.csproj
    ├── packages.lock.json
    ├── Program.cs
    ├── OrderModels.cs
    ├── OrderContracts.cs
    ├── OrderValidator.cs
    ├── SqliteOrderStore.cs
    └── appsettings.json
tests/
└── Orders.Api.Tests/
    ├── Orders.Api.Tests.csproj
    ├── packages.lock.json
    ├── ValidationTests.cs
    ├── ApiContractTests.cs
    ├── PersistenceTests.cs
    ├── AtomicityTests.cs
    ├── ConcurrencyTests.cs
    └── LoadTests.cs
scripts/
└── verify.ps1
```

**Structure Decision**: una solución `.slnx` —formato predeterminado de .NET 10— con un proyecto
web y un proyecto de pruebas. Los archivos dentro del proyecto web separan responsabilidades
concretas, pero no forman capas ni proyectos independientes. Las pruebas unitarias y de integración
comparten proyecto porque la escala de la PoC no justifica un tercer proyecto. La estructura es
propuesta: esta fase no crea `.slnx`, `.csproj`, código ni scripts.

## Design

### Request flow

1. ASP.NET Core recibe JSON y conserva los identificadores exactamente como fueron enviados.
2. `OrderValidator` recorre toda la solicitud y acumula los errores semánticos detectables.
3. Si hay errores, el endpoint devuelve `400` con `ValidationProblemDetails`; no abre una
   transacción.
4. Si es válida, `SqliteOrderStore` obtiene el gate de escritura, genera un GUID v4 y abre una
   conexión y transacción propias.
5. Inserta la orden `Pending` y todos sus elementos mediante SQL parametrizado.
6. Confirma la transacción antes de devolver `201`. Una violación de clave de orden provoca la
   generación de otro GUID y reintenta; cualquier otro fallo revierte todo.
7. La consulta usa el identificador recibido como texto opaco. Vacío/blanco es `400`; cualquier
   valor no vacío sin coincidencia exacta es `404`, aunque no tenga forma de GUID.

### Persistence and concurrency

- `orders.order_id` es `TEXT PRIMARY KEY COLLATE BINARY`.
- `order_items` tiene clave primaria compuesta `(order_id, product_id)` y foreign key a `orders`.
- La validación de negocio ocurre antes de escribir y las restricciones de SQLite actúan como
  defensa adicional.
- SQLite opera en WAL. Cada operación crea su propia conexión; nunca se comparten objetos ADO.NET
  entre hilos.
- Un `SemaphoreSlim` nativo serializa las breves transacciones de creación dentro de la única
  instancia. Las consultas no toman ese gate y pueden convivir con el escritor en WAL.
- No se usan APIs async de `Microsoft.Data.Sqlite`, porque SQLite no ofrece I/O asíncrono real. El
  único wait asíncrono es el del gate de escritura.
- El timeout operativo se mantiene por debajo del objetivo de 2 segundos. Saturación o bloqueo
  devuelve `503` sin datos parciales; el harness con 25 usuarios debe demostrar que el caso objetivo
  no llega a ese estado.

### Validation and errors

- Validación manual, determinista y sin dependencias: `string.IsNullOrWhiteSpace`, colección no
  vacía, cantidad `Int64 > 0` y productos únicos mediante comparación ordinal exacta.
- No hay trim, cambio de mayúsculas, normalización Unicode, redondeo ni consolidación de productos.
- Errores de binding/JSON, semánticos, duplicados, identificador de consulta inválido, ausencia y
  fallo operativo usan el formato observable definido en
  [contracts/openapi.yaml](./contracts/openapi.yaml).
- `ProblemDetails` y `ValidationProblemDetails` proceden de ASP.NET Core. `traceId` se expone; nunca
  se exponen stack traces, SQL, rutas físicas ni contenido de otras órdenes.

### Dependencies and rejected complexity

| Dependency/pattern | Decision | Justification |
|---|---|---|
| ASP.NET Core Minimal APIs | Use shared framework | Dos endpoints HTTP no necesitan Controllers ni framework adicional. |
| `Microsoft.Data.Sqlite` 10.0.10 | Add runtime package | La BCL no incluye un almacén embebido durable con transacciones y restricciones. |
| MSTest 4.3.2 | Add test-only package | .NET no incluye por sí solo framework, runner y analyzers de pruebas. |
| `Microsoft.AspNetCore.Mvc.Testing` 10.0.10 | Add test-only package | Prueba el pipeline HTTP real en proceso sin scripts de lifecycle propios. |
| OpenAPI runtime generation | Reject | El contrato estático basta para dos endpoints; añadir `Microsoft.AspNetCore.OpenApi` no mejora el requisito. |
| EF Core / Repository / Unit of Work | Reject | SQL directo y una transacción cubren las dos operaciones y dos tablas. |
| Controllers / CQRS / MediatR / service layer | Reject | No existe complejidad de routing, orquestación ni reutilización que los justifique. |
| FluentValidation / AutoMapper | Reject | Las reglas y mapeos caben en código directo, auditable y nativo. |
| Docker / servidor SQL / cache | Reject | Añaden infraestructura sin requisito de despliegue distribuido o volumen que la necesite. |

## Constitution Check — Post-design (after Phase 1)

| Principle | Result | Evidence after design |
|---|---|---|
| Specification First | PASS | Modelo y contrato trazan únicamente `Order`, `OrderItem`, creación, consulta y errores de `spec.md`; no se agregan capacidades de negocio. |
| Simplicity and Justified Architecture | PASS | Un proyecto web, uno de pruebas, una dependencia runtime y SQL directo. Cada separación y paquete tiene justificación concreta. |
| .NET Engineering Standards | PASS | .NET 10.0.302/C# 14 y paquetes estables vigentes; capacidades nativas para HTTP, JSON, DI, logging, GUID, validación simple y errores. Nullable y warnings-as-errors quedan exigidos. |
| Testing and Quality | PASS | Quickstart y plan cubren validación, contrato, persistencia, atomicidad, unicidad concurrente, p95 con 25 usuarios y el protocolo humano de SC-005. |
| Security by Design | PASS | Entradas y SQL se validan/parametrizan; no hay auth por alcance explícito; entorno controlado, mínimo privilegio y no logging de identificadores/contenido. |
| Observability and Operability | PASS | Logs JSON estructurados, duración/resultado/traceId y tratamiento seguro de fallos; métricas exportadas y tracing distribuido se descartan con justificación proporcional. |
| Automation and Reproducibility | PASS | SDK y paquetes fijados, restore bloqueado, build/test documentados y script PowerShell propuesto con failure code. |
| AI-Assisted Development | PASS | Phase 0 y Phase 1 se ejecutaron secuencialmente por un solo agente, sin herramientas/agentes adicionales. |

**Final gate**: PASS. No hay violaciones constitucionales ni elementos en Complexity Tracking.

## Specification Gaps and Clarifications

- **Specification gaps**: ninguno descubierto. La comparación ordinal exacta se deriva de tratar los
  identificadores como opacos y conservarlos sin alteración; un valor de consulta no vacío pero no
  generado por el sistema se trata como no encontrado conforme a FR-018/FR-019.
- **Pending clarifications**: ninguna.
- **Environment note**: el host actual tiene SDK `10.0.203` y runtime `10.0.7`; la implementación y
  verificación deberán ejecutarse con el servicing vigente planificado (`10.0.302`/runtime
  `10.0.10`). No se instaló ni actualizó software durante esta fase.
