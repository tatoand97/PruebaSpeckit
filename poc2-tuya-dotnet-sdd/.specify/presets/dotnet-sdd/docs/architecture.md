# Arquitectura de referencia

## Alcance

Esta arquitectura aplica inicialmente a aplicaciones greenfield en .NET 10 construidas como
monolitos modulares. Los módulos se obtienen de capacidades y límites reales del dominio mediante
Domain-Driven Design (DDD); no se crean módulos para agrupar detalles técnicos.

El nombre raíz de la solución, los assemblies y los namespaces proviene del aplicativo. El preset
no agrega automáticamente prefijos de una empresa u organización.

## Estructura

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

Cada módulo contiene las cuatro capas aunque una feature pequeña use muy pocos tipos dentro de
ellas. La estructura obligatoria no autoriza a crear servicios vacíos, interfaces de un solo uso,
wrappers triviales, factories, base classes, mappers o DTO duplicados sin una necesidad concreta.

## Dirección de dependencias

| Proyecto | Puede referenciar | No puede referenciar |
|---|---|---|
| `Domain` | `Common.Domain` | `Application`, `Infrastructure`, `Presentation`, `Api` |
| `Application` | `Domain` | Infraestructura concreta, `Presentation` |
| `Infrastructure` | `Application`, `Common.Infrastructure` y `Domain` solo cuando sea necesario | `Presentation`, `Api` |
| `Presentation` | `Infrastructure`, `Common.Presentation` | Acceso directo a persistencia |
| `<ProjectName>.Server` | `Common.Presentation`, cada `Module.Presentation` | Lógica de negocio propia |

`Domain` contiene conceptos y comportamiento del dominio: entities, value objects, domain services,
excepciones, eventos y abstracciones de repositorio solo cuando correspondan naturalmente.

`Application` contiene casos de uso, commands, queries, handlers, validators, contratos y DTOs con
utilidad real. No conoce SQL Server, MongoDB, `DbContext` ni otro detalle concreto.

`Infrastructure` implementa persistencia y adapters técnicos. El Repository Pattern es obligatorio
para el acceso a persistencia desde Application; no se crean generic repositories por defecto.

`Presentation` contiene Minimal API endpoints, contratos HTTP y mapeo del módulo. Permanece delgada:
no contiene reglas de negocio, no usa repositories o contextos de datos y no llama handlers de
Application directamente.

`<ProjectName>.Server` es el composition root que registra los componentes compartidos y compone
los módulos.

## Flujo de una operación

```text
Minimal API
  -> Presentation
  -> Wolverine mediator
  -> Application handler
  -> Domain
  -> Repository abstraction
  -> Infrastructure implementation
```

Wolverine se usa exclusivamente como mediator con `DurabilityMode.MediatorOnly`. Esta V1 no
introduce colas, brokers, outbox, inbox, sagas ni durable messaging.

## Persistencia

Las opciones soportadas son:

- EF Core con SQL Server.
- EF Core con MongoDB.

El plan debe elegir una sola opción cuando la feature necesite persistencia y justificarla con
requisitos de consistencia, consultas, modelo de datos, operación y contexto existente. No se
selecciona un motor por preferencia ni se agregan ambos sin una necesidad verificable.

Application usa abstracciones de repositorio. Solo Infrastructure conoce el proveedor, el contexto
y su configuración concreta.

## API, contratos y errores

Las APIs usan ASP.NET Core Minimal APIs y delegan a Wolverine. Para toda feature HTTP debe existir
`contracts/openapi.yaml` dentro del directorio de artefactos de la feature. El contrato cubre
operaciones, respuestas exitosas y errores relevantes, y al cierre es consistente con `spec.md`,
`plan.md` y la implementación. El preset no impone contract-first.

El manejo global usa `IExceptionHandler` y `AddProblemDetails()`. La clasificación base es:

| Condición | HTTP |
|---|---:|
| Error de validación | 400 |
| No autenticado | 401 |
| No autorizado | 403 |
| Recurso no encontrado | 404 |
| Conflicto de negocio | 409 |
| Error inesperado | 500 |

El contrato funcional puede justificar otro status. Las respuestas no exponen stack traces,
connection strings, SQL, secretos, tokens ni detalles internos sensibles. Los errores de
validación pueden incluir la extensión `errors`; se incluye un identificador de correlación o trace
cuando corresponda.

## Estándares transversales

El plan evalúa y aplica según el contexto:

- FluentValidation para validación de entrada o del caso de uso.
- Serilog para logging estructurado.
- OpenTelemetry para trazas y métricas.
- HealthChecks para dependencias relevantes.
- Azure App Configuration para configuración centralizada.

No se crean collectors, dashboards, recursos Azure ni infraestructura externa como parte de esta
V1. Nunca se registran secretos, tokens o información sensible innecesaria.
