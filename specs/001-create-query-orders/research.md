# Phase 0 Research: Creación y consulta de órdenes

**Feature**: `001-create-query-orders`

**Date**: 2026-07-28

**Status**: Complete — no pending clarifications

Las decisiones se evaluaron desde requisitos y riesgos concretos. Las versiones se comprobaron en
documentación oficial y en el registro de paquetes el 2026-07-28.

## 1. Platform and servicing level

**Decision**: usar .NET 10 LTS con SDK `10.0.302`, C# 14 y paquetes Microsoft de la línea estable
`10.0.10`. Fijar el SDK mediante `global.json`, aceptar roll-forward sólo dentro del patch
planificado y usar lock files de NuGet.

**Rationale**: .NET 10 es el baseline obligatorio y permanece soportado hasta noviembre de 2028.
El servicing `10.0.10`, publicado el 2026-07-14, es el vigente y contiene correcciones de seguridad;
los SDK `10.0.302` y `10.0.110` lo incluyen. El SDK local `10.0.203`/runtime `10.0.7` sirve para
inspección de este plan, pero no es el nivel elegido para implementar o verificar.

**Alternatives considered**:

- Mantener `10.0.203`/`10.0.7`: rechazado porque ya no es el servicing vigente.
- .NET 8 o 9: rechazado; contradice el baseline sin aportar una ventaja.
- .NET 11 preview: rechazado; no es estable y está fuera del baseline.

