## .NET SDD — Task Generation Constraints

Estas reglas complementan y, cuando exista conflicto, restringen las reglas genéricas anteriores:

- genere solo tareas trazables a `spec.md`, `plan.md`, contratos o Constitution;
- preserve los módulos DDD y la asignación de capas del plan;
- incluya unit tests xUnit significativos y la medición Coverlet de al menos 80% sobre lógica de
  negocio, aunque el flujo core trate los tests como opcionales;
- TDD no es obligatorio: ordene tests y código según `plan.md`;
- para HTTP, incluya implementación y consistencia de `contracts/openapi.yaml`, endpoints Minimal
  API, Wolverine, FluentValidation y Problem Details;
- incluya tareas finales concretas para restore, build Release sin warnings, unit tests, coverage,
  arquitectura, contrato, estándares transversales aplicables y secretos;
- no marque tareas como paralelas si comparten archivos o dependen de trabajo incompleto; y
- no cree interfaces, services, repositories genéricos, mappers o wrappers sin necesidad.

No genere tareas de integration testing, performance testing, Sonar, Veracode, SAST, DAST, CI/CD,
deployment, infraestructura externa o mensajería distribuida. `speckit.converge` es el gate
posterior a implement, no una tarea circular dentro de la primera ejecución.
