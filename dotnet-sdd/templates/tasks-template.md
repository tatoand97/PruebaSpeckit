---
description: "Lista de tareas para una feature de monolito modular .NET 10"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: `plan.md` y `spec.md` son obligatorios; use `research.md`, `data-model.md`,
`contracts/` y `quickstart.md` cuando existan.

**Testing**: Genere únicamente unit tests con xUnit. Incluya los tests significativos necesarios
para la lógica de negocio y el objetivo de 80% de line coverage con Coverlet. TDD no es
obligatorio; el orden sigue la estrategia definida en `plan.md`.

**Organization**: Agrupe el trabajo por user story para preservar entregas y validaciones
independientes. Genere solo las tareas que la feature necesita.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Puede ejecutarse en paralelo porque usa archivos distintos y no depende de trabajo
  incompleto.
- **[Story]**: User story propietaria (`[US1]`, `[US2]`, etc.); se exige en las fases de stories.
- Cada descripción debe incluir una ruta de archivo exacta o un comando/evidencia exactos.
- Una tarea se marca `[X]` únicamente cuando exista su evidencia.

## Path Conventions

```text
Api/<ProjectName>.Server/
Common/Common.Domain/
Common/Common.Infrastructure/
Common/Common.Presentation/
Modules/<DDDModule>/Domain/
Modules/<DDDModule>/Application/
Modules/<DDDModule>/Infrastructure/
Modules/<DDDModule>/Presentation/
Modules/<DDDModule>/Tests/<Module>.Test/
specs/<feature>/contracts/openapi.yaml
```

Use los nombres y rutas concretos de `plan.md`. No agregue prefijos de una empresa u organización
al nombre raíz.

<!--
  INSTRUCCIONES PARA GENERACIÓN

  Reemplace todo el contenido de ejemplo por tareas concretas. Antes de escribirlas:

  1. Mapee cada user story y requisito a módulos DDD reales.
  2. Extraiga la asignación Domain/Application/Infrastructure/Presentation del plan.
  3. Respete la dirección de dependencias y el flujo Presentation -> Wolverine -> Application.
  4. Para persistencia, use las abstracciones e implementaciones específicas justificadas.
  5. Si existe HTTP, mapee cada operación/error de contracts/openapi.yaml a tareas de
     implementación, Redocly lint y consistencia.
  6. Asigne fallos conocidos a Module.Presentation y el fallback inesperado a
     Common.Presentation sin referencias hacia módulos.
  7. Incluya la integración de código obligatoria con Azure App Configuration.
  8. Incluya unit tests significativos y evidencia de coverage.
  9. Incluya las validaciones locales finales.

  No conserve placeholders ni tareas ilustrativas en el tasks.md generado.
-->

## Phase 1: Setup

**Purpose**: Crear o ajustar únicamente la base compartida requerida por la feature.

Ejemplos de forma; reemplace o elimine según `plan.md`:

- [ ] T001 Crear los proyectos y referencias estrictamente necesarios descritos en `[exact path]`
- [ ] T002 [P] Configurar .NET 10, nullable e implicit usings en `[exact project/props path]`
- [ ] T003 [P] Agregar solo las dependencias aprobadas por el plan en `[exact project/props path]`

**Checkpoint**: El esqueleto requerido existe sin módulos ni abstracciones artificiales.

---

## Phase 2: Foundational

**Purpose**: Implementar los prerrequisitos que bloquean todas las stories.

Genere solo los fundamentos compartidos que realmente sean necesarios, por ejemplo:

- composición del módulo y del Server;
- configuración Wolverine `DurabilityMode.MediatorOnly`;
- handlers del módulo para fallos conocidos y fallback transversal en `Common.Presentation`, todos
  con `IExceptionHandler` y Problem Details;
- integración de Azure App Configuration con endpoint externo y `DefaultAzureCredential`, activa
  solo cuando el endpoint esté presente;
- configuración transversal aplicable;
- abstracciones específicas de persistencia que varias stories compartan.

No convierta cada tecnología estándar en una tarea si ya está correctamente configurada y la
feature no requiere cambios.

- [ ] T00X [Acción concreta y ruta exacta]

**Checkpoint**: Las stories pueden implementarse sin violar dependencias de arquitectura.

---

## Phase 3: User Story 1 - [TITLE] (Priority: P1)

**Goal**: [Valor observable entregado]

**Independent Test**: [Cómo comprobar el comportamiento de esta story de forma aislada]

### Unit Tests for User Story 1

Incluya pruebas de reglas, branches y fallos significativos. No genere integration, contract o
performance tests. Si la story no contiene lógica nueva, explique por qué no requiere un test en
vez de crear uno artificial.

- [ ] T00X [P] [US1] Probar [comportamiento] con xUnit en `Modules/<Module>/Tests/<Module>.Test/[file].cs`