Sources: [.NET releases and support](https://learn.microsoft.com/en-us/dotnet/core/releases-and-support),
[.NET 10 downloads](https://dotnet.microsoft.com/en-us/download/dotnet/10.0).

## 2. Application type and exposure

**Decision**: servicio web ASP.NET Core Minimal API con JSON sobre HTTP. Exponer:

- `POST /orders` para crear;
- `GET /orders/{orderId}` para consultar;
- `GET /orders` únicamente para representar como `400` la consulta sin identificador.

**Rationale**: el requisito describe solicitantes simultáneos y un contrato de creación/consulta.
HTTP permite una interfaz externa automatizable y accesible sin UI. ASP.NET Core recomienda Minimal
APIs para APIs nuevas y las ofrece en el shared framework, con serialización JSON, routing, DI,
logging y resultados tipados sin dependencias adicionales. Dos endpoints no justifican Controllers.

**Alternatives considered**:

- CLI: rechazada; no representa naturalmente 25 usuarios simultáneos ni una interfaz remota.
- UI web: rechazada; no hay requisitos visuales y agregaría frontend.
- Controllers: rechazados; aportan convenciones y estructura que dos operaciones no requieren.
- gRPC: rechazado; exige contrato/tooling adicional sin streaming ni comunicación servicio-servicio.

Sources: [ASP.NET Core APIs overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/apis?view=aspnetcore-10.0),
[Minimal API responses](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/responses?view=aspnetcore-10.0).

## 3. Minimal solution and project structure

**Decision**: una solución `Orders.slnx`, un proyecto desplegable `src/Orders.Api` y un proyecto
`tests/Orders.Api.Tests`. Mantener clases concretas dentro del proyecto web; no crear proyectos
Domain/Application/Infrastructure ni una librería de contratos.

**Rationale**: una sola feature, dos entidades y dos operaciones caben en una unidad desplegable.
Separar las pruebas mantiene sus dependencias fuera de producción; dividirlas nuevamente en
unit/integration añadiría administración sin aislamiento útil para esta PoC. `.slnx` es el formato
predeterminado de solución en .NET 10.

**Alternatives considered**:

- Todo en un proyecto: rechazado porque mezclaría dependencias y artefactos de prueba con runtime.
- Clean Architecture de cuatro proyectos: rechazada; no existe independencia de despliegue,
  dominio complejo ni adaptadores múltiples que la justifiquen.
- Varios servicios: rechazados; romperían atomicidad y operación simple sin un requisito.
- `.sln` heredado: válido, pero rechazado porque `.slnx` es el default mantenible de .NET 10.

Source: [.NET default templates](https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-new-sdk-templates).

## 4. Persistence

**Decision**: SQLite embebido mediante `Microsoft.Data.Sqlite` `10.0.10`, SQL parametrizado directo y
un archivo configurable en disco local. Crear dos tablas estrictas al iniciar si no existen, activar
foreign keys y WAL. No incorporar migrador en esta primera PoC; cualquier cambio futuro de esquema
deberá introducir una migración explícita.

**Rationale**: FR-014 requiere disponibilidad durante la vida del entorno, y FR-007/FR-020 requieren
atomicidad y unicidad concurrente. SQLite aporta durabilidad, transacciones, primary/foreign keys y
restricciones sin operar un servidor. La BCL no incluye un proveedor SQLite; ésta es la única
dependencia runtime justificada. Con dos tablas y dos consultas, un ORM añade más superficie que SQL
directo.

**Alternatives considered**:

- Memoria (`ConcurrentDictionary`): rechazada; pierde órdenes al reiniciar el proceso.
- JSON/archivo por orden: rechazado; exigiría implementar recuperación de escrituras parciales,
  locking, índices y unicidad que SQLite ya resuelve.
- SQL Server/PostgreSQL: rechazados; añaden servicio, credenciales y operación externa sin escala que
  lo requiera.
- Entity Framework Core: rechazado; tracking, migraciones y LINQ no compensan para dos tablas y SQL
  fijo.
- Repository/Unit of Work: rechazados; `SqliteOrderStore` y una transacción concreta ya expresan el
  límite requerido.

Sources: [Microsoft.Data.Sqlite package](https://www.nuget.org/packages/Microsoft.Data.Sqlite/10.0.10),
[SQLite transactions](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/transactions).

## 5. Identifier generation and uniqueness

**Decision**: generar `Guid.NewGuid()` (UUID v4), exponerlo en formato canónico `D` y persistirlo como
`TEXT PRIMARY KEY COLLATE BINARY`. La creación se considera exitosa sólo después del insert y commit.
Si la primary key detecta una colisión, revertir, generar otro GUID y repetir.

**Rationale**: `Guid.NewGuid()` es nativo, no incorpora cliente, productos ni contenido y usa 122 bits
de entropía fuerte. La aleatoriedad hace la colisión extremadamente improbable; la primary key da la
garantía determinista de que nunca se acepten dos órdenes con el mismo identificador. El valor se
trata como texto opaco en consulta: no se usa `Guid.TryParse` para convertir un identificador no vacío
en validación inválida.

**Alternatives considered**:

- Entero autoincremental: rechazado; es predecible y facilita enumeración en una API sin auth.
- UUID v7: rechazado; el orden temporal no es requisito y revelaría orden/tiempo aproximado.
- ID derivado del cliente/contenido: rechazado por SR-003 y porque solicitudes idénticas deben crear
  órdenes distintas.
- Generador externo: rechazado; no hay despliegue distribuido que lo necesite.

Source: [`Guid.NewGuid`](https://learn.microsoft.com/en-us/dotnet/api/system.guid.newguid?view=net-10.0).

## 6. Atomicity

**Decision**: validar la solicitud completa antes de abrir la transacción; después insertar la fila
de `orders` y todas las filas `order_items` dentro de una única transacción SQLite serializable.
Responder `201` sólo después de `Commit`. Ante cualquier excepción, rollback y respuesta sin
confirmación de creación.

**Rationale**: una transacción agrupa todas las sentencias como una unidad atómica y conserva el
estado inicial si alguna falla. Esto satisface FR-007–FR-009 y el edge case de fallo antes de
confirmación sin compensaciones ni patrones adicionales.

**Alternatives considered**:

- Inserts independientes y compensación: rechazados; pueden dejar estado parcial y son más complejos.
- Transacción distribuida/outbox: rechazados; existe un único recurso local.
- Guardar toda la orden como JSON en una columna: rechazado; dificulta restricciones de unicidad y
  cantidad por elemento sin aportar una necesidad.

Source: [Microsoft.Data.Sqlite transactions](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/transactions).

## 7. Concurrency

**Decision**: una conexión nueva por operación; WAL; transacciones de escritura cortas y un
`SemaphoreSlim(1,1)` en la única instancia para serializar creaciones. Las consultas no usan el gate.
Usar APIs ADO.NET síncronas dentro de la sección crítica, timeout inferior a 2 segundos y devolver
`503` ante saturación/bloqueo operativo sin crear datos parciales.

**Rationale**: los objetos `SqliteConnection`, `SqliteCommand` y `SqliteDataReader` no son thread-safe
y no deben compartirse. SQLite admite concurrencia, pero sólo un escritor pendiente; WAL mejora la
convivencia con lecturas. El gate nativo evita una carrera de writers dentro del único proceso y
mantiene el modelo fácil de probar. SQLite no ofrece I/O async real, por lo que simularlo con métodos
ADO async sólo bloquearía igualmente.

**Alternatives considered**:

- Compartir una conexión singleton: rechazado por thread-safety.
- Confiar sólo en retries de SQLite: válido, pero rechazado como estrategia primaria porque produce
  contención menos predecible bajo la carga objetivo.
- Cola/background worker: rechazado; cambiaría la creación de síncrona a asíncrona.
- Base de datos cliente-servidor: rechazada; 25 usuarios y transacciones pequeñas no la justifican.
- Escalado horizontal: fuera de alcance; el diseño objetivo es una instancia.

Sources: [Database errors, locking and retries](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/database-errors),
[SQLite async limitations](https://learn.microsoft.com/en-us/dotnet/standard/data/sqlite/async).

## 8. Validation

**Decision**: validador C# manual y sin estado que acumula todos los errores detectables. Validar con
`string.IsNullOrWhiteSpace`, `items` no nulo/no vacío, cada item, `Int64 > 0` y duplicados mediante
comparación ordinal exacta. Almacenar los identificadores sin trim, case folding ni normalización.
Los fallos de sintaxis/tipo JSON se reportan como error de `body`; sólo después de un parse exitoso
se enumeran todas las reglas semánticas.

**Rationale**: son pocas reglas, varias cruzan la colección y una debe identificar duplicados. Código
directo es menor y más transparente que un framework. `Int64` mantiene cantidades enteras amplias;
un número fuera de rango se rechaza explícitamente y nunca se trunca o redondea, como permite FR-021.

**Alternatives considered**:

- DataAnnotations/validación automática: rechazada; no cubre bien duplicados, acumulación y rutas de
  error sin validadores propios.
- `Microsoft.Extensions.Validation`: rechazado; añadir paquete para reglas que caben en una función.
- FluentValidation: rechazado; dependencia externa sin complejidad que la justifique.
- Normalizar identificadores: rechazado; alteraría valores opacos y comportamiento de duplicados.

## 9. External contract and errors

**Decision**: contrato OpenAPI 3.1 estático en `contracts/openapi.yaml`. Éxito de creación `201` con
`Location`, `orderId` y `Pending`; consulta `200`; validación `400`; no encontrado `404`; límite de
transporte `413`; indisponibilidad temporal `503`. Todos los errores usan
`application/problem+json`; validación añade `errors` y todos añaden `traceId`.

**Rationale**: Problem Details es capacidad nativa de ASP.NET Core y produce un formato consistente
sin middleware de terceros. Un contrato estático basta para dos endpoints y sirve directamente como
fuente para pruebas; no hace falta generación OpenAPI en runtime. El detalle no expone excepciones,
SQL, rutas físicas ni datos ajenos.

**Alternatives considered**:

- Objeto de error propio: rechazado; duplicaría un estándar y soporte nativo.
- Excepciones/stack traces en respuesta: rechazados por SR-005.
- `200` para errores: rechazado; degrada semántica HTTP y pruebas.
- `Microsoft.AspNetCore.OpenApi` runtime: rechazado; el contrato versionado estático satisface la
  necesidad sin dependencia de producción adicional.

Sources: [ASP.NET Core API error handling](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling-api?view=aspnetcore-10.0),
[ASP.NET Core error handling](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling?view=aspnetcore-10.0).

## 10. Testing strategy

**Decision**: `MSTest` `4.3.2` y `Microsoft.AspNetCore.Mvc.Testing` `10.0.10` en un proyecto de
pruebas. Cobertura:

- unit: todas las combinaciones de validación y acumulación de errores;
- integration: esquema SQLite, create/read y rollback real con archivo temporal por test;
- contract: status, headers, media types y cuerpos del OpenAPI;
- concurrency: 25 creaciones paralelas, IDs distintos y 25 órdenes completas consultables;
- atomicity: fallo de item dentro de la transacción deja cero filas;
- load/acceptance: mezcla de creación/consulta, 25 usuarios, p95 < 2 s y resultados correctos;
- usability acceptance: participantes representativos siguen únicamente el quickstart; se mide desde
  que reciben la guía hasta que crean y consultan una orden, y al menos 95 % termina sin ayuda en
  menos de 2 minutos (SC-005);
- security/observability: no se filtran detalles internos y los logs capturados omiten identificadores
  y cuerpos.

**Rationale**: MSTest es mantenido, integra runner y analyzers; `WebApplicationFactory` prueba el
pipeline real en proceso. SQLite temporal prueba la tecnología elegida en lugar de un fake. La carga
es pequeña y puede producirse con `Task` + `HttpClient`, sin instalar herramienta de performance.
SC-005 mide comprensión humana y por ello requiere una sesión de aceptación registrada, no una
simulación automatizada; todos los demás comportamientos se automatizan.

**Alternatives considered**:

- Sólo unit tests: rechazado; no demostrarían transacciones, routing ni contrato.
- Mocks de base de datos: rechazados; ocultarían la semántica de SQLite.
- xUnit/NUnit: válidos, pero no aportan capacidad necesaria frente a MSTest.
- Playwright: rechazado; no existe UI.
- Herramienta externa de load test: rechazada; 25 usuarios caben en un harness de prueba nativo.

Sources: [MSTest SDK guidance](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-mstest-sdk),
[ASP.NET Core integration tests](https://learn.microsoft.com/en-us/aspnet/core/test/integration-tests?view=aspnetcore-10.0),
[`Microsoft.AspNetCore.Mvc.Testing` 10.0.10](https://www.nuget.org/packages/Microsoft.AspNetCore.Mvc.Testing/10.0.10),
[`MSTest` 4.3.2](https://www.nuget.org/packages/MSTest/4.3.2).

## 11. Logging and observability

**Decision**: `ILogger` con console formatter JSON nativo y un middleware mínimo de finalización.
Registrar nombre estable de operación, status, duración, resultado y `traceId`; registrar excepciones
operativas con código/categoría, nunca cuerpos, ruta cruda, orderId, customerId ni productId. Sin
exportador de métricas o tracing. El load test calcula conteo, errores y p95.

**Rationale**: logs estructurados permiten diagnosticar fallos y latencia con capacidades incluidas
en ASP.NET Core. El orderId concede consulta en esta PoC, por lo que omitirlo de logs reduce exposición.
No hay backend de observabilidad ni servicios downstream que justifiquen OpenTelemetry/exporters.

**Alternatives considered**:

- Serilog/NLog: rechazados; el proveedor JSON nativo cubre el requisito.
- Logging de request/response bodies: rechazado por SR-007.
- Stack de métricas/tracing: rechazado en esta PoC; se reconsiderará al definir un backend operativo
  o múltiples servicios.

Source: [Console log formatting](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging/console-log-formatter).

## 12. Capacity target

**Decision**: diseñar para 25 usuarios con operaciones pequeñas, validar con una barrera que inicia
25 flujos simultáneos y medir cada resultado desde cliente. El test falla si existen IDs repetidos,
errores inesperados, datos incompletos o p95 >= 2 segundos.

**Rationale**: la carga es baja para Kestrel y SQLite WAL si las escrituras son breves. La evidencia
medida es preferible a añadir cache, pooling manual o infraestructura anticipada. El gate de escritura
se evaluará bajo el caso peor de 25 creaciones simultáneas.

**Alternatives considered**:

- Cache de órdenes: rechazada; añade consistencia sin demostrar necesidad.
- Optimización prematura/benchmark de microcomponentes: rechazada; el criterio es end-to-end.
- Escalado horizontal: rechazado; amplía operación y cambia persistencia sin requisito.

## 13. Build, tests and execution automation

**Decision**: proponer `global.json`, `Directory.Build.props`, `Directory.Packages.props`, lock files
y `scripts/verify.ps1`. El script ejecutará restore bloqueado, build Release con warnings como errores,
pruebas completas y categorías de concurrencia/carga; cada comando propagará código de fallo. La
ejecución usa `dotnet run` y configuración por variables de entorno.

**Rationale**: comandos SDK y PowerShell cumplen reproducibilidad sin instalar herramientas.
Centralizar versions evita drift entre runtime y tests. El script no oculta pasos manuales.

**Alternatives considered**:

- Make/Bash: rechazados; PowerShell es la preferencia constitucional del repositorio.
- Docker como requisito de build: rechazado; SQLite embebido y .NET SDK bastan.
- CI de proveedor concreto: diferido; no se ha solicitado plataforma remota.

## Research conclusion

Todas las decisiones técnicas necesarias quedaron resueltas. No se detectó una decisión de negocio
que requiera modificar `spec.md` y no quedan aclaraciones pendientes.
