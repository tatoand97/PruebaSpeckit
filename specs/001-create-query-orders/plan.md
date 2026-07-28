# Implementation Plan: Creación y consulta de órdenes

**Active Git branch**: `main` | **Feature ID**: `001-create-query-orders` | **Date**: 2026-07-28 |
**Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-create-query-orders/spec.md` plus the approved
remediation decisions for [checklists/pre-tasks.md](./checklists/pre-tasks.md).

## Summary

La feature tiene dos capacidades de negocio —crear una orden y consultarla por identificador— y
tres operaciones HTTP: `POST /orders`, `GET /orders/{orderId}` y `GET /orders`. La tercera nunca
lista órdenes; sólo convierte la ausencia del identificador en `400`.

La implementación propuesta sigue siendo una ASP.NET Core 10 Minimal API, un archivo SQLite
persistente y SQL parametrizado directo. Las creaciones se validan por completo, esperan un gate
de escritor durante un máximo de 1 segundo y escriben `orders` y `order_items` en una sola
transacción. SQLite aplica un `busy_timeout` de 500 ms. Sólo un commit completado permite intentar
la respuesta `201`; todo `503` de creación garantiza que no hubo commit.

El diseño mantiene una unidad desplegable y un proyecto de pruebas. No introduce Controllers, ORM,
capas arquitectónicas, idempotency keys, rate limiting, cache, colas ni escalamiento horizontal.

## Technical Context

**Language/Version**: .NET 10 LTS, SDK `10.0.302`, C# 14.

**Primary Dependencies**:

- ASP.NET Core desde `Microsoft.AspNetCore.App`, sin paquete NuGet directo, para Minimal APIs,
  Kestrel, `System.Text.Json`, Problem Details, DI y logging.
- `Microsoft.Data.Sqlite` `10.0.10`, única dependencia directa de runtime, para SQLite.
- `MSTest` `4.3.2` y `Microsoft.AspNetCore.Mvc.Testing` `10.0.10`, sólo en pruebas.

**Storage**: un archivo SQLite configurable en almacenamiento local persistente, junto con sus
archivos WAL auxiliares cuando existan. Tablas `orders` y `order_items` en modo `STRICT`,
`foreign_keys=ON`, WAL, `synchronous=FULL`, transacciones `BEGIN IMMEDIATE`, esquema v1 validado al
inicio y `busy_timeout=500` ms.

**Testing**: MSTest con pruebas unitarias de validación; integración/contrato contra Minimal API y
SQLite real; atomicidad; colisiones UUID; concurrencia; clasificación de errores; seguridad de
logs; reinicio del proceso; límites de Kestrel; y carga reproducible con 25 usuarios. Las fronteras
de persistencia/respuesta se controlan mediante delegates internos no-op accesibles sólo a
`Orders.Api.Tests` con `InternalsVisibleTo`. Comandos: `dotnet restore`, `dotnet build`,
`dotnet test` y el futuro `scripts/verify.ps1`.

**Target Platform**: una sola instancia ASP.NET Core en loopback local o red de desarrollo aislada,
con filesystem persistente escribible. No se admite exposición pública.

**Project Type**: servicio web HTTP JSON sin frontend.

**Performance Goals**: con el protocolo de carga de 500 operaciones medidas y 25 usuarios virtuales,
p95 end-to-end de operaciones exitosas estrictamente menor que 2 segundos, cero `503` y cero
errores inesperados durante la carga objetivo.

**Constraints**: body máximo de `POST /orders` de 1 MiB; writer gate de 1 segundo;
`busy_timeout=500` ms; cantidades JSON enteras en rango `Int64`; identificadores sin normalización;
sin máximos de negocio para items o cantidades; sin idempotencia; sin autenticación; sin
integraciones externas; sin rate limiting; sin escalado horizontal.

**Scale/Scope**: dos capacidades, tres operaciones HTTP, dos entidades persistentes, una instancia,
un archivo de datos y 25 usuarios concurrentes. `GET /orders` nunca enumera.

**Security**: todo input se valida en el límite HTTP; SQL siempre parametrizado. La API sin auth se
restringe a loopback/red aislada, datos sintéticos o clasificados como no sensibles y ausencia de
credenciales reales. No se exige TLS en loopback; cualquier otra exposición requiere un diseño de
auth/authz y revisión de seguridad. Kestrel limita el body. No se registran datos de órdenes ni
detalles de almacenamiento.

**Observability**: formatter JSON console nativo, configurado con salida de una línea, timestamp UTC
explícito y scopes deshabilitados. Su envelope nativo se distingue del `State` aplicativo, cuyo
vocabulario cerrado contiene operación lógica, status HTTP, resultado, duración en milisegundos,
`traceId` y categoría segura. No se añaden formatter propio, backend de métricas ni tracing
distribuido; se reconsideran con múltiples instancias, downstream services, SLO u operación
on-call.

**Automation**: `global.json` fijará el SDK; NuGet usará lock files; Release tratará warnings como
errores; `scripts/verify.ps1` ejecutará locked restore, Release build, validación de lock files y
las categorías unitarias, integración, contrato, persistencia/atomicidad, restart, concurrencia,
Kestrel host-boundary, logging/security y performance. Propagará códigos de fallo. Estos artefactos
se crearán después, no en `/speckit-plan`.

## Constitution Check — Initial (before remediation)

Los principios constitucionales no exigían ampliar el alcance, pero el checklist detectó
indeterminación material en contrato, concurrencia, fallos, rendimiento, seguridad y
observabilidad. Por ello, el gate inicial quedó **REMEDIATION REQUIRED** y `/speckit-tasks`
permaneció bloqueado hasta actualizar Phase 0/Phase 1.

| Principle | Initial assessment | Remediation required |
|---|---|---|
| Specification First | Source of truth available | Propagar las decisiones aprobadas a spec, plan, research, model, contract y quickstart. |
| Simplicity and Justified Architecture | Architecture remained small | Precisar límites sin agregar capas, auth, idempotencia, rate limiting ni infraestructura. |
| .NET Engineering Standards | Baseline selected | Confirmar comportamiento nativo de JSON, Problem Details y SQLite. |
| Testing and Quality | Scenarios existed | Hacer reproducibles SC-002 y SC-005 y cubrir fronteras de fallo. |
| Security by Design | Intent existed | Definir entorno controlado, límite de body, errores y datos permitidos/prohibidos. |
| Observability and Operability | Structured logging selected | Cerrar el contrato de eventos/campos y justificar métricas/tracing ausentes. |
| Automation and Reproducibility | Commands proposed | Determinar fixtures, reinicios y protocolo de carga. |
| AI-Assisted Development | Compliant | Mantener ejecución secuencial sin subagentes ni herramientas nuevas. |

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
    ├── requirements.md
    └── pre-tasks.md
```

