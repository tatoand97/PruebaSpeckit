# Phase 0 Research: Registro y consulta de solicitudes de contacto

**Feature**: `001-contact-requests`
**Date**: 2026-07-29

## 1. Límite de dominio

**Decision**: Crear un único módulo DDD `ContactRequests`, responsable de registrar y recuperar
solicitudes de contacto.

**Rationale**: Registro y consulta operan sobre el mismo agregado, comparten reglas e identidad y
forman una sola capacidad de dominio. Separarlas produciría límites técnicos sin autonomía de
negocio.

**Alternatives considered**:

- Módulos separados para escritura y lectura: rechazado; sería CQRS ceremonial para dos casos de
  uso sobre el mismo modelo.
- Módulos por protocolo o almacenamiento: rechazado; HTTP y SQL Server son detalles técnicos, no
  capacidades del dominio.

## 2. Interfaz externa

**Decision**: Exponer dos operaciones HTTP mediante ASP.NET Core Minimal APIs:
`POST /contact-requests` y `GET /contact-requests/{contactRequestId}`.

**Rationale**: La feature requiere una interfaz para consumidores externos, creación de un recurso
y recuperación por identificador exacto. HTTP permite expresar creación con `201` y consulta con
`200`/`404` sin agregar operaciones fuera del alcance.

**Alternatives considered**:

- CLI: rechazado; no satisface de forma natural el consumo abierto de la aplicación.
- gRPC: rechazado; agrega contrato y tooling innecesarios para el caso de uso sencillo.

## 3. Identidad y tiempo

**Decision**: Generar identificadores UUID versión 7 en el sistema y registrar `CreatedAtUtc` como
`DateTimeOffset` obtenido de `TimeProvider`.

**Rationale**: UUID v7 mantiene unicidad práctica bajo concurrencia y mejor localidad de índice que
un UUID completamente aleatorio. `DateTimeOffset` en UTC representa un instante inequívoco.
`TimeProvider` hace deterministas las pruebas sin introducir un wrapper propio.

**Alternatives considered**:

- Identidad incremental: rechazada; hace más predecibles los identificadores de una consulta
  abierta y requiere coordinación central.
- UUID v4: válido, pero rechazado por su peor localidad de índice.
- Servicio de reloj propio: rechazado; `TimeProvider` ya cubre la necesidad.

## 4. Persistencia

**Decision**: Usar EF Core con SQL Server y un repositorio específico
`IContactRequestRepository`, implementado en Infrastructure.

**Rationale**: La feature necesita conservación durable, unicidad del identificador, inserción
atómica y lectura exacta por clave. SQL Server y EF Core cubren esas necesidades con un modelo
relacional pequeño y estable. Cada alta es un único `SaveChangesAsync`; si falla, no existe una
creación parcial. Application y Presentation solo conocen la abstracción específica.

**Alternatives considered**:

- EF Core con MongoDB: técnicamente viable para un documento aislado, pero no aporta una ventaja
  requerida frente a la consistencia y restricciones de clave del modelo relacional.
- Memoria o archivo: rechazados; no proporcionan durabilidad ni coordinación segura entre
  instancias.
- Repositorio genérico: rechazado; expone operaciones no requeridas y diluye el lenguaje del caso
  de uso.

El versionado, creación, actualización y despliegue del esquema físico quedan fuera de alcance. No
se usarán EF Core Migrations, `dotnet-ef`, snapshots, `database update` ni `EnsureCreated()` como
política alternativa.

## 5. Modelo y validación

**Decision**: Modelar una entidad `ContactRequest` con una factory que recorta nombre, asunto y
mensaje, protege sus invariantes y acepta cada alta válida como nueva. FluentValidation validará
los comandos antes del handler para devolver errores comprensibles.

**Rationale**: La validación en Application produce detalles por campo; las guardas del Domain
evitan que un caller interno construya estado inválido. No se necesitan value objects, mappers,
domain events ni servicios de dominio para estas reglas locales.

**Alternatives considered**:

- Validar solo en el endpoint: rechazado; permite omitir reglas al invocar Application.
- Value objects por cada string: rechazados; no agregan comportamiento o identidad suficiente en
  esta feature.
- Deduplicación o idempotencia: rechazadas porque FR-009 exige una solicitud nueva por cada alta
  válida.

El correo se conserva tal como fue recibido y se valida mediante una única política compartida por
Domain y el validador: 1–320 caracteres ASCII imprimibles U+0021–U+007E, un único `@`, partes local
y dominio no vacías y un dominio con al menos un punto y etiquetas no vacías. La columna usa
`nvarchar(320)`. Nombre, asunto y mensaje se miden en valores escalares Unicode tras retirar
`White_Space` exterior y usan capacidades UTF-16 conservadoras `nvarchar(300)`, `nvarchar(400)` y
`nvarchar(4000)` para admitir los máximos 150, 200 y 2000 definidos por FR-004 a FR-006.

