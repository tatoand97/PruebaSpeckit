# .NET SDD

Preset reutilizable de GitHub Spec Kit para aplicar un estándar de desarrollo .NET sin acoplarlo a
una empresa, sin hacer fork ni modificar archivos core.

## Purpose

`dotnet-sdd` personaliza el workflow SDD oficial con:

- principios de ingeniería permanentes;
- arquitectura de monolito modular basada en DDD y Clean Architecture;
- .NET 10, Minimal APIs y Wolverine como mediator;
- Repository Pattern y selección justificada de persistencia;
- OpenAPI validado estáticamente con Redocly CLI y Problem Details para features HTTP;
- ownership modular de errores conocidos y fallback HTTP transversal;
- integración de código obligatoria con Azure App Configuration;
- unit testing con xUnit, Coverlet y 80% de line coverage sobre lógica de negocio; y
- un Definition of Done local reproducible.

El preset usa únicamente templates y command composition soportados por Spec Kit. No crea una
metodología paralela, agentes, workflows, extensions ni infraestructura.

## Scope

La V1 está dirigida a proyectos greenfield .NET 10 construidos como monolitos modulares. Cada
módulo corresponde a una capacidad o límite DDD real y conserva proyectos Domain, Application,
Infrastructure, Presentation y Tests.

La versión mínima es Spec Kit `0.14.3`. `speckit.converge` apareció antes, pero `0.14.3` contiene el
arreglo necesario para que la integración GitHub Copilot aplique correctamente los command
overrides de presets.

## Architecture

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

El flujo de una operación es:

```text
Minimal API
  -> Presentation
  -> Wolverine mediator
  -> Application handler
  -> Domain
  -> Repository abstraction
  -> Infrastructure implementation
```

El Server es el composition root. Domain solo puede usar `Common.Domain`; Application depende de
Domain; Infrastructure depende de Application y `Common.Infrastructure`;
`Module.Presentation` puede referenciar las capas de su propio módulo y `Common.Presentation` sin
acceder directamente a persistencia. Consulte [Architecture](docs/architecture.md) para la matriz
completa.

`Common.Presentation` solo contiene manejo HTTP transversal y el fallback inesperado a 500. Cada
`Module.Presentation` traduce a Problem Details los fallos conocidos de su propio módulo;
`Common.Presentation` nunca referencia proyectos `Modules.*`.

Toda aplicación generada integra en código Azure App Configuration mediante
`Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`,
`AddAzureAppConfiguration(...)` y `DefaultAzureCredential`, usando un endpoint suministrado por
configuración externa. El provider remoto se registra solo cuando ese endpoint está presente, de
modo que restore, build y unit tests locales no requieren conectividad con Azure. El provisioning
del recurso no pertenece al preset.

El versionado y despliegue del esquema físico quedan fuera de la V1. El preset no usa EF Core
Migrations, `dotnet-ef`, snapshots ni comandos de actualización de base de datos, y tampoco
establece `EnsureCreated()` como política alternativa.

## Install for GitHub Copilot

Ejecute los comandos desde el repositorio consumidor, no desde el directorio fuente del preset.

Requisito:

```powershell
specify version
```

El resultado debe ser `0.14.3` o superior.

La validación OpenAPI requiere npm `>=10` y Node.js `>=22.12.0` o
`>=20.19.0 <21.0.0`, según los engines publicados por Redocly CLI `2.41.1`. No instale Redocly
globalmente ni agregue un proyecto Node a la aplicación solo para este gate.

Inicialice Spec Kit con la integración oficial de GitHub Copilot y scripts PowerShell:

```powershell
specify init --here --integration copilot --script ps
```

Spec Kit `0.14.3` muestra una advertencia porque el layout markdown predeterminado de Copilot está
deprecado, pero el comando anterior sigue siendo válido. El preset permanece agnóstico al layout:
Spec Kit se encarga de materializar sus commands para el modo activo.

Instale el preset desde su ruta absoluta durante desarrollo:

```powershell
specify preset add --dev "C:\ruta\absoluta\dotnet-sdd"
```

Spec Kit materializa los command addenda en el formato de la integración activa. El preset no
hardcodea el directorio interno de commands de GitHub Copilot.

## Verify

Desde el repositorio consumidor:

```powershell
specify preset list
specify preset info dotnet-sdd

specify preset resolve constitution-template
specify preset resolve spec-template
specify preset resolve plan-template
specify preset resolve tasks-template
```

`spec-template` debe mostrar una composition chain. Constitution, plan y tasks deben resolver al
preset como base `replace`. `preset info` debe listar los cinco entries de tipo `command`; Spec Kit
los registra para la integración activa durante la instalación.

La CLI `0.14.3` no expone resolución de commands mediante `preset resolve`; ese subcommand resuelve
los templates que se consultan en runtime. Los commands se componen y materializan al instalar el
preset.

Para una feature HTTP, el gate reproducible de validación estática es:

```powershell
npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml
```

