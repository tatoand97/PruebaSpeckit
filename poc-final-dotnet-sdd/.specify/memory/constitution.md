<!--
Sync Impact Report
- Version change: template -> 1.0.0
- Modified principles: none; initialized from dotnet-sdd 1.0.1 baseline
- Added sections: none
- Removed sections: none
- Templates requiring updates:
  - ✅ .specify/templates/spec-template.md plus resolved preset addendum
  - ✅ resolved dotnet-sdd plan-template
  - ✅ resolved dotnet-sdd tasks-template
- Follow-up TODOs: none
-->
# ContactRequests Constitution

## Core Principles

### I. Specification First

Toda funcionalidad de producción DEBE partir de una especificación suficiente antes de su
implementación. `spec.md` define qué y por qué se construye, `plan.md` define cómo se construirá y
`tasks.md` define el trabajo ejecutable. Los descubrimientos que cambien requisitos, restricciones
o decisiones DEBEN reflejarse en el artefacto correspondiente. El código NO PUEDE modificar
silenciosamente la intención para hacerla coincidir con la implementación.

Rationale: separar intención, diseño y ejecución conserva trazabilidad y permite detectar
desviaciones antes de convertirlas en deuda.

### II. DDD Modular Boundaries and Clean Architecture

La solución DEBE ser un monolito modular. Los módulos DEBEN representar capacidades o límites
reales del dominio identificados mediante DDD; NO PUEDEN inventarse por conveniencia técnica. Cada
módulo DEBE contener proyectos `Domain`, `Application`, `Infrastructure` y `Presentation`, con sus
unit tests bajo `Tests`.

Las dependencias DEBEN apuntar en las direcciones autorizadas:

- `Domain` PUEDE depender de `Common.Domain` y NO PUEDE depender de Application,
  Infrastructure, Presentation o Api.
- `Application` DEBE depender de Domain y NO PUEDE conocer infraestructura concreta ni
  Presentation.
- `Infrastructure` DEBE depender de Application y `Common.Infrastructure`, y PUEDE depender de
  Domain cuando sea necesario.
- `Module.Presentation` PUEDE depender de Infrastructure, Application y Domain del mismo módulo
  cuando necesite componerlo o traducir sus fallos públicos, además de `Common.Presentation`, pero
  NO PUEDE acceder directamente a persistencia ni referenciar capas de otro módulo.
- `Common.Presentation` NO PUEDE referenciar ningún proyecto `Modules.<Module>.*`.
- `<ProjectName>.Server` DEBE actuar como composition root y referenciar
  `Common.Presentation` y los proyectos `Module.Presentation`.

Los nombres de solución, assemblies y namespaces DEBEN provenir del aplicativo; el preset NO
agrega automáticamente prefijos de una empresa u organización.

Rationale: límites explícitos mantienen cohesión de dominio y evitan acoplar casos de uso a
frameworks o detalles técnicos.

### III. Simplicity and Justified Abstractions

Dentro de las cuatro capas obligatorias, cada feature DEBE usar el diseño más simple que satisfaga
los requisitos. Toda abstracción, interfaz, factory, service, wrapper, base class, mapper, DTO,
domain event o value object adicional DEBE responder a una necesidad concreta y quedar justificada
cuando no sea evidente. NO se crean generic repositories, CQRS ceremonial ni tipos vacíos por el
solo hecho de aplicar Clean Architecture.

Rationale: la estructura protege límites; la complejidad interna sin necesidad solo aumenta el
costo de cambio.

### IV. .NET Application Baseline

La plataforma DEBE ser .NET 10 con la versión de C# correspondiente, nullable reference types e
implicit usings habilitados. Las APIs DEBEN usar ASP.NET Core Minimal APIs. Wolverine DEBE ser el
único mecanismo de mediación entre Presentation y los handlers de Application, configurado con
`DurabilityMode.MediatorOnly`.

