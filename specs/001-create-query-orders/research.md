# Phase 0 Research: Creación y consulta de órdenes

**Feature**: `001-create-query-orders`

**Active Git branch**: `main`

**Date**: 2026-07-28

**Status**: Complete after post-design checklist review

Las decisiones se agrupan por impacto material en contrato, implementación, pruebas, seguridad,
concurrencia, rendimiento y operación. Los checks no se convierten en requisitos independientes.

## 1. Platform and minimal solution

**Decision**: .NET 10 LTS con SDK `10.0.302`, C# 14 y paquetes Microsoft de servicing `10.0.10`.
Una solución `.slnx`, un proyecto `Orders.Api` y un proyecto `Orders.Api.Tests`.

**Rationale**: .NET 10 es constitucional. ASP.NET Core, `System.Text.Json`, Problem Details, DI y
logging están en el shared framework. Sólo SQLite necesita paquete runtime. La feature no justifica
proyectos por capa.

**Alternatives considered**:

- Clean Architecture, CQRS, MediatR, Repository, Unit of Work: rechazados por falta de necesidad.
- Frameworks externos de JSON, validación o logging: rechazados; las capacidades nativas bastan.
- Varios servicios o proyectos de dominio/infraestructura: rechazados; amplían despliegue y
  transacciones sin aportar comportamiento.