El comando debe salir con código cero. Redocly valida la estructura y las reglas OpenAPI; la
consistencia entre contrato y endpoints implementados se comprueba separadamente durante
`speckit.implement` y `speckit.converge`.

## Composition Strategy

| Artifact | Strategy | Reason |
|---|---|---|
| `constitution-template` | `replace` | El template core es genérico y no puede establecer la línea base obligatoria. |
| `spec-template` | `append` | El core ya mantiene la especificación en qué y por qué; solo se agregan NFR y necesidades de interfaz. |
| `plan-template` | `replace` | Las opciones core de estructura genérica no expresan el monolito modular ni su matriz de dependencias. |
| `tasks-template` | `replace` | Los ejemplos core incluyen integration tests, TDD obligatorio, deploy y commits, todos incompatibles con esta V1. |
| Command addenda | `append` | Conservan el flujo oficial y agregan únicamente las restricciones y verificaciones del preset. |

No se necesita `prepend` ni `wrap` en V1: ningún addendum requiere contenido simultáneo antes y
después del command core.

## Commands Customized

- `speckit.constitution`: protege la línea base del preset frente a cambios contradictorios.
- `speckit.plan`: exige Architecture Compliance y Local Definition of Done.
- `speckit.tasks`: limita el alcance y exige tareas con evidencia local.
- `speckit.implement`: valida arquitectura, unit tests, coverage, build y OpenAPI.
- `speckit.converge`: amplía el inventario oficial sin cambiar su semántica append-only.

Permanecen core:

- `speckit.specify`: ya mantiene `spec.md` centrado en qué y por qué; el addendum de template basta.
- `speckit.clarify`: ya reduce ambigüedad sin imponer decisiones técnicas.
- `speckit.checklist`: ya valida calidad de requisitos y no implementación.
- `speckit.analyze`: ya es read-only, valida Constitution y cruza spec, plan y tasks.

## Expected SDD Flow

```text
constitution
-> specify
-> clarify when valuable
-> plan
-> checklist when valuable
-> tasks
-> analyze when valuable
-> implement
-> converge
```

Si converge agrega tasks, ejecute implement y converge nuevamente. Para features pequeñas y de
bajo riesgo se permite el flujo corto oficial; clarify, checklist y analyze no deben convertirse
en ceremonia sin valor.

## Local Definition of Done

Una feature termina únicamente cuando:

- todas sus tasks tienen evidencia;
- restore y build Release pasan con cero errores y cero warnings .NET;
- los unit tests xUnit pasan y Coverlet demuestra al menos 80% de line coverage de lógica de
  negocio;
- OpenAPI existe para HTTP, Redocly CLI `2.41.1` finaliza con código cero y el contrato coincide
  con endpoints y errores implementados;
- DDD, las cuatro capas, sus dependencias, Repository Pattern, Wolverine mediator y Minimal APIs
  están respetados;
- FluentValidation, Problem Details y los estándares aplicables de Serilog, OpenTelemetry,
  HealthChecks están cubiertos;
- Azure App Configuration está integrado en código, aunque la conectividad y el recurso Azure no
  sean necesarios para el DoD local;
- los errores conocidos pertenecen a `Module.Presentation` y el fallback inesperado a
  `Common.Presentation`;
- no hay secretos hardcoded; y
- `speckit.converge` finaliza sin brechas.

La lista normativa y su evidencia están en [Local Definition of Done](docs/definition-of-done.md).
La estrategia de pruebas está en [Testing](docs/testing.md).

## Out of Scope

Esta V1 no genera ni ejecuta:

- Sonar;
- Veracode;
- SAST;
- DAST;
- performance testing;
- integration testing;
- CI/CD;
- deployment;
- provisioning de recursos Azure;
- versionado o despliegue del esquema físico de base de datos;
- mensajería distribuida; ni
- infraestructura externa.

Esos controles pertenecen a etapas posteriores del SDLC. Los requisitos de seguridad, calidad y
performance siguen siendo válidos cuando correspondan.

## Repository Instructions for GitHub Copilot

[assets/copilot-instructions.md](assets/copilot-instructions.md) es una propuesta separada,
deliberadamente pequeña. Los presets de Spec Kit no instalan repository-wide instructions, por lo
que este asset no está declarado en `preset.yml`.

Para usarlo, cópielo posteriormente al repositorio consumidor:

```powershell
New-Item -ItemType Directory -Force .github | Out-Null
Copy-Item "C:\ruta\absoluta\dotnet-sdd\assets\copilot-instructions.md" `
  ".github\copilot-instructions.md"
```

La distribución organizacional de ese archivo puede gestionarse por un mecanismo separado.

## Development Notes

La V1 fue contrastada con el scaffold y la documentación oficiales de Spec Kit `0.14.3`, incluyendo
composition strategies y la integración activa de GitHub Copilot. El manifest omite `repository` y
`license` porque el remote actual es una PoC y no un repositorio dedicado de distribución del
preset; no se inventa metadata publicable.