### Implementation for User Story 1

Ordene solo las tareas aplicables:

- Domain: reglas y conceptos con significado real.
- Application: caso de uso, message/handler, validación y contratos útiles.
- Infrastructure: implementación del repository o adapter concreto.
- Presentation: Minimal API delgada que delega a Wolverine.
- OpenAPI: operación, respuestas exitosas y errores relevantes.

- [ ] T00X [US1] [Acción concreta y ruta exacta]

**Checkpoint**: US1 es funcional y sus unit tests pasan de forma independiente.

---

## Phase 4: User Story 2 - [TITLE] (Priority: P2)

**Goal**: [Valor observable entregado]

**Independent Test**: [Validación independiente]

### Unit Tests for User Story 2

- [ ] T00X [P] [US2] Probar [comportamiento] con xUnit en `Modules/<Module>/Tests/<Module>.Test/[file].cs`

### Implementation for User Story 2

- [ ] T00X [US2] [Acción concreta y ruta exacta]

**Checkpoint**: US1 y US2 funcionan y pueden validarse independientemente.

---

[Agregue una fase por cada user story real siguiendo el mismo patrón.]

---

## Final Phase: Local Verification and Cross-Cutting Completion

**Purpose**: Producir evidencia del Definition of Done local antes de convergencia.

Genere tareas concretas, sin duplicar verificaciones ya cubiertas:

- [ ] T0XX Ejecutar `dotnet restore` desde `[solution path]` y registrar resultado exitoso
- [ ] T0XX Ejecutar `dotnet build -c Release` desde `[solution path]` y registrar cero errores y cero warnings .NET
- [ ] T0XX Ejecutar todos los unit tests xUnit mediante `[exact command]` y registrar el resultado
- [ ] T0XX Medir con Coverlet al menos 80% de line coverage sobre `[business-logic scope]` mediante `[exact command]`
- [ ] T0XX Auditar referencias de proyectos y flujo Wolverine contra Architecture Compliance en `specs/[feature]/plan.md`
- [ ] T0XX Ejecutar `npx --yes @redocly/cli@2.41.1 lint specs/[feature]/contracts/openapi.yaml` y registrar exit code cero [eliminar si no hay HTTP]
- [ ] T0XX Comparar `specs/[feature]/contracts/openapi.yaml` con endpoints y errores HTTP implementados [eliminar si no hay HTTP]
- [ ] T0XX Validar Problem Details y el ownership Module/Common de excepciones en `[exact paths]`
- [ ] T0XX Validar la integración de Azure App Configuration, activación condicional por endpoint y ausencia de secretos hardcoded en `[exact paths]`
- [ ] T0XX Validar los demás estándares transversales aplicables en `[exact paths]`
- [ ] T0XX Registrar la evidencia local final en `[feature artifact or agreed evidence path]`

`speckit.converge` se ejecuta después de `speckit.implement`; no lo convierta en una tarea circular.
Si converge encuentra brechas, él agrega una nueva fase y se vuelve a ejecutar implement.

## Dependencies and Execution Order

Documente:

- dependencias entre Setup, Foundational y cada user story;
- dependencias reales entre stories, evitando acoplamientos innecesarios;
- orden dentro de cada story según Domain, Application, Infrastructure, Presentation y contrato;
- qué tareas `[P]` operan en archivos distintos; y
- que trabajo sobre un mismo archivo es secuencial.

No interprete `[P]` como autorización para introducir orquestación multiagente.

## Requirement Coverage

| Requirement / Acceptance | Task IDs | Evidence |
|---|---|---|
| [FR/NFR/US acceptance] | [T###] | [Test, contract, file or command] |

Cada requisito construible y cada criterio de aceptación debe tener al menos una tarea trazable.

## Scope Guard

Este `tasks.md` NO debe incluir tareas para:

- Sonar o Veracode;
- SAST o DAST;
- performance testing;
- integration testing;
- CI/CD;
- deployment;
- collectors, dashboards, recursos Azure o infraestructura externa;
- versionado, creación, actualización o despliegue del esquema físico de base de datos;
- EF Core Migrations, `dotnet-ef`, snapshots, database update o `EnsureCreated()` como política;
- colas, brokers, outbox, inbox, sagas o durable messaging; ni
- abstracciones sin una necesidad trazable.

Los requisitos de seguridad, calidad y performance siguen siendo válidos; sus gates especializados
se ejecutan en etapas posteriores del SDLC.

## Completion Evidence

Al finalizar, resuma:

- tasks completadas y cualquier bloqueo;
- comandos de restore/build/test/coverage y resultados;
- cobertura obtenida y alcance medido;
- resultado de arquitectura, Redocly lint y consistencia OpenAPI;
- integración de Azure App Configuration, ownership de excepciones y demás puntos transversales; y
- siguiente paso: `speckit.converge`.