El Repository Pattern es obligatorio para acceso a persistencia desde Application. Solo
Infrastructure PUEDE usar EF Core, SQL Server, MongoDB, `DbContext` o drivers concretos. Cuando se
requiera persistencia, `plan.md` DEBE justificar EF Core con SQL Server o EF Core con MongoDB; NO
PUEDE elegir un motor arbitrariamente ni incorporar ambos sin necesidad.

Esta V1 NO usa EF Core Migrations ni su tooling. El versionado, creación, actualización y
despliegue del esquema físico están fuera del alcance del preset. La implementación NO PUEDE
generar directorios de migrations, snapshots o comandos `dotnet-ef`, ni convertir
`EnsureCreated()` en una política alternativa. Esta exclusión no elimina `DbContext`,
configuraciones de entidades ni repositories cuando la persistencia los requiera.

FluentValidation DEBE aplicarse donde exista validación de entrada o del caso de uso.

Rationale: una línea base coherente permite reutilizar conocimiento y proteger los límites sin
convertir Wolverine en infraestructura de mensajería distribuida.

### V. HTTP Contracts and Standardized Errors

Todo endpoint DEBE permanecer delgado, delegar a Wolverine, documentar sus respuestas y aparecer en
el contrato OpenAPI. Toda feature HTTP DEBE mantener `contracts/openapi.yaml` dentro de sus
artefactos y cerrar con consistencia entre `spec.md`, `plan.md`, OpenAPI e implementación. Se
permite tanto diseñar el contrato antes del código como ajustarlo durante la implementación; no se
impone contract-first.

La validación estática de ese contrato DEBE ejecutarse con Redocly CLI `2.41.1` mediante
`npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml` y finalizar con código
cero. NO se permite `@latest`, una instalación global no versionada ni reemplazar este gate por
pruebas runtime. Redocly valida estructura y reglas OpenAPI; `implement` y `converge` DEBEN
comprobar separadamente la consistencia entre contrato e implementación.

El manejo de excepciones DEBE usar `IExceptionHandler`, `AddProblemDetails()` y Problem Details en
todos los handlers. `Common.Presentation` DEBE manejar exclusivamente el fallback inesperado o
transversal y producir 500 sin conocer tipos de ningún módulo. Cada `Module.Presentation` DEBE
traducir los fallos conocidos de su propio dominio y casos de uso. El mapeo base es validación 400,
no autenticado 401, no autorizado 403, no encontrado 404 y conflicto de negocio 409, salvo
justificación funcional. Está prohibido referenciar Domain, Application, Infrastructure o
Presentation de un módulo desde `Common.Presentation` para resolver ese mapeo.

Las respuestas NO PUEDEN exponer stack traces, connection strings, SQL, secretos, tokens o detalles
internos sensibles. Los detalles técnicos pertenecen a observabilidad; los errores de validación
PUEDEN incluir `errors` y las respuestas DEBEN incluir correlación o trace cuando corresponda.

Rationale: contratos verificables y errores uniformes reducen ambigüedad para consumidores sin
filtrar información operativa.

### VI. Meaningful Unit Testing

Esta etapa DEBE producir únicamente unit tests con xUnit y Coverlet. La lógica de negocio DEBE
alcanzar al menos 80% de line coverage, priorizando Domain y Application. Los tests DEBEN probar
comportamiento significativo; NO se generan pruebas artificiales para elevar el porcentaje.

DTOs sin lógica, `Program.cs`, configuración DI, código generado, assembly markers, bootstrap
trivial y archivos OpenAPI NO necesitan coverage artificial. Si una regla de negocio vive
legítimamente en otra capa, DEBE probarse allí. TDD NO es obligatorio: el plan decide el orden de
implementación y pruebas.

Rationale: el coverage es una señal sobre lógica con riesgo, no una meta que justifique tests sin
valor.

### VII. Observability, Safety, and Reproducibility

El plan DEBE considerar y aplicar según corresponda Serilog, OpenTelemetry y HealthChecks conforme
al estándar existente. Además, toda aplicación ASP.NET Core DEBE integrar Azure App Configuration
en código con `Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`,
`AddAzureAppConfiguration(...)`, un endpoint suministrado por configuración externa y
`DefaultAzureCredential` como autenticación preferida. El provider remoto DEBE activarse solo
cuando exista el endpoint requerido, para que restore, build y unit tests locales no dependan de
Azure. La ausencia de conectividad o de un recurso Azure NO convierte la integración en opcional
ni permite marcarla `N/A`. Las credenciales y connection strings hardcoded están prohibidas.

