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
- `contracts/openapi.yaml` validado por
  `npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml` con exit code cero y,
  por separado, consistente con endpoints y errores HTTP;
- handlers `IExceptionHandler` con Problem Details: fallos conocidos en `Module.Presentation` y
  fallback inesperado/transversal en `Common.Presentation`, sin referencias Common -> `Modules.*`;
- FluentValidation y estándares aplicables de Serilog, OpenTelemetry y HealthChecks;
- Azure App Configuration integrado en código con provider oficial, `DefaultAzureCredential`,
  endpoint externo y activación remota condicional, nunca `N/A`;
- ausencia de EF Core Migrations, `dotnet-ef`, snapshots, database update, `EnsureCreated()` como
  política y tooling de diseño agregado solo para gestión del esquema físico;
- ausencia de secretos hardcoded; y
- todas las demás tasks del Local Definition of Done con evidencia.

No convierta en brechas locales la ausencia de Sonar, Veracode, SAST, DAST, performance testing,
integration testing, CI/CD, deployment, provisioning Azure o gestión del esquema físico. Si falta
evidencia o existe una violación, agregue una task concreta y trazable. Declare convergencia solo
cuando no quede ninguna brecha aplicable.
