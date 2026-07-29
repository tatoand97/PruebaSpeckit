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
8. FluentValidation, Problem Details, fallos conocidos en `Module.Presentation` y fallback
   inesperado en `Common.Presentation` sin referencias `Modules.*`;
9. `contracts/openapi.yaml` con operaciones y errores cuando exista HTTP, validado estáticamente
   mediante `npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml`;
10. Serilog, OpenTelemetry y HealthChecks según aplicabilidad;
11. Azure App Configuration integrado obligatoriamente en código con provider oficial,
    `DefaultAzureCredential` y endpoint externo, sin permitir `N/A`;
12. unit tests xUnit, Coverlet y umbral de 80% sobre lógica de negocio;
13. versionado y despliegue del esquema físico fuera de alcance, sin EF Core Migrations,
    `dotnet-ef`, snapshots, database update ni `EnsureCreated()` como política; y
14. cada control del Local Definition of Done.

Phase 1 debe crear o actualizar `contracts/openapi.yaml` para una feature HTTP usando la convención
de contratos de Spec Kit. No imponga contract-first; exija Redocly lint con exit code cero y
compruebe por separado la consistencia final con la implementación. Documente npm `>=10` y Node.js
`>=22.12.0` o `>=20.19.0 <21.0.0`; no agregue instalación global ni una infraestructura Node
completa.

El plan debe permitir restore, build y unit tests locales sin Azure: active el provider remoto
solo cuando exista el endpoint configurado. Esto no vuelve opcional su integración en código. Use
`AddAzureAppConfiguration()` en servicios y `UseAzureAppConfiguration()` solo si el refresh
seleccionado realmente los necesita; no diseñe refresh complejo por defecto.

Realice la investigación dentro del command y del contexto activo. No cree agentes adicionales ni
orquestación multiagente para despachar las tareas de research descritas por el flujo genérico.

No agregue integration testing, performance testing, seguridad de pipeline, CI/CD, deployment,
provisioning Azure o gestión del esquema físico al plan. Las brechas de arquitectura sin una
justificación aprobada hacen fallar Constitution Check.
