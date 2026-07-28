<!--
Sync Impact Report
- Version change: unversioned template → 1.0.0
- Added principles:
  - I. Specification First
  - II. Simplicity and Justified Architecture
  - III. .NET Engineering Standards
  - IV. Testing and Quality
  - V. Security by Design
  - VI. Observability and Operability
  - VII. Automation and Reproducibility
- Added sections:
  - Development Workflow
  - AI-Assisted Development
- Removed sections: None; template placeholders were replaced with governed content.
- Templates updated:
  - ✅ .specify/templates/plan-template.md
  - ✅ .specify/templates/spec-template.md
  - ✅ .specify/templates/tasks-template.md
- Agent guidance synchronized:
  - ✅ .github/copilot-instructions.md
  - ✅ .github/skills/speckit-specify/SKILL.md
  - ✅ .github/skills/speckit-plan/SKILL.md
  - ✅ .github/skills/speckit-tasks/SKILL.md
  - ✅ .github/skills/speckit-implement/SKILL.md
  - ✅ Remaining installed Spec Kit skills reviewed; no changes required.
- Follow-up TODOs: None.
-->
# PruebaSpeckit Constitution

## Core Principles

### I. Specification First

Toda funcionalidad de producción DEBE partir de una especificación suficiente antes de su
implementación. `spec.md` define qué debe construirse, `plan.md` define cómo se construirá y
`tasks.md` define el trabajo ejecutable.
Todo requisito, restricción o cambio relevante descubierto durante la implementación DEBE
reflejarse explícitamente en los artefactos SDD afectados. Una inconsistencia entre código y
especificación DEBE resolverse de forma explícita; el código nunca PUEDE sustituir silenciosamente
a la especificación como fuente de verdad.

Rationale: mantener la intención separada de la implementación permite revisar alcance, detectar
desviaciones y conservar trazabilidad.

### II. Simplicity and Justified Architecture

Cada solución DEBE comenzar con el diseño más simple que satisfaga los requisitos conocidos. Toda
abstracción, capa, servicio, patrón o dependencia adicional DEBE responder a un requisito, riesgo o
restricción concreta y DEBE quedar justificada en `plan.md`. Clean Architecture, microservicios y
cualquier otro patrón arquitectónico NO son valores predeterminados. Las alternativas más simples
DEBEN evaluarse antes de aceptar complejidad adicional.

Rationale: la complejidad sin una necesidad verificable aumenta el coste de cambio y la superficie
de fallos sin aportar valor demostrado.

### III. .NET Engineering Standards

.NET 10 es la plataforma principal. Las dependencias DEBEN usar versiones soportadas y mantenidas
en el momento de planificar o actualizar la solución. Las capacidades nativas de .NET DEBEN
preferirse cuando satisfagan la necesidad sin una pérdida relevante de funcionalidad o calidad.
Los warnings relevantes del compilador y de los analizadores DEBEN resolverse; toda supresión
necesaria DEBE incluir una justificación explícita y localizada. Los nullable reference types
DEBEN permanecer habilitados, salvo una excepción documentada y justificada en `plan.md`.

Rationale: una base coherente, soportada y con diagnósticos atendidos reduce defectos evitables y
facilita el mantenimiento.

### IV. Testing and Quality

Todo comportamiento de negocio relevante DEBE contar con pruebas automatizadas apropiadas para el
riesgo y el tipo de solución. La corrección de un defecto DEBE incluir una prueba de regresión
cuando sea técnicamente razonable; si no lo es, la razón DEBE documentarse. El build y todas las
pruebas aplicables DEBEN pasar antes de considerar completada una implementación. TDD NO es
obligatorio: `plan.md` DEBE definir la estrategia, los tipos de prueba y los comandos de validación
adecuados para la feature.

Rationale: la evidencia automatizada protege el comportamiento acordado sin imponer un único
método de desarrollo.

### V. Security by Design

La seguridad DEBE considerarse de forma proporcional al riesgo desde `spec.md` y `plan.md`.
Secretos, credenciales y tokens NO PUEDEN almacenarse en el código fuente. Toda entrada que cruce
un límite de confianza DEBE validarse antes de su uso. Identidades, procesos y servicios DEBEN
operar con el mínimo privilegio necesario. Toda decisión que afecte autenticación, autorización,
cifrado o exposición de información DEBE quedar explícita en `plan.md`, junto con sus controles y
supuestos relevantes.

