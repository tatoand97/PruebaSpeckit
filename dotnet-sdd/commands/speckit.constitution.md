## .NET SDD — Constitution Baseline Guard

Además del flujo oficial, trate las obligaciones ya incluidas por el preset como una línea base
inmutable para este proyecto:

- preserve Specification First, DDD modular boundaries, Clean Architecture, simplicidad, .NET 10,
  Repository Pattern, Wolverine mediator, Minimal APIs, unit testing/coverage, errores
  estandarizados, observabilidad, reproducibilidad y la separación de gates posteriores;
- permita agregar reglas específicas del proyecto únicamente cuando no debiliten ni contradigan
  esa línea base;
- ante una solicitud contradictoria, no modifique silenciosamente la obligación: identifique el
  conflicto y solicite una decisión de gobierno explícita; y
- mantenga la estructura y el significado normativo del template del preset al actualizar nombre,
  versión, fechas o reglas adicionales.

No transforme la constitución en diseño de una feature; las decisiones específicas pertenecen a
`spec.md` y `plan.md`.
