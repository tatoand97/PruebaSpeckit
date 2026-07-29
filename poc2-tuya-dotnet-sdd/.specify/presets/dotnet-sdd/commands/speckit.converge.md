## .NET SDD — Additional Convergence Inventory

Conserve íntegramente la semántica oficial: este command solo evalúa el estado actual y, si
encuentra brechas, agrega tasks append-only para que una ejecución posterior de
`speckit.implement` las resuelva. No modifique código, `spec.md` ni `plan.md`.

Incluya en el inventario de intención y evidencia:

- módulos DDD y existencia de Domain/Application/Infrastructure/Presentation;
- referencias entre proyectos y responsabilidades de Clean Architecture;
- ausencia de abstracciones no justificadas;
- Repository Pattern y ausencia de acceso concreto desde Application/Presentation;
- Wolverine exclusivamente como mediator y `DurabilityMode.MediatorOnly`;
- endpoints Minimal API delgados que delegan a Wolverine;
- unit tests xUnit significativos y reporte Coverlet `>= 80%` de lógica de negocio;
- restore exitoso y build Release con cero errores y cero warnings;
- `contracts/openapi.yaml` consistente con endpoints y errores HTTP;
- manejo global `IExceptionHandler` + `AddProblemDetails()` y respuestas Problem Details seguras;
- FluentValidation y estándares aplicables de Serilog, OpenTelemetry, HealthChecks y Azure App
  Configuration;
- ausencia de secretos hardcoded; y
- todas las demás tasks del Local Definition of Done con evidencia.

No convierta en brechas locales la ausencia de Sonar, Veracode, SAST, DAST, performance testing,
integration testing, CI/CD o deployment. Si falta evidencia o existe una violación, agregue una
task concreta y trazable. Declare convergencia solo cuando no quede ninguna brecha aplicable.
