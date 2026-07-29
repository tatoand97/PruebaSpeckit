# Estrategia de testing

## Alcance V1

Esta V1 genera únicamente unit tests. El framework es xUnit y la medición de cobertura usa
Coverlet.

Los tests se concentran en comportamiento significativo de `Domain` y `Application`. Si una regla
de negocio vive legítimamente en otra capa, se prueba allí. TDD no es obligatorio: el plan puede
ubicar las tareas de prueba antes o después del código mientras preserve dependencias claras y
evidencia reproducible.

## Objetivo de cobertura

La lógica de negocio debe alcanzar al menos 80% de line coverage. El plan debe:

1. delimitar qué proyectos o namespaces contienen lógica de negocio;
2. definir el comando reproducible de xUnit y Coverlet;
3. explicar exclusiones justificadas; y
4. producir un reporte del que pueda comprobarse el umbral.

No se crean pruebas artificiales para elevar el porcentaje. Normalmente quedan fuera del objetivo:

- DTOs sin lógica;
- `Program.cs`;
- configuración de dependency injection;
- migrations;
- código generado;
- assembly markers;
- bootstrap trivial;
- archivos OpenAPI; y
- código sin comportamiento.

Las exclusiones no pueden ocultar lógica de negocio.

## Qué no se genera

El preset V1 no genera ni ejecuta:

- integration tests;
- performance tests;
- DAST o SAST;
- pruebas de infraestructura propias de otro equipo; ni
- tests cuyo único objetivo sea incrementar coverage.

Estas exclusiones no eliminan requisitos funcionales o no funcionales. Solo delimitan la evidencia
local que produce esta versión del preset; los controles especializados pertenecen a etapas
posteriores del SDLC.
