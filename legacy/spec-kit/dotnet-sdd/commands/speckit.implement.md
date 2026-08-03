## .NET SDD — Implementation and Local Evidence

Estas reglas restringen el flujo genérico cuando exista una diferencia:

1. Ejecute `tasks.md` respetando dependencias y archivos compartidos. TDD no es obligatorio; siga
   el orden explícito del plan y de las tareas.
2. No invente requisitos, módulos, abstracciones o infraestructura. Si aparece una necesidad nueva
   que cambia intención o diseño, deténgase y señale el artefacto SDD que debe actualizarse.
3. Preserve los límites DDD, la dirección de referencias y el flujo por Wolverine mediator.
4. Genere y ejecute únicamente unit tests xUnit en esta V1. No agregue integration o performance
   tests.
5. Ejecute el comando Coverlet definido en `plan.md` y compruebe `>= 80%` de line coverage para la
   lógica de negocio. No compense brechas con tests sin comportamiento.
6. Ejecute `dotnet restore` y `dotnet build -c Release`; el resultado debe tener cero errores y
   cero warnings .NET.
7. Ejecute todos los unit tests aplicables.
8. Para HTTP, ejecute
   `npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml`, exija exit code cero
   y no lo sustituya por una prueba runtime.
9. Compare separadamente `spec.md`, `plan.md`, `contracts/openapi.yaml` e implementación,
   incluyendo errores relevantes y Problem Details.
10. Compruebe que cada fallo conocido se traduzca en `Module.Presentation`, que
    `Common.Presentation` conserve solo el fallback inesperado/transversal y que Common no
    referencie ningún proyecto `Modules.*`.
11. Compruebe Repository Pattern, Minimal APIs, FluentValidation y los estándares aplicables de
    Serilog, OpenTelemetry y HealthChecks.
12. Compruebe en código la integración de Azure App Configuration con
    `Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`, endpoint externo y
    `DefaultAzureCredential`. La ausencia del endpoint debe omitir la conexión remota sin permitir
    marcar la integración `N/A`; agregue services/middleware de refresh solo si el diseño los usa.
13. Compruebe que no existan secretos hardcoded ni datos sensibles innecesarios en respuestas,
    logs o trazas.
14. Compruebe que la implementación no haya agregado EF Core Migrations, `dotnet-ef`, snapshots,
    database update, `EnsureCreated()` como política ni tooling de diseño justificado solo por
    gestión del esquema físico.

Las tasks `[P]` describen oportunidades de ejecución sin conflicto, pero no autorizan crear agentes
adicionales ni orquestación multiagente.

Marque una task `[X]` solo después de obtener su evidencia. No ejecute Sonar, Veracode, SAST, DAST,
performance testing, integration testing, CI/CD, deployment, provisioning Azure ni gestión del
esquema físico. Al terminar, reporte los comandos y resultados y señale `speckit.converge` como
siguiente paso.