## 6. Mediación y flujo

**Decision**: Presentation enviará `CreateContactRequestCommand` y
`GetContactRequestQuery` mediante Wolverine configurado con
`DurabilityMode.MediatorOnly`.

**Rationale**: Cumple la separación entre endpoint y caso de uso manteniendo el flujo
Minimal API → Presentation → Wolverine → Application → Domain → repositorio → Infrastructure.

**Alternatives considered**:

- Invocación directa del handler: rechazada; rompe el mecanismo de mediación requerido.
- Colas, brokers, outbox, inbox o sagas: rechazados; no existe mensajería distribuida ni
  procesamiento asíncrono durable en el alcance.

## 7. Contrato HTTP y errores

**Decision**: `POST` devuelve `201 Created`; errores de entrada devuelven `400` con Validation
Problem Details. `GET` devuelve `200` o `404` con Problem Details. Un identificador malformado o
desconocido se trata como ausencia de coincidencia exacta y devuelve `404`. Los fallos inesperados
devuelven `500` mediante el handler transversal.

**Rationale**: El mapeo refleja los resultados funcionales. Aceptar el parámetro de consulta como
string evita que el binder convierta un identificador incompleto en un `400` antes de aplicar
FR-013. El contrato no declara `401`, `403` ni `409` porque no hay autenticación, autorización ni
conflicto por contenido duplicado.

**Alternatives considered**:

- `200` al crear: rechazado; `201` expresa mejor la creación y permite `Location`.
- `400` para UUID malformado: rechazado; la especificación exige que identificadores incompletos o
  alterados informen que no existe coincidencia.
- Exponer excepciones de EF Core: rechazado; filtra detalles internos y acopla el contrato.

Los fallos conocidos se traducen en `ContactRequests.Presentation`; el fallback inesperado vive en
`Common.Presentation`, que no referencia proyectos `Modules.*`. Todos usan `IExceptionHandler`,
`AddProblemDetails()` y un `traceId` seguro.

## 8. Configuración y observabilidad

**Decision**: Integrar Serilog, OpenTelemetry, HealthChecks y Azure App Configuration en el
composition root. El provider remoto se agrega con `DefaultAzureCredential` solo cuando
`AzureAppConfiguration:Endpoint` contiene una URI absoluta configurada externamente.

**Rationale**: Proporciona logs estructurados, trazas/métricas, señal de salud y configuración
central sin hacer que restore, build o unit tests locales dependan de Azure. No se habilita refresh,
por lo que no son necesarios `AddAzureAppConfiguration()` en servicios ni
`UseAzureAppConfiguration()`.

**Alternatives considered**:

- Connection string o credencial hardcoded: rechazadas por seguridad.
- Activación obligatoria aun sin endpoint: rechazada; rompería el flujo local reproducible.
- Refresh complejo: rechazado; no hay requisito de actualización dinámica.
- Collectors, dashboards o recursos Azure: rechazados; pertenecen a infraestructura externa fuera
  de esta fase.

Logs, trazas y métricas no contendrán nombre, correo, asunto, mensaje, secretos ni tokens. Se usarán
identificador, operación, resultado, duración y `traceId` con cardinalidad controlada.

## 9. Pruebas y coverage

**Decision**: Crear únicamente unit tests xUnit con Coverlet y exigir al menos 80% de line coverage
sobre la lógica de Domain y Application.

**Rationale**: Las reglas de normalización, validación, creación siempre nueva, consulta exacta,
not-found y coordinación con el repositorio pueden probarse con fakes en memoria sin SQL Server,
red ni Azure.

**Alternatives considered**:

- Integration o performance tests: rechazados; están explícitamente fuera del alcance V1.
- Tests de bootstrap, DTOs o OpenAPI para inflar coverage: rechazados; no prueban lógica con riesgo.
- TDD obligatorio: rechazado; la constitución permite decidir el orden.

## 10. Contrato y tooling reproducible

**Decision**: Mantener OpenAPI 3.1 en `contracts/openapi.yaml` y validarlo con
`npx --yes @redocly/cli@2.41.1 lint`.

**Rationale**: La versión fija de Redocly vuelve reproducible el gate estructural sin imponer
contract-first. La equivalencia final entre contrato e implementación se comprobará por revisión
de rutas, mensajes, schemas, status codes y handlers durante `implement` y `converge`.

**Alternatives considered**:

- `@latest`: rechazado; produce resultados no reproducibles.
- Instalación global o proyecto Node completo: rechazados; agregan estado innecesario.
- Tratar lint como prueba runtime: rechazado; Redocly no demuestra equivalencia con el código.

Prerequisitos: npm `>=10` y Node.js `>=22.12.0` o `>=20.19.0 <21.0.0`.

## Research Resolution

Todas las decisiones técnicas necesarias para Phase 1 están resueltas. No quedan aclaraciones
técnicas pendientes ni desviaciones de la constitución.
