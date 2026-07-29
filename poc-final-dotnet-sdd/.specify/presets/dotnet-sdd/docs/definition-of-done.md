# Local Definition of Done

Una feature no se considera terminada hasta que exista evidencia para cada control aplicable. Una
tarea no puede marcarse como completada por intención o por trabajo parcial.

## Checklist

- [ ] Todas las tasks de la feature están completadas.
- [ ] `dotnet restore` finaliza correctamente.
- [ ] `dotnet build -c Release` finaliza correctamente.
  - [ ] Cero errores.
  - [ ] Cero warnings .NET.
- [ ] Todos los unit tests pasan.
- [ ] La lógica de negocio alcanza al menos 80% de line coverage.
  - [ ] Los tests usan xUnit.
  - [ ] La medición usa Coverlet.
  - [ ] Los tests validan comportamiento significativo.
- [ ] `contracts/openapi.yaml` existe cuando la feature expone HTTP.
- [ ] Redocly CLI `2.41.1` ejecuta con código cero:
  `npx --yes @redocly/cli@2.41.1 lint specs/<feature>/contracts/openapi.yaml`.
- [ ] `openapi.yaml` representa los endpoints implementados.
- [ ] `openapi.yaml` representa los errores HTTP relevantes.
- [ ] Clean Architecture está respetada.
- [ ] Los módulos corresponden a límites DDD.
- [ ] `Domain`, `Application`, `Infrastructure` y `Presentation` existen por módulo.
- [ ] Las dependencias entre proyectos respetan únicamente las direcciones autorizadas.
- [ ] Repository Pattern está respetado.
- [ ] Wolverine se usa exclusivamente como mediator.
- [ ] Las APIs están implementadas con Minimal APIs.
- [ ] FluentValidation está aplicado cuando existe validación de entrada o del caso de uso.
- [ ] Serilog está configurado según el estándar existente.
- [ ] OpenTelemetry está integrado según el estándar existente.
- [ ] HealthChecks están integrados según el estándar existente.
- [ ] Azure App Configuration está integrado en código mediante el provider oficial, un endpoint
  externo y `DefaultAzureCredential`; su ausencia impide declarar `PASS`.
- [ ] La ausencia del endpoint permite restore, build y unit tests locales sin conectarse a Azure.
- [ ] No existen secretos hardcoded.
- [ ] Los errores HTTP siguen el estándar Problem Details.
- [ ] Los errores conocidos específicos de un módulo se traducen en `Module.Presentation`.
- [ ] `Common.Presentation` maneja solo el fallback inesperado/transversal y no referencia ningún
  proyecto `Modules.<Module>.*`.
- [ ] `speckit.converge` finaliza sin brechas pendientes.

Redocly lint valida la estructura y las reglas estáticas OpenAPI. Los dos checks posteriores del
contrato validan por separado la consistencia entre OpenAPI y los endpoints implementados; el lint
no es una prueba runtime de equivalencia.

Un punto transversal puede declararse `N/A` solo con una justificación concreta en `plan.md`. Por
ejemplo, una feature que no agrega una dependencia operativa puede no requerir un HealthCheck
nuevo; eso no permite retirar el estándar ya configurado en la solución. Azure App Configuration
no puede declararse `N/A`: la integración de código es obligatoria aunque el recurso, el endpoint y
la conectividad remota estén fuera del DoD local.

## Evidencia mínima

El cierre debe registrar:

- comandos ejecutados y su resultado;
- resumen de unit tests;
- reporte y umbral de coverage;
- resultado del build Release;
- ubicación del contrato OpenAPI y resultado de Redocly lint, cuando aplique;
- evidencia de integración de Azure App Configuration y ownership de excepciones; y
- resultado final de convergencia.

## Controles posteriores del SDLC

Los siguientes controles no se generan ni se ejecutan en esta V1:

- Sonar;
- Veracode;
- SAST;
- DAST;
- performance testing;
- integration testing;
- CI/CD; y
- deployment;
- provisioning de recursos Azure; y
- versionado o despliegue del esquema físico de base de datos.

Pertenecen a etapas posteriores del SDLC. Las features deben seguir especificando seguridad,
calidad y performance cuando sean requisitos, pero `tasks.md` no debe fingir que ejecutó esos gates
ni crear tareas para configurar sus herramientas.