`AddAzureAppConfiguration()` en servicios y `UseAzureAppConfiguration()` DEBEN agregarse solo si
el diseño adopta refresh que los requiera; esta V1 no impone refresh complejo. Los logs y trazas NO
PUEDEN incluir secretos, tokens o información sensible innecesaria. Esta etapa NO crea collectors,
dashboards, infraestructura externa, recursos Azure, credenciales, secretos ni pipelines.

Restore, build Release, unit tests y coverage DEBEN poder reproducirse mediante comandos
documentados. El build Release DEBE terminar con cero errores y cero warnings .NET. No se puede
marcar una tarea como completa sin la evidencia que exige.

Rationale: diagnóstico seguro y validación reproducible son parte del producto, no pasos manuales
ocultos.

## Development Workflow

El flujo de referencia es:

```text
constitution
-> specify
-> clarify cuando aporte valor
-> plan
-> checklist cuando aporte valor
-> tasks
-> analyze cuando aporte valor
-> implement
-> converge
```

`clarify`, `checklist` y `analyze` son controles de calidad y NO son ceremonia obligatoria para
cambios pequeños de bajo riesgo. Antes de implementar una feature DEBEN existir una especificación,
un plan y un desglose de tareas suficientes.

Este preset NO introduce orquestación multiagente ni agentes adicionales. Una marca de trabajo
paralelizable solo describe dependencias entre tareas y no autoriza por sí misma a delegar contexto.

Una feature NO se considera completa hasta que:

- todas sus tasks estén completadas con evidencia;
- `dotnet restore` y `dotnet build -c Release` pasen con cero errores y cero warnings;
- todos los unit tests pasen y la lógica de negocio alcance 80% de line coverage con xUnit y
  Coverlet;
- exista un OpenAPI consistente cuando exponga HTTP y Redocly CLI `2.41.1` finalice con código
  cero;
- se respeten DDD, las cuatro capas, sus dependencias, Repository Pattern, Wolverine mediator,
  Minimal APIs, FluentValidation y Problem Details;
- los estándares aplicables de Serilog, OpenTelemetry y HealthChecks estén cubiertos;
- Azure App Configuration esté integrado en código sin secretos hardcoded;
- los fallos conocidos pertenezcan a `Module.Presentation` y el fallback inesperado a
  `Common.Presentation`; y
- `speckit.converge` finalice sin brechas pendientes.

Sonar, Veracode, SAST, DAST, performance testing, integration testing, CI/CD, deployment,
provisioning de recursos Azure y versionado o despliegue del esquema físico pertenecen a etapas
posteriores del SDLC. Esta V1 NO genera ni ejecuta esos controles, aunque los requisitos de
seguridad, calidad y performance DEBEN seguir especificándose cuando correspondan.

## Governance

Esta Constitution prevalece sobre instrucciones y prácticas de menor nivel que entren en
conflicto. Una constitución de proyecto PUEDE agregar reglas específicas, pero NO PUEDE debilitar
ni contradecir esta línea base obligatoria.

Toda excepción DEBE estar ligada a un requisito, riesgo o restricción concreta, documentarse en
`plan.md` y aprobarse mediante el proceso de gobierno aplicable. Una desviación no documentada
bloquea el Definition of Done.

Los cambios DEBEN proponer motivación e impacto, actualizar la versión con Semantic Versioning y
propagar sus efectos a templates y documentación. Un cambio incompatible con la arquitectura o
metodología fundamental requiere MAJOR; una capacidad compatible nueva requiere MINOR; una
corrección o aclaración del comportamiento esperado de la V1 requiere PATCH. Cada revisión DEBE
comprobar los principios aplicables y la evidencia local.

**Version**: 1.0.0 | **Ratified**: 2026-07-29 | **Last Amended**: 2026-07-29