Rationale: tratar la seguridad como una restricción tardía produce controles incompletos y riesgos
difíciles de corregir.

### VI. Observability and Operability

Toda aplicación destinada a producción DEBE diseñarse para que sus fallos y estados relevantes
puedan diagnosticarse. Los eventos operativos DEBEN registrarse mediante logging estructurado.
Los logs NO PUEDEN contener secretos ni información sensible innecesaria. `plan.md` DEBE definir,
según la solución y su riesgo, las necesidades de logs, métricas y trazabilidad, o justificar
explícitamente por qué alguna de ellas no aplica. Esta Constitution NO impone una herramienta o
plataforma de observabilidad concreta.

Rationale: la capacidad de diagnóstico debe diseñarse junto con el sistema, sin acoplar el
repositorio prematuramente a un proveedor.

### VII. Automation and Reproducibility

El build, las pruebas y las validaciones principales DEBEN poder reproducirse mediante comandos
documentados desde un entorno limpio que cumpla los prerrequisitos declarados. Los scripts propios
del repositorio DEBEN preferir PowerShell. Ningún paso manual oculto PUEDE ser necesario para
compilar o probar la solución. Todo script DEBE terminar con un error explícito y un código de
salida distinto de cero cuando falle una validación crítica.

Rationale: la automatización reproducible permite obtener la misma evidencia de calidad en
desarrollo local, revisión y automatización futura.

## Development Workflow

El flujo de referencia es:

constitution
→ specify
→ clarify cuando sea necesario
→ plan
→ checklist cuando aporte valor
→ tasks
→ analyze
→ implement
→ converge

Antes de implementar una feature de producción DEBEN existir especificación, planificación y
desglose de tareas suficientes. Los cambios directos PUEDEN omitir fases solo cuando sean triviales
y no redefinan comportamiento de producción. `clarify`, `checklist` y `analyze` son fases de
calidad: DEBEN ejecutarse cuando la ambigüedad, complejidad o riesgo hagan inseguro omitirlas, y
PUEDEN omitirse en cambios triviales cuando no aporten valor. El workflow NO DEBE convertirse en
ceremonia que retrase cambios simples sin mejorar su evidencia o control.

## AI-Assisted Development

GitHub Copilot es el coding agent principal de este repositorio. El uso de IA NO elimina la
responsabilidad de revisar las decisiones técnicas, el código generado y la evidencia de build y
pruebas. El contexto proporcionado al modelo DEBE mantenerse tan pequeño como sea razonable y los
artefactos persistentes del proyecto DEBEN preferirse frente a repetir contexto extenso en
conversaciones.

La ejecución multiagente o paralela NO DEBE usarse por defecto. Los subagentes SOLO PUEDEN
emplearse para trabajo especializado o verdaderamente paralelizable; que una tarea esté marcada
como paralelizable no autoriza por sí solo a crear subagentes. Los Agent Skills DEBEN cargarse
únicamente cuando sean relevantes. No se PUEDEN introducir herramientas MCP, agentes adicionales
ni servicios externos sin una necesidad identificada, documentada y aprobada para el trabajo en
cuestión.

## Governance

Esta Constitution prevalece sobre instrucciones, convenciones y prácticas de menor nivel que
entren en conflicto con ella. Toda excepción DEBE ser explícita, estar justificada por un requisito,
riesgo o restricción concreta y quedar registrada en el artefacto SDD o revisión correspondiente.
Una desviación no documentada bloquea la consideración del trabajo como completado.

Los cambios a esta Constitution DEBEN:

1. proponer el cambio, su motivación y su impacto;
2. actualizar la versión siguiendo Semantic Versioning;
3. propagar sus efectos a los templates y Agent Skills de Spec Kit afectados; y
4. incluir una revisión de cumplimiento y, cuando aplique, un plan de migración.

Un incremento MAJOR corresponde a principios eliminados o redefinidos de forma incompatible; un
incremento MINOR, a principios o secciones nuevos o materialmente ampliados; y un incremento PATCH,
a aclaraciones que no cambian obligaciones. Todo pull request y revisión DEBE comprobar los
principios aplicables. Toda complejidad adicional DEBE estar justificada por un requisito, riesgo o
restricción concreta.

**Version**: 1.0.0 | **Ratified**: 2026-07-28 | **Last Amended**: 2026-07-28