Sources: [.NET releases and support](https://learn.microsoft.com/en-us/dotnet/core/releases-and-support),
[ASP.NET Core API overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis?view=aspnetcore-10.0).

## 2. Two capabilities and three HTTP operations

**Decision**: exponer exactamente:

- `POST /orders`: capacidad de crear;
- `GET /orders/{orderId}`: capacidad de consultar por identificador;
- `GET /orders`: operación técnica que responde `400` por identificador ausente y nunca enumera.

**Rationale**: reconcilia el contrato aprobado sin inventar una tercera capacidad. HTTP JSON permite
pruebas automatizadas y 25 clientes concurrentes; Minimal APIs es la opción más pequeña.

**Alternatives considered**:

- Omitir `GET /orders`: rechazado; volvería dependiente del router la distinción normativa de
  identificador ausente.
- Hacer de `GET /orders` un listado: rechazado; añade negocio fuera de alcance y expone datos.
- Controllers/gRPC/UI/CLI: rechazados por complejidad o falta de adecuación al contrato aprobado.

Source: [Minimal API parameter binding](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/parameter-binding?view=aspnetcore-10.0).

## 3. JSON binding policy

**Decision**: usar `HttpRequest.ReadFromJsonAsync<T>`/`System.Text.Json` dentro del endpoint, sin
parser ni converter propio. El DTO usa referencias y cantidades anulables para que ausencia/null
puedan acumularse como errores semánticos. Opciones:

- property naming camelCase y matching case-sensitive;
- numeric handling estricto;
- `AllowDuplicateProperties=false`;
- propiedades desconocidas ignoradas (`UnmappedMemberHandling=Skip`);
- sin comentarios, trailing commas ni números entre comillas.

La política observable es:

| Case | Result |
|---|---|
| Body ausente, vacío o top-level `null` con Content-Type correcto | `400 invalid-body` |
| JSON truncado/malformado | `400 invalid-body` |
| Propiedad obligatoria ausente o nula | deserializa a null y participa en `400 validation` |
| `items` nulo/vacío o elemento nulo | `400 validation`; se siguen validando valores disponibles |
| Tipo incorrecto | `400 invalid-body`; no se promete validación semántica posterior |
| Cantidad fuera de `Int64`, fracción o notación exponencial | `400 invalid-body` |
| Propiedad desconocida | ignorada, nunca almacenada ni devuelta |
| Nombre de propiedad JSON repetido | `400 invalid-body` mediante opción nativa de .NET 10 |
| Content-Type ausente o distinto de `application/json` | `415` antes de leer el body; prevalece si también falta body |

**Rationale**: distingue parsing de semántica y permite cumplir la acumulación sin reimplementar
JSON. Ignorar miembros desconocidos es el default más simple y compatible; cerrar los esquemas de
respuesta evita que esa tolerancia expanda los datos expuestos. Rechazar duplicados elimina
last-write-wins ambiguo usando una opción nativa.

**Alternatives considered**:

- Parser `Utf8JsonReader` propio: rechazado; replica funcionalidad estándar.
- Rechazar propiedades desconocidas: válido, pero descartado porque no protege un requisito y
  endurece innecesariamente la PoC.
- Aceptar duplicados con “último gana”: rechazado por ambigüedad contractual.
- C# `required` para todo: rechazado porque convertiría ausencias en parsing failure e impediría
  acumular otras reglas semánticas.

Sources:
[required properties](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/required-properties),
[nullable annotations](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/nullable-annotations),
[unmapped members](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/missing-members),
[`AllowDuplicateProperties`](https://learn.microsoft.com/en-us/dotnet/api/system.text.json.jsonserializeroptions.allowduplicateproperties?view=net-10.0),
[`Utf8JsonReader.GetInt64`](https://learn.microsoft.com/en-us/dotnet/api/system.text.json.utf8jsonreader.getint64?view=net-10.0).

## 4. SQLite persistence and durability boundary

**Decision**: `Microsoft.Data.Sqlite` `10.0.10`, SQL parametrizado y un archivo configurable sobre
almacenamiento local persistente. El archivo principal y los sidecars WAL activos se preservan como
una unidad. Configuración:

- esquema v1 creado transaccionalmente y validado al iniciar;
- `PRAGMA user_version=1`, tablas/columnas requeridas, `quick_check` correcto y
  `foreign_key_check` vacío;
- `STRICT`, `foreign_keys=ON`, `journal_mode=WAL`, `synchronous=FULL`;
- sin `Cache=Shared`;
- `PRAGMA busy_timeout=500` en cada conexión;
- writer transaction `BEGIN IMMEDIATE`.

Una orden confirmada sobrevive reinicios del proceso y host si se conserva ese almacenamiento.
Recrear el entorno, eliminar/reemplazar el archivo o perder el volumen queda fuera de garantía.

**Rationale**: SQLite aporta recuperación WAL, atomicidad y constraints sin servidor/credenciales.
`FULL` prioriza la garantía de durabilidad de esta PoC sobre micro-optimizaciones. Versionar y
validar el esquema evita operar silenciosamente con estructura incompatible.

**Alternatives considered**:

- Memoria: rechazada; no sobrevive reinicio de proceso.
- JSON/archivo por orden: rechazado; obligaría a construir journaling, locks e índices.
- SQL Server/PostgreSQL: rechazados; añaden servicio y secretos sin requisito.
- Migrator/ORM: diferidos; el esquema v1 fijo puede crearse directamente. Un cambio futuro sí
  requerirá migración explícita.

Sources:
[Microsoft.Data.Sqlite connection strings](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/connection-strings),
[SQLite transactions](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/transactions),
[SQLite async limitations](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/async).

## 5. UUID v4 identity and bounded collision handling

**Decision**: generar `Guid.NewGuid()`, serializar `ToString("D")` y persistir
`TEXT PRIMARY KEY COLLATE BINARY`. La primary key es la garantía definitiva. Una colisión hace
rollback del intento, genera un UUID nuevo y vuelve a intentar, con tres intentos totales. Tras la
tercera colisión: rollback, cero orden confirmada, `500 internal`, log sólo
`failureCategory=uuid_collision`.

**Rationale**: UUID v4 no revela contenido y satisface unicidad sin coordinador. El límite evita un
loop indefinido aunque la colisión sea extremadamente improbable.

**Alternatives considered**:

- Retry ilimitado: rechazado; viola presupuestos y oculta un generador defectuoso.
- UUID v7/autoincremental: rechazados; aportan orden/predecibilidad no requerida.
- Idempotency key o ID derivado del contenido: rechazados; contradicen creaciones independientes.

Source: [`Guid.NewGuid`](https://learn.microsoft.com/en-us/dotnet/api/system.guid.newguid?view=net-10.0).

## 6. Atomicity and uncertain outcomes

**Decision**: mantener exactamente:

```text
validación completa
→ writer gate
→ conexión + BEGIN IMMEDIATE
→ insert orders
→ insert all order_items
→ commit
→ intento de respuesta HTTP 201
```

No se usa el cancellation token del cliente para interrumpir una transacción después de iniciada;
la operación termina en commit o rollback para conservar una frontera determinista. Cualquier
fallo pre-commit revierte. `201` sólo se intenta después del retorno exitoso de commit.

`503` se usa únicamente cuando se sabe que no hubo commit. Si commit arroja y no puede demostrarse
su resultado, se clasifica `500`/desconexión, nunca `503`. Si commit terminó y la respuesta se pierde,
la orden puede existir aunque el cliente no conozca el resultado. Un retry puede crear otra orden.

**Minimal testability mechanism**: `SqliteOrderStore.cs` conserva delegates internos, no-op por
default, inmediatamente antes de `BEGIN`, después del insert de `orders`, después de todos los
inserts de items, antes de commit y después de commit. `Program.cs` conserva un único delegate
interno después de commit y antes de construir/escribir la respuesta. `InternalsVisibleTo` da
acceso sólo a `Orders.Api.Tests`. Las pruebas pueden hacer que esos delegates bloqueen con
`Barrier`/`ManualResetEventSlim` o lancen un fallo determinista; producción no los configura. El
generador UUID sustituible puede integrarse en el mismo mecanismo o permanecer separado.

**Rationale**: la transacción evita estados parciales; no hay compensación ni recurso distribuido.
La ausencia deliberada de idempotencia hace necesario documentar, no ocultar, el resultado incierto.
Estos seams observan/provocan las fronteras reales sin introducir delays, capas, Repository, Unit
of Work, framework de mocks/fault injection, paquetes ni proyectos.

**Alternatives considered**:

- Devolver `201` antes del commit: rechazado; confirmaría datos no durables.
- Convertir todo fallo de persistencia a `503`: rechazado; podría afirmar falsamente “no commit”.
- Outbox/idempotency key: rechazados; no hay downstream y el usuario prohibió resolver el retry de
  esa manera.

## 7. Concurrency model and operational budget

**Decision**:

- una sola instancia soportada;
- una conexión SQLite por operación;
- `SemaphoreSlim(1,1)` sólo para writers;
- espera máxima del gate: 1.000 ms;
- readers sin gate;
- `busy_timeout`: 500 ms;
- no retry loop general de SQLite;
- no timeout artificial dentro de la transacción síncrona.

Presupuesto de objetivo: 1.000 ms gate + 500 ms busy + 500 ms de margen para binding, validación,
SQL local, commit y respuesta. El objetivo `<2 s` se verifica end-to-end; no se declara un hard
timeout de servidor que no pueda cancelar commit con seguridad.

`SemaphoreSlim` no garantiza FIFO. No se fija una segunda capacidad de cola: las 25 solicitudes
esperan de forma asíncrona y las que excedan 1 segundo reciben `503`. El riesgo de starvation se
acepta sólo en el entorno/control/carga declarados.

**Guarantees by component**:

- Gate: evita writers simultáneos dentro del proceso y da el timeout local.
- SQLite: ACID, primary/foreign keys, locks interproceso, snapshot de lectura y ausencia de
  parciales.
- WAL: permite readers con writer; no sustituye atomicidad/constraints.

Una lectura iniciada antes del commit puede ver el snapshot anterior y responder `404`; nunca ve
una orden parcial. Una consulta iniciada después del commit puede ver la orden completa. El `404`
pre-commit no impide un commit posterior.

**Alternatives considered**:

- Gate también para readers: rechazado; reduce concurrencia sin mejorar consistencia.
- Retry/backoff general: rechazado; podría exceder silenciosamente 2 segundos.
- Background queue: rechazado; cambiaría la API síncrona.
- Horizontal scale: rechazado; fuera de alcance y el gate sería sólo local.

Sources:
[SQLite locking and retries](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/database-errors),
[SQLite async limitations](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/async).

## 8. Semantic validation and duplicate reporting

**Decision**: validación manual, determinista y acumulativa después de deserialización:

1. `customerId` utilizable;
2. `items` presente/no vacío;
3. cada elemento no nulo;
4. cada `productId` utilizable;
5. cada `quantity` presente y positiva;
6. duplicados entre product IDs utilizables con `StringComparer.Ordinal`.

Para cada repetición posterior a la primera, usar la clave `items[n].productId` y un mensaje que
referencia el índice previo, no el ID controlado por el solicitante. Case, whitespace y secuencias
Unicode distintas no son duplicados. Tres repeticiones y varios grupos producen un error por cada
ocurrencia posterior. Items/IDs nulos o inválidos conservan sus errores y no participan en el set.

**Rationale**: informa exactamente qué posiciones conflictúan sin eco de entrada ni amplificación.
Un único recorrido acumula reglas sin framework de validación.

**Alternatives considered**:

- Consolidar cantidades: rechazado; cambia negocio.
- Normalizar/trim/case-fold: rechazado; altera identificadores opacos.
- Incluir productId en el mensaje: rechazado; eco innecesario de input no confiable.

## 9. 1 MiB transport protection

**Decision**: configurar `KestrelServerOptions.Limits.MaxRequestBodySize=1_048_576`. No se instala
request-decompression middleware. El límite cuenta bytes del body entregado por Kestrel después de
framing, tanto con `Content-Length` como chunked; un `Content-Length` superior puede rechazarse antes
de ejecutar el endpoint y un stream sin longitud se rechaza al superar el límite. Nunca se trunca.

`413` garantiza cero orden porque el body no alcanza una creación válida. Un `Content-Length`
superior permite rechazo temprano; si falta se cuentan bytes reales, y si es engañoso/inconsistente
la solicitud es un error de protocolo del host y no puede eludir el límite. Como el rechazo puede
producirse antes del pipeline de la app, no se garantiza body, media type ni Problem Details.

**Rationale**: es la protección más simple y nativa frente a bodies desproporcionados; no introduce
un máximo de productos ni cantidad.

**Alternatives considered**:

- Límite de items o cantidad: rechazado; sería máximo de negocio.
- Leer/truncar manualmente: rechazado; violaría rechazo total y reimplementaría límites.
- Middleware de error para todos los `413`: rechazado; no puede cubrir todos los rechazos del host
  y añade complejidad sin valor para la PoC.

Sources:
[Kestrel security and limits](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/security-considerations?view=aspnetcore-10.0),
[Kestrel options](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/options?view=aspnetcore-10.0).

## 10. HTTP errors and Problem Details boundary

**Decision**: todos los errores creados por handlers/application services usan
`application/problem+json`, catálogo estable y schemas cerrados. La matriz normativa:

| Operation | 2xx | 400 | 404 | 413 | 415 | 500 | 503 |
|---|---:|---:|---:|---:|---:|---:|---:|
| `POST /orders` | 201 | app PD | N/A | host; PD not guaranteed | app PD | app PD | app PD; no commit |
| `GET /orders` | — | app PD | N/A | N/A | N/A | app PD | N/A |
| `GET /orders/{orderId}` | 200 | app PD | app PD | N/A | N/A | app PD | app PD |

`405`, malformed HTTP, server timeouts, route rejections and disconnects outside controlled handlers
are explicitly outside the Problem Details contract. No middleware se añade sólo para unificarlos.
No `Retry-After`: no existe intervalo conocido.

Problem types/titles/details/instances/keys are normative in `plan.md` and OpenAPI. `instance` uses
route template, not raw input. Handlers producen los errores conocidos; un exception handler
estándar mínimo produce sólo el `500` seguro de excepciones no controladas. No se habilita status
code pages, por lo que `405`/routing no se homogeneizan. `500` nunca incluye exception, SQL, path o
stack trace.

**Rationale**: el contrato sólo promete lo que la aplicación controla. ASP.NET Core Problem Details
evita un envelope propio.

**Alternatives considered**:

- “Todos los errores HTTP son Problem Details”: rechazado; Kestrel/red pueden responder antes.
- Middleware complejo para 405/timeouts: rechazado; no mejora el negocio.
- Error model custom: rechazado; duplica el estándar.

Sources:
[ASP.NET Core API error handling](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0),
[Minimal API responses](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-10.0).

## 11. 503 and permanent failures

**Decision**: `503` sólo para gate timeout, SQLite busy/locked agotando 500 ms, o storage temporal
pre-commit con garantía de no commit. Permisos, configuración, corrupción, schema incompatible,
filesystem lleno, constraints inesperadas e invariantes internas son `500` genérico o fallo de
startup. Un fallo ambiguo de commit no es `503`.

**Rationale**: separa indisponibilidad temporal/reintentable de defectos permanentes y mantiene la
garantía fuerte de no confirmación en cada `503`.

**Alternatives considered**:

- Retry general o `Retry-After`: rechazados; no hay intervalo fiable.
- Tratar “disk full” como temporal: rechazado; requiere intervención y no es un retry corto seguro.

## 12. Controlled environment, data classification and rate limiting

**Decision**: soportar sólo loopback o red de desarrollo aislada, sin Internet pública, con datos
sintéticos o preclasificados no sensibles y sin credenciales reales. HTTP sin TLS se permite sólo
en loopback; otra topología controlada decide TLS en su boundary. El operador es responsable de
binding/firewall. Salir de ese límite requiere auth, authz, revisión de red/TLS y threat review.

No implementar rate limiting: entorno aislado, 25 usuarios de aceptación y no exposición pública.
Reevaluar antes de exposición no controlada o incremento material de carga.

SC-006 se evidencia automáticamente con fixtures controlados de nombres sintéticos, inspección de
los archivos SQLite/reportes producidos por la suite y validaciones de ausencia de canarios
prohibidos. Cualquier fixture externo requeriría un registro previo de clasificación no sensible;
la baseline no depende de datasets externos ni de revisión por participantes humanos.

**Rationale**: auth y rate limiting no aportan al ejercicio si el boundary se cumple; documentar al
responsable evita presentar la API anónima como segura fuera de él.

## 13. Logging and observability

**Decision**: usar el formatter JSON console nativo de
`Microsoft.Extensions.Logging.Console`, sin formatter propio. Configurarlo explícitamente como
JSON de una entrada por línea (`JsonWriterOptions.Indented=false`), UTC
(`UseUtcTimestamp=true`), timestamp explícito y `IncludeScopes=false`.

El formatter es propietario del envelope JSON, que puede contener los campos nativos configurados
`Timestamp`, `EventId`, `LogLevel`, `Category`, `Message` y `State`. Esos campos no forman parte del
catálogo de propiedades aplicativas. En .NET 10, `Message` normalmente está en el nivel superior y
no se duplica dentro de `State`.

El contrato cerrado dentro de `State` permite estas seis propiedades aplicativas:

- `operation`: `startup`, `create_order`, `get_order`, `reject_missing_order_id`;
- `httpStatus`;
- `outcome`: `succeeded`, `rejected`, `not_found`, `unavailable`, `failed`,
  `client_disconnected`;
- `durationMs`;
- `traceId`;
- `failureCategory` del catálogo cerrado de `plan.md`.

También puede aparecer metadata generada por el formatter, como `{OriginalFormat}`; no se considera
propiedad aplicativa. La suite comprueba el envelope nativo esperado, la presencia y dominio de las
seis propiedades aplicativas, ausencia de otras propiedades de aplicación, ausencia de datos
sensibles y correlación exacta del `traceId`.

Sólo la categoría `Orders.Api` queda habilitada para eventos aplicativos. Se suprimen categorías de
framework/provider capaces de emitir path/query, connection detail o exception text
(`Microsoft.AspNetCore.*`, `Microsoft.Data.Sqlite`, `Microsoft.Hosting.Lifetime`); startup usa un
evento custom seguro.

`operation` es a la vez nombre lógico del evento; no se agrega otro campo. Information para
éxito/4xx funcional; Warning para indisponibilidad, colisión, rollback o desconexión; Error para
startup/500. `traceId` coincide con Problem Details. Categorías cubren
startup/schema, parsing/validation, gate/busy, storage, collision, rollback, commit, 503 y 500.

Prohibido: bodies, customer/product/order IDs, raw path/query, sensitive headers, connection string,
physical DB path, SQL/parameters y exception detail no revisado. Baseline registra categoría, no
exception object; el exception handler tampoco pasa la excepción a `ILogger`. Se verifica
capturando logs y buscando valores canario de requests/configuración.

Sin métricas exportadas ni distributed tracing. Reconsiderar con múltiples instancias, downstream
services, SLO, alertas u on-call.

**Rationale**: logs estructurados bastan para el diagnóstico de una sola PoC local y evitan nueva
infraestructura/cardinalidad. Separar envelope de `State` preserva el comportamiento nativo del
formatter sin afirmar que las seis propiedades aplicativas son las únicas claves del JSON completo.

**Alternatives considered**:

- Formatter propio, Serilog, OpenTelemetry o backend de métricas: rechazados por ausencia de
  necesidad/consumidor operativo.
- Request/response logging: rechazado por privacidad y porque expondría la capacidad `orderId`.

Source: [JSON console formatter](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging/console-log-formatter).

## 14. Testing and reproducible performance

**Decision**: MSTest + `WebApplicationFactory`, SQLite real y fixtures temporales. Cobertura:

- unit: parsing-policy-adjacent DTO cases y todas las reglas semánticas acumulables;
- contract: auditoría diferencial de tres operaciones, statuses, headers, media types, schemas
  cerrados y catálogo contra `contracts/openapi.yaml`;
- integration: schema/pragmas, create/read, restart with same file, startup failures;
- atomicity: cada frontera pre-commit y rollback sin parciales mediante los delegates internos;
- identity: collision attempts 1/2/3 con generador sustituible sólo en tests;
- concurrency: reads before/after commit sincronizadas con `Barrier`/`ManualResetEventSlim`, no
  partial reads, writer saturation and busy timeout;
- host boundary: Kestrel real sobre loopback/puerto dinámico, incluido request válido cercano a
  1 MiB con muchos productos distintos y persistencia completa;
- security/logging: envelope nativo separado de `State`, no forbidden canary appears y correlación
  exacta de `traceId`;
- load: SC-005 sobre Kestrel real, 25 users, exact 25/75 POST/GET mix and p95 protocol;
- data: SC-006 mediante fixtures controlados y comprobaciones automáticas, sin participantes.

`WebApplicationFactory` se configura para usar Kestrel y URL loopback con puerto dinámico en los
tests host-boundary/load; `TestServer` no se usa para medir. Los delegates de test y primitivas
nativas sustituyen delays arbitrarios y no requieren framework de mocks/fault injection.

Protocolo SC-005:

1. Release, Kestrel real en loopback/puerto dinámico, host dedicado sin debugger/carga ajena.
2. Warm-up en instancia y base descartables: dos ciclos por usuario, no medidos; detener y
   descartar ambos.
3. Iniciar instancia nueva con base SQLite nueva; crear 25 seed orders antes de medir.
4. Liberar 25 usuarios por barrera.
5. Cada usuario ejecuta cinco ciclos secuenciales: POST + GET propia + dos GET de seeds.
6. Total: 500 operaciones, 125 POST y 375 GET.
7. Medir desde antes de `SendAsync` hasta después de leer todo el body.
8. p95 nearest-rank: ordenar N duraciones exitosas y tomar `ceil(0.95*N)`.
9. Reportar por separado `201`, `200`, `503`, timeouts y otros errores.
10. Registrar como mínimo OS, CPU, storage y runtime .NET.
11. Pasar sólo con p95 `< 2.000 ms`, cero `503`, cero timeouts y cero errores inesperados.

**Rationale**: sincronizar el POST inicial de cada ciclo estresa el único writer y los GET prueban
la capacidad de consulta/reader concurrency. El número fijo hace el resultado repetible sin
herramienta externa.

**Alternatives considered**:

- 100% writes: útil como stress, pero no representa ambas capacidades; queda en suite de
  concurrencia, no SC-005.
- Herramienta de load externa: rechazada; 25 usuarios caben en harness .NET.
- Incluir 400/404 en población de latencia: rechazado; SC-005 mide flujos exitosos y los errores se
  reportan aparte.

Sources:
[MSTest SDK](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-mstest-sdk),
[ASP.NET Core integration tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-10.0).

## 15. Automation and traceability

**Decision**: `global.json`, central package versions, lock files y `scripts/verify.ps1`. El script
ejecuta y detiene al primer fallo: locked restore; Release build con warnings-as-errors; tests
unitarios; integración; contract; persistence/atomicity; restart; concurrency; Kestrel
host-boundary; logging/security; SC-005 performance; y validación de lock files. SC-006 se verifica
con fixtures/repositorios y artefactos controlados, no con intervención humana. La matriz
bidireccional de `plan.md` relaciona grupos FR/SR/SC con diseño, model, OpenAPI y quickstart.

**Rationale**: hace reproducibles los gates sin crear CI/proveedor ni scripts Bash.

**Alternatives considered**:

- Docker/CI como prerrequisito: rechazados; no son necesarios para build/test local.
- Pasos manuales ocultos: rechazados por la Constitution.

## Research conclusion

Las decisiones materiales están resueltas sin añadir negocio, autenticación, idempotencia, rate
limiting, escalado horizontal ni observabilidad externa. La revisión post-design encontró evidencia
para los 40 checks y cero contradicciones o clarificaciones técnicas pendientes; el resultado
coincide con `plan.md`: `READY FOR TASKS`.
