## .NET SDD — Required Planning Pass

Antes de completar el flujo oficial de `speckit.plan`, llene todas las secciones aplicables del
template del preset y valide explícitamente:

1. módulos DDD afectados y razón de cada límite;
2. responsabilidades Domain/Application/Infrastructure/Presentation;
3. referencias autorizadas entre proyectos y composition root;
4. flujo Minimal API -> Presentation -> Wolverine -> Application -> Domain -> repository ->
   Infrastructure;
5. `DurabilityMode.MediatorOnly`, sin mensajería distribuida;
6. decisión justificada entre EF Core + SQL Server, EF Core + MongoDB o N/A;
7. Repository Pattern sin acceso concreto desde Application o Presentation;
8. FluentValidation, Problem Details y manejo global de excepciones;
9. `contracts/openapi.yaml` con operaciones y errores cuando exista HTTP;
10. Serilog, OpenTelemetry, HealthChecks y Azure App Configuration según aplicabilidad;
11. unit tests xUnit, Coverlet y umbral de 80% sobre lógica de negocio; y
12. cada control del Local Definition of Done.

Phase 1 debe crear o actualizar `contracts/openapi.yaml` para una feature HTTP usando la convención
de contratos de Spec Kit. No imponga contract-first; exija consistencia final.

Realice la investigación dentro del command y del contexto activo. No cree agentes adicionales ni
orquestación multiagente para despachar las tareas de research descritas por el flujo genérico.

No agregue integración, performance, seguridad de pipeline, CI/CD o deployment al plan. Las
brechas de arquitectura sin una justificación aprobada hacen fallar Constitution Check.
