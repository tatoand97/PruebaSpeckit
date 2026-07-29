# Research: Crear y consultar órdenes

## R1. Límite de dominio

**Decision**: Crear un único módulo DDD `Orders`.

**Rationale**: La feature solo administra el agregado orden. Cliente y producto son identificadores
opacos sin validación externa, por lo que no constituyen capacidades del sistema.

**Alternatives considered**:

- Módulos `Customers` y `Products`: rechazados porque inventarían capacidades y dependencias
  ausentes del alcance.
- Un módulo técnico `Persistence`: rechazado porque los módulos representan dominio, no tecnología.

## R2. Interfaz

**Decision**: Exponer `POST /orders` y `GET /orders/{orderId}` mediante ASP.NET Core Minimal APIs.

**Rationale**: La especificación necesita una interfaz de servicio programática con dos operaciones;
la Constitution establece Minimal APIs como baseline y exige contratos OpenAPI para HTTP.

**Alternatives considered**:

- CLI: no representa adecuadamente una interfaz de servicio concurrente.
- API MVC con controllers: agrega un modelo de presentación distinto al Minimal API obligatorio.

## R3. Mediación

**Decision**: Usar WolverineFx 6.24.0 exclusivamente como mediator con
`DurabilityMode.MediatorOnly`.

**Rationale**: Es la baseline obligatoria del preset y conserva endpoints delgados sin introducir
mensajería distribuida.

**Alternatives considered**:

- Llamar handlers directamente: rompe el flujo requerido.
- Colas, durable messaging u outbox: no existe requisito y están fuera de alcance.

## R4. Persistencia

**Decision**: EF Core 10.0.10 con SQL Server y una implementación específica de
`IOrderRepository`.

**Rationale**: La orden tiene estructura estable, una colección con duplicados prohibidos, escritura
atómica y consulta exacta por identificador. Una transacción relacional cubre esas necesidades de
forma directa.

**Alternatives considered**:

- EF Core con MongoDB: no hay esquema variable, consultas documentales ni necesidad de un modelo
  documental.
- Memoria o archivos: no son opciones soportadas por la baseline para persistencia requerida y no
  representan una solución durable.
- Generic repository: oculta operaciones de dominio y agrega superficie no requerida.

## R5. Identidad y tiempo

**Decision**: Generar `Guid` nuevo por cada solicitud válida y usar `TimeProvider` para obtener
`DateTimeOffset` UTC.

**Rationale**: Un GUID permite consultas exactas y unicidad sin coordinación entre requests. El
`TimeProvider` incluido en .NET permite pruebas deterministas sin crear una interfaz de reloj.

**Alternatives considered**:

- Identificador secuencial expuesto: requiere coordinación con persistencia y no aporta valor de
  negocio.
- Interfaz `IClock` propia: sería una abstracción redundante frente a `TimeProvider`.

## R6. Validación y atomicidad

**Decision**: FluentValidation valida forma y presencia en Application; el dominio protege la
invariante de productos duplicados. El handler valida y construye el agregado completo antes de
invocar una única escritura del repositorio.

**Rationale**: Se identifican todos los datos inválidos antes de persistir y el dominio no puede
existir en estado inválido. El producto duplicado se devuelve de forma segura en los errores.

**Alternatives considered**:

- Validar solo en el endpoint: acopla reglas a HTTP y permite otros entry points inválidos.
- Guardar líneas una a una: permitiría resultados parciales y viola FR-006.

## R7. Errores HTTP

**Decision**: Un fallback común `IExceptionHandler` genera el 500 inesperado y un
`OrdersExceptionHandler` registrado en Presentation genera 400/404 para excepciones que pertenecen
al módulo. `AddProblemDetails()` conserva el formato, con `errors` y `traceId`.

**Rationale**: Centraliza el estándar sin hacer que `Common.Presentation` dependa de excepciones de
Orders, evita repetición en endpoints y previene exposición de detalles técnicos.

**Alternatives considered**:

- `try/catch` por endpoint: duplica mapeos y facilita inconsistencias.
- Un único handler Common para tipos Orders: invertiría dependencias entre Common y el módulo.
- 409 para duplicados: el duplicado es una solicitud inválida definida por FR-014, no un conflicto
  con estado preexistente.

## R8. Estándares transversales

**Decision**: Configurar Serilog de consola, OpenTelemetry para ASP.NET Core/HttpClient y un
HealthCheck del `OrdersDbContext`. Azure App Configuration es N/A.

**Rationale**: Logging, trazas/métricas y salud de la dependencia persistente son aplicables. No hay
un estándar remoto previo ni una integración externa permitida que justifique Azure App
Configuration; los secretos se obtendrán del entorno/configuración local.

**Alternatives considered**:

- Collector, dashboard o recurso Azure: infraestructura externa excluida.
- Registrar bodies o identificadores de cliente/producto: riesgo de exposición sin necesidad
  diagnóstica.

## R9. Pruebas y cobertura

**Decision**: Un proyecto xUnit referencia únicamente Domain y Application; Coverlet MSBuild mide y
aplica un umbral total de 80% de líneas sobre esos proyectos.

**Rationale**: Delimita la lógica de negocio y evita exigir cobertura artificial a bootstrap,
contratos, EF, migrations u OpenAPI.

**Alternatives considered**:

- Integration tests con SQL Server: gate posterior excluido.
- Cubrir todos los proyectos: incentiva pruebas sin comportamiento sobre configuración y DTOs.
- TDD obligatorio: el preset lo deja como decisión y no es necesario para esta PoC.

## R10. Tooling reproducible

**Decision**: Versionar `dotnet-ef` 10.0.10 en `.config/dotnet-tools.json`, aislar las versiones
NuGet en un `Directory.Packages.props` propio y validar OpenAPI 3.1 con
`npx --yes @redocly/cli@2.41.1 lint`.

**Rationale**: La migración, los paquetes y el lint deben poder repetirse sin depender de
herramientas globales o de archivos del repositorio padre. Redocly se ejecuta con versión fija y no
agrega runtime, pipeline ni archivos Node al producto.

**Alternatives considered**:

- `dotnet ef` global: la versión depende de la máquina y no satisface reproducibilidad.
- PyYAML: no está disponible en el entorno y solo comprueba YAML, no reglas OpenAPI.
- Crear un proyecto de validación propio: agrega código y dependencias para un control de tooling.