No se crea `tasks.md`; corresponde exclusivamente a `/speckit-tasks`.

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
    ├── RestartTests.cs
    ├── LoggingTests.cs
    └── LoadTests.cs
scripts/
└── verify.ps1
```

**Structure Decision**: una solución `.slnx`, un proyecto web y un proyecto de pruebas. Los archivos
del proyecto web separan routing/contrato, validación y acceso SQLite como responsabilidades
concretas, no como capas o proyectos independientes.

## Design

### Capabilities and HTTP operations

| Business capability | HTTP operation | Normative purpose |
|---|---|---|
| Crear una orden | `POST /orders` | Validar, confirmar exactamente una orden y devolver `201`. |
| Consultar por identificador | `GET /orders/{orderId}` | Recuperar una coincidencia exacta o devolver `400`/`404`. |
| Sin capacidad adicional | `GET /orders` | Representar identificador ausente con `400`; nunca listar ni buscar. |

### Create request flow

1. Kestrel aplica `MaxRequestBodySize=1_048_576` bytes antes de deserializar. No hay middleware de
   descompresión; el límite se mide sobre los bytes del body HTTP que Kestrel entrega tras remover
   el framing de transferencia.
2. La aplicación exige `Content-Type: application/json` con parámetros opcionales. Ausencia u otro
   media type produce `415` Problem Details antes de leer el body. Por tanto, body y Content-Type
   ambos ausentes producen `415`; body ausente con Content-Type correcto produce `400`.
3. `System.Text.Json` deserializa un DTO anulable. Con Content-Type correcto, body ausente, vacío,
   `null`, malformado, tipos incompatibles, propiedad JSON repetida y número no representable como
   `Int64` producen `400` `invalid-body`. Propiedades desconocidas se ignoran deliberadamente y no
   se conservan.
4. `OrderValidator` acumula todas las infracciones semánticas detectables del DTO: requeridos,
   whitespace, colección, elementos nulos, cantidades y duplicados ordinales.
5. Una solicitud semánticamente inválida devuelve `400` y no abre conexión ni transacción.
6. La operación espera `SemaphoreSlim(1,1)` hasta 1 segundo. Timeout o cancelación antes de
   adquirirlo no inicia transacción; el timeout devuelve `503`.
7. Con el gate adquirido, abre una conexión propia, aplica/valida los pragmas de conexión e inicia
   una transacción inmediata. Inserta `orders` y todos los `order_items`.
8. Genera UUID v4 en formato canónico `D`. Si la primary key detecta colisión, hace rollback y
   repite con UUID nuevo, con máximo de tres intentos totales. Agotar los intentos devuelve `500`
   genérico; nunca registra ni revela los UUID.
9. Hace commit. Sólo después construye `201`, body y `Location: /orders/{orderId}`. No existe retry
   general de SQLite.
10. Libera el gate en `finally`. Una desconexión después del commit no revierte la orden.

### Query request flow and routing boundary

- `GET /orders` —incluido el trailing slash equivalente que el router asocie a esa plantilla—
  devuelve `400` `missing-order-id` y nunca accede a una enumeración.
- El cliente soportado usa exactamente el `Location` ASCII generado por `POST`; el UUID canónico no
  necesita percent-encoding ni contiene slash, Unicode o whitespace.
- Si un valor de ruta llega a `GET /orders/{orderId}`, ASP.NET Core entrega el route value
  procesado. Vacío/blanco es `400`; cualquier otro valor se compara de forma ordinal/binaria y
  devuelve `200` sólo si coincide o `404` si no.
- Unicode no blanco que llegue al handler es simplemente un valor opaco no encontrado. Encodings
  inválidos, slash codificado, segmentos extra y solicitudes que el host/router no asigne a la
  operación quedan fuera del contrato de esta operación y pueden terminar en rechazo/404 del host
  sin Problem Details garantizado.
- Cada consulta abre una conexión propia, no adquiere el writer gate y nunca enumera.

### JSON policy

| Input case | Result | Semantic validation |
|---|---|---|
| Body absent, empty or top-level `null` with supported Content-Type | `400 invalid-body` | Not run |
| Malformed/truncated JSON | `400 invalid-body` | Not run |
| Missing or `null` `customerId`, `items`, `productId`, `quantity` | DTO nullable; `400 validation` | All detectable rules accumulated |
| `items: null` or empty | `400 validation` | Collection rule plus other available fields |
| Null array element | `400 validation` keyed by index | Other elements still validated |
| Wrong JSON type | `400 invalid-body` | Not run |
| Int64 overflow, fraction or exponent notation | `400 invalid-body` | Not run |
| Unknown property | Ignored by standard serializer | Known fields still validated; unknown data is not stored |
| Repeated JSON property name | `400 invalid-body` using .NET 10 `AllowDuplicateProperties=false` | Not run |
| Content-Type absent/unsupported (takes precedence over body parsing) | `415 unsupported-media-type` | Body not read |

Serializer configuration remains native: camel-case output, case-sensitive input property names,
strict numeric handling, `AllowDuplicateProperties=false`, unmapped members skipped and no custom
JSON converter/parser.

### Semantic validation

- `customerId` and `productId` use `string.IsNullOrWhiteSpace`.
- Identifiers that pass are preserved byte-for-byte at the UTF-8/UTF-16 value level; no trim,
  case-folding or Unicode normalization.
- `quantity` must be present and `> 0` after strict `Int64` deserialization.
- Duplicates compare only usable product IDs with `StringComparer.Ordinal`.
- Case, leading/trailing/internal whitespace and distinct Unicode sequences remain distinct.
- For each duplicate occurrence after the first, the error key is
  `items[n].productId` and the safe message references the index of the first occurrence, never the
  submitted product ID. Tres repeticiones generan errores para la segunda y tercera; varios grupos
  generan un error por cada ocurrencia posterior. IDs nulos/inválidos no participan en duplicate
  detection, pero conservan su propio error.
- El orden de `items` se conserva cuando resulte práctico, pero no tiene semántica ni forma parte
  del contrato de igualdad.

### Normative response matrix

| Operation | Success | Application errors | Host/pipeline boundary |
|---|---|---|---|
| `POST /orders` | `201 application/json` | `400`, `415`, `500`, `503` as `application/problem+json` | `413`; body/media type not guaranteed |
| `GET /orders` | none | `400`, `500` as `application/problem+json` | `405`, server timeout/disconnect outside app contract |
| `GET /orders/{orderId}` | `200 application/json` | `400`, `404`, `500`, `503` as `application/problem+json` | `405`, routing rejection, server timeout/disconnect outside app contract |

`405`, host timeouts, malformed HTTP, disconnects and failures before the application pipeline are
not part of the Problem Details guarantee. Handlers create their known problems directly; a
minimal standard exception handler converts only otherwise-unhandled application exceptions to
safe `500` Problem Details. Status-code-pages middleware is not enabled, so no middleware is added
solely to homogenize `405` or routing/host failures. `Retry-After` is absent because no reliable
retry interval is known.

### Application Problem Details catalog

Every application-produced problem has closed fields
`type`, `title`, `status`, `detail`, `instance`, `traceId`; validation problems also have `errors`.
`instance` is the logical route template (`/orders` or `/orders/{orderId}`), never a raw path with
an identifier.

| Status | Type | Title | Stable detail | Error keys |
|---:|---|---|---|---|
| 400 | `urn:orders:problem:invalid-body` | El cuerpo JSON no es válido. | El body debe ser un objeto JSON válido con los tipos declarados. | `body` |
| 400 | `urn:orders:problem:validation` | La solicitud no es válida. | Se detectaron errores de validación semántica. | `customerId`, `items`, `items[n]`, `items[n].productId`, `items[n].quantity` |
| 400 | `urn:orders:problem:missing-order-id` | Falta el identificador de orden. | Use la ruta Location devuelta al crear la orden. | `orderId` |
| 404 | `urn:orders:problem:not-found` | Orden no encontrada. | No existe una orden asociada al identificador proporcionado. | none |
| 415 | `urn:orders:problem:unsupported-media-type` | Content-Type no soportado. | Use application/json. | none |
| 500 | `urn:orders:problem:internal` | Error interno. | La operación no pudo completarse. | none |
| 503 | `urn:orders:problem:temporarily-unavailable` | Servicio temporalmente no disponible. | La operación no pudo completarse temporalmente. | none |

Mensajes no reflejan IDs, JSON, SQL, rutas físicas ni excepciones. El `traceId` coincide exactamente
con el campo del evento operacional seguro.

### Persistence, durability and schema

| Decision | Exact behavior and responsibility |
|---|---|
| Persistent storage | Database path is configuration. Main DB and active WAL files reside on the same persistent volume. Preserving that storage preserves committed orders across process/host restarts. Environment recreation or storage loss is out of scope. |
| Initialization | Startup creates schema v1 transactionally if absent; validates `user_version=1`, required tables, `PRAGMA quick_check` and empty `foreign_key_check`. Unknown/incompatible schema or corruption fails startup. |
| Foreign keys | `Foreign Keys=True`/`PRAGMA foreign_keys=ON` on every connection. |
| Journal | Startup sets and verifies `journal_mode=WAL`; no shared-cache mode. |
| Durability | `synchronous=FULL`; `201` follows successful commit. |
| Types | Both tables are `STRICT`; identifiers use `TEXT COLLATE BINARY`, quantity uses `INTEGER`. |
| Isolation | Writers use `BEGIN IMMEDIATE`; readers use SQLite's committed snapshot semantics. |
| Busy handling | `PRAGMA busy_timeout=500`; no general retry loop. |
| Connections | Exactly one non-shared connection per HTTP operation. |

### Atomicity and result boundaries

| Boundary/failure | Persisted result | HTTP classification when a response remains possible |
|---|---|---|
| Body/content/semantic validation | No connection or transaction | `400`/`415`; host may produce `413` |
| Gate timeout at 1 s | No transaction, no commit | `503` |
| Cancellation/disconnect before gate or transaction | No commit | Response may be impossible |
| Open or `BEGIN IMMEDIATE` temporary busy/unavailable | No commit | `503` only when no commit is certain |
| Permanent permission/path/schema/corruption failure | No commit at startup or current operation | Startup fails; otherwise generic `500` |
| Order/item insert or constraint failure | Rollback entire attempt | Collision may retry; otherwise generic `500` |
| UUID collision attempts 1–2 | Rollback, generate new UUID | No response yet |
| UUID collision attempt 3 | Rollback, no confirmed order | Generic `500` |
| Commit succeeds | Complete order visible | Application may attempt `201` |
| Commit throws or its outcome cannot be proved | Never classify as `503`; outcome is uncertain | Generic `500` if writable, otherwise disconnect |
| HTTP connection/serialization fails after commit | Confirmed order may exist; no rollback | Client has uncertain outcome |

No idempotency key is introduced. Retrying after a proven pre-commit `503` cannot duplicate that
failed attempt, but it creates a new order if the retry succeeds. Retrying after `500`, timeout or
disconnect with uncertain outcome can create a second order.

### Minimal deterministic test seams

La testabilidad de las fronteras anteriores se limita a delegates internos dentro de los archivos
ya aprobados. No se agregan capas, Repository Pattern, Unit of Work, framework de mocks/fault
injection, paquetes, proyectos ni delays arbitrarios.

`SqliteOrderStore.cs` contiene hooks internos con delegate production-default no-op en exactamente
estas fronteras:

1. antes de `BEGIN IMMEDIATE`;
2. después de insertar la fila `orders`;
3. después de insertar todas las filas `order_items`;
4. antes de commit;
5. después de que commit retornó correctamente.

Los delegates pueden bloquear con `Barrier`, `ManualResetEventSlim` u otra primitiva nativa, o
lanzar el fallo determinado por la prueba. No cambian el flujo normal, no forman parte del contrato
público y sólo `Orders.Api.Tests` puede configurarlos mediante `InternalsVisibleTo`; el generador
UUID sustituible puede vivir en el mismo contenedor interno o mantenerse separado. Cada prueba
restaura los defaults no-op al terminar para evitar estado cruzado.

`Program.cs` contiene un único delegate interno adicional, también no-op por defecto, invocado
después de recibir la confirmación de commit de `SqliteOrderStore` y antes de construir/escribir la
respuesta HTTP. Este seam permite provocar determinísticamente un fallo post-commit y demostrar
que la orden permanece confirmada, no hay rollback, el resultado nunca se clasifica como `503` y
el cliente puede quedar con resultado incierto. No simula indisponibilidad mediante espera
temporal.

### Concurrency guarantees and budgets

- `SemaphoreSlim`: serializes only writers inside the single process and bounds gate wait to 1
  second. It has no FIFO/fairness guarantee and no separate fixed queue capacity; a waiter that
  loses scheduling for 1 second receives `503`. This starvation risk is accepted for the bounded
  25-user controlled PoC.
- SQLite: provides interprocess file locking, atomic commit/rollback, primary-key uniqueness,
  foreign keys and reader isolation. These protections remain if another process accidentally
  opens the file, but multi-process/horizontal operation is unsupported and not load-tested.
- Readers never take the gate. A read whose SQLite snapshot precedes commit cannot observe the new
  order and may return `404`; it cannot observe only `orders` or a subset of `order_items`. Reads
  beginning after commit can retrieve the complete order. A pre-commit `404` does not predict the
  later result of a concurrent creation.
- Operational budget for a target request: up to 1.000 ms gate wait + up to 500 ms SQLite busy wait
  + 500 ms margin for parse, validation, local SQL, commit and response, aiming at `< 2 s`. There is
  no separate transaction retry or application-wide server timeout: forcibly timing out a
  synchronous commit could make outcome classification dishonest. The load client uses 5 seconds
  only as a harness fail-safe; any successful operation at or above 2 seconds already fails SC-005.

### 503 taxonomy

`503` is limited to temporary operational unavailability known before commit:

- writer gate not acquired within 1 second;
- SQLite remains busy/locked after the 500 ms busy budget;
- storage is temporarily unavailable and the application can prove no commit occurred.

Permanent configuration, schema, corruption, invariant and unexpected failures are `500` generic.
Ambiguous commit outcomes are never `503`. No `Retry-After` is emitted.

### Controlled environment, abuse protection and data handling

- Supported: local loopback or isolated development network, single instance, synthetic or
  pre-classified non-sensitive data, no real credentials.
- Unsupported: public Internet, shared/untrusted network or production data. The operator owns the
  binding/firewall boundary. Any expansion requires auth, authz, TLS/network review and threat
  review.
- HTTP without TLS is allowed only on loopback. A controlled non-loopback network decides TLS at
  its boundary; public exposure is prohibited.
- No rate limiting is implemented because the PoC is isolated and acceptance is capped at 25
  users. Reevaluate before any uncontrolled exposure or materially higher load.
- The request body limit and writer timeout are protective operational limits, not business
  maxima. No input is truncated.

### Logging contract

Se usa exclusivamente el formatter JSON nativo de
`Microsoft.Extensions.Logging.Console`; no se implementa un formatter propio. La configuración
explícita selecciona JSON console, `JsonWriterOptions.Indented=false` para una entrada por línea,
`UseUtcTimestamp=true`, `TimestampFormat="yyyy-MM-dd'T'HH:mm:ss.fff'Z'"` y
`IncludeScopes=false`.

El objeto JSON completo pertenece al formatter. Su envelope nativo esperado puede contener
`Timestamp`, `EventId`, `LogLevel`, `Category`, `Message` y `State`; esos nombres no son propiedades
aplicativas ni están sujetos al catálogo cerrado de `State`. En .NET 10, `Message` normalmente
aparece en el nivel superior y no se exige ni se espera que se duplique dentro de `State`.

Dentro de `State`, el contrato cerrado de propiedades aplicativas y dominios es:

| Application State property | Type/domain |
|---|---|
| `operation` | `startup`, `create_order`, `get_order`, `reject_missing_order_id` |
| `httpStatus` | integer or null for startup |
| `outcome` | `succeeded`, `rejected`, `not_found`, `unavailable`, `failed`, `client_disconnected` |
| `durationMs` | non-negative number measured with a monotonic clock |
| `traceId` | ASP.NET Core trace identifier; exact value copied to application Problem Details |
| `failureCategory` | null or `validation`, `invalid_body`, `unsupported_media_type`, `writer_gate_timeout`, `sqlite_busy`, `storage_unavailable`, `startup_schema`, `uuid_collision`, `constraint`, `commit`, `rollback`, `internal` |

La metadata propia del formatter, incluida `{OriginalFormat}`, puede coexistir en `State`; no cuenta
como propiedad aplicativa. Las pruebas permiten sólo las seis propiedades aplicativas anteriores,
verifican que no aparezca ninguna otra propiedad de aplicación y validan por separado el envelope
nativo.

Completion events use Information for `succeeded`, `rejected` and `not_found`; Warning for temporary
unavailability, collision/rollback and disconnect; Error for startup failure or `500`. Operation,
outcome and category are bounded-cardinality; only `traceId` is intentionally high-cardinality.
`operation` is also the logical event name; no second event-name field is introduced.

Only the `Orders.Api` application category is enabled for these events. Framework/provider
categories that can emit raw path, query, connection detail or exception text
(`Microsoft.AspNetCore.*`, `Microsoft.Data.Sqlite`, `Microsoft.Hosting.Lifetime`) are suppressed for
this PoC; startup is represented by the safe custom `startup` event. The exception handler emits
the categorized application event without passing the exception object to `ILogger`.

Prohibited: request/response body, `customerId`, `productId`, `orderId`, raw path, raw query string,
sensitive headers, connection string, physical DB path, SQL, SQL parameters and exception objects
whose message/stack was not explicitly proven free of prohibited data. Stack traces never appear
in responses. Safe internal exception detail may be added to a local log only after review proves
it necessary and free of every prohibited class; the baseline implementation logs category only.

Signals cover startup/schema readiness, validation/parsing rejection, gate timeout, SQLite busy,
rollback, UUID collision, commit failure, `503`, `500` and normal completion. No metrics backend or
distributed tracing is justified for a single local process without downstream services.

### Performance validation protocol

The normative runnable protocol is in [quickstart.md](./quickstart.md). El harness usa
`WebApplicationFactory` configurado para Kestrel real sobre loopback y puerto dinámico; `TestServer`
no participa en la medición:

- Release build on a dedicated local host, loopback, no debugger or unrelated workload;
- instancia y base descartables de warm-up, ambas detenidas al terminar; luego instancia nueva y
  base SQLite nueva de medición, seeded with 25 known orders;
- 25 virtual users released by one barrier;
- five measured cycles per user; each cycle is one POST followed by three GETs (25% writes/75%
  reads), for 500 operations;
- timer starts immediately before HTTP send and stops after the full response body is read;
- p95 uses nearest-rank `ceil(0.95 × N)` over successful measured operations only;
- `503`, timeouts and all other errors are counted separately as failed operations;
- the report records at least OS, CPU, storage and .NET runtime;
- pass requires p95 `< 2.000 ms`, zero `503`, zero timeouts and zero unexpected errors.

The mix exercises the writer gate at each synchronized cycle while representing the only retrieval
capability more frequently; it does not add a list workload.

## Requirement traceability

| Source requirements | Design evidence |
|---|---|
| FR-001–FR-008, SC-001/SC-002 | JSON policy, semantic validation, OpenAPI request/errors, unit/contract tests |
| FR-009–FR-014, SC-001/SC-003 | create flow, atomicity table, durability/schema, data model |
| FR-015–FR-019, SC-003/SC-004 | capability table, query/routing boundary, response matrix |
| FR-020, SR-003 | UUID retries, SQLite primary key, concurrency guarantees |
| FR-021, SC-005 | 1 MiB Kestrel limit, operational budgets, real-Kestrel load protocol |
| SR-001–SR-007, SC-006 | controlled environment, Problem catalog, native logging envelope/application State and automated data contract |

## Constitution Check — Post-design

Los artefactos finales se compararon individualmente con los 40 elementos de
`checklists/pre-tasks.md`: 40 resueltos, 0 abiertos. Se verificaron además enlaces locales,
referencias/estructura OpenAPI, conteo de 2 paths/3 operaciones, presencia de 21 FR/7 SR/6 SC,
ausencia de metadatos contradictorios, consistencia de `tasks.md` y `git diff --check`.

| Principle | Result | Post-design evidence |
|---|---|---|
| Specification First | PASS | Spec y decisiones aprobadas están propagadas y trazadas en plan, research, model, contract, quickstart y checklist. |
| Simplicity and Justified Architecture | PASS | Un web project, un test project y un package runtime; no business scope, auth, idempotencia, rate limiting ni plataforma especulativa. |
| .NET Engineering Standards | PASS | .NET 10 y comportamiento nativo se fijan explícitamente; nullable, lock files y warnings-as-errors permanecen como gates. |
| Testing and Quality | PASS | Se definen tests de negocio, parsing, contrato, fallos, restart, concurrencia, seguridad de logs y carga reproducible. |
| Security by Design | PASS | Trust boundary, 1 MiB, no-auth limitado, data classification, SQL parameters, errors y logs seguros son verificables. |
| Observability and Operability | PASS | Contrato JSON/categorías/levels y supresión de providers inseguros son explícitos; métricas/tracing tienen criterios de reevaluación. |
| Automation and Reproducibility | PASS | Quickstart fija commands, fixtures, entorno, failure codes y protocolo de performance. |
| AI-Assisted Development | PASS | La planificación fue secuencial, sin subagentes, MCP adicional ni nueva dependencia de tooling. |

**Final gate**: PASS.

## Complexity Tracking

No existe violación constitucional ni complejidad excepcional que requiera justificación adicional.

## Specification Gaps and Clarifications

- **Specification gaps**: ninguno después de la remediación y revisión de los 40 checks.
- **Pending clarifications**: ninguna.
- **Remaining contradictions**: ninguna detectada.
- **Readiness**: `READY FOR TASKS`.
