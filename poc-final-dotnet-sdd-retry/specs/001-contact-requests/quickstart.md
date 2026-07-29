# Quickstart Validation Guide: Contact Requests

Esta guía valida la feature de extremo a extremo una vez implementada. No provisiona SQL Server,
Azure ni el esquema físico.

## Prerequisites

- .NET SDK `10.0.302`, fijado en `global.json`.
- Una instancia SQL Server accesible y una base de datos con el esquema compatible ya administrado
  por el proceso externo responsable del esquema.
- Node.js `>=22.12.0` o `>=20.19.0 <21.0.0`.
- npm `>=10`.
- PowerShell 7+ para los ejemplos.
- Datos exclusivamente sintéticos o no sensibles.

Azure App Configuration no es necesario para restore, build, unit tests ni ejecución local. Para
probar el provider remoto se requiere un endpoint y una identidad disponible mediante
`DefaultAzureCredential`.

## 1. Configure local runtime

Desde la raíz del repositorio:

```powershell
$env:ConnectionStrings__ContactRequests = 'Server=localhost;Database=ContactRequests;Integrated Security=true;TrustServerCertificate=true'
```

Opcionalmente, para activar Azure App Configuration:

```powershell
$env:AzureAppConfiguration__Endpoint = 'https://<resource-name>.azconfig.io'
```

No use connection strings, secretos ni credenciales hardcoded. Si el endpoint no existe, el
provider remoto permanece inactivo.

## 2. Restore, build, and unit tests

```powershell
dotnet restore ContactRequests.slnx
dotnet build ContactRequests.slnx -c Release --no-restore
dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build
```

Resultados esperados:

- restore exitoso;
- build Release con cero errores y cero warnings .NET;
- todos los unit tests xUnit exitosos;
- ninguna conexión a SQL Server o Azure durante unit tests.

## 3. Verify coverage

```powershell
$coverageOutput = Join-Path (Get-Location) 'artifacts\coverage\contact-requests\'
dotnet test src/Modules/ContactRequests/Tests/ContactRequests.Tests.csproj -c Release --no-build `
  /p:CollectCoverage=true `
  /p:CoverletOutput="$coverageOutput" `
  /p:CoverletOutputFormat=cobertura `
  /p:Threshold=80 `
  /p:ThresholdType=line
```

Resultado esperado: exit code cero y al menos 80% de line coverage en la lógica de negocio de
Domain y Application. DTOs sin lógica, bootstrap, DI, configuración EF y OpenAPI no requieren
coverage artificial.

## 4. Validate OpenAPI

```powershell
npx --yes @redocly/cli@2.41.1 lint specs/001-contact-requests/contracts/openapi.yaml
```

Resultado esperado: exit code cero. Este lint valida el documento estáticamente; no sustituye la
comparación de rutas, schemas, status codes y handlers implementados.

## 5. Run the API

```powershell
dotnet run --project src/Api/ContactRequests.Server/ContactRequests.Server.csproj -c Release
```

Use la URL HTTP mostrada por ASP.NET Core como `$baseUrl`:

```powershell
$baseUrl = 'http://localhost:5000'
```

## 6. Register a valid request

```powershell
$created = Invoke-RestMethod `
  -Method Post `
  -Uri "$baseUrl/contact-requests" `
  -ContentType 'application/json' `
  -Body (@{
    name = '  Ada Lovelace  '
    email = 'ada@example.test'
    subject = '  Consulta  '
    message = '  Mensaje sintético de validación.  '
  } | ConvertTo-Json)

$created
```

Expected:

- HTTP `201 Created`;
- response contains `id` and `createdAtUtc`;
- `Location` points to `/contact-requests/{id}`;
- persisted name, subject, and message have exterior whitespace removed.

Repeat the same request. The second response must contain a different `id`.

## 7. Retrieve the exact request

```powershell
$found = Invoke-RestMethod `
  -Method Get `
  -Uri "$baseUrl/contact-requests/$($created.id)"

$found
```

Expected: HTTP `200` with the exact `id`, `name`, `email`, `subject`, `message`, and
`createdAtUtc` from the created request.

## 8. Validate rejection and not-found outcomes

Invalid input:

```powershell
$invalidBody = @{
  name = '   '
  email = 'not-an-email'
  subject = 'Synthetic'
  message = 'Synthetic'
} | ConvertTo-Json

try {
  Invoke-WebRequest -Method Post -Uri "$baseUrl/contact-requests" `
    -ContentType 'application/json' -Body $invalidBody
} catch {
  $_.Exception.Response.StatusCode
}
```

Expected: HTTP `400`, `application/problem+json`, field errors, and no persisted row.

Unknown or malformed identifier:

```powershell
try {
  Invoke-WebRequest -Method Get -Uri "$baseUrl/contact-requests/not-an-existing-id"
} catch {
  $_.Exception.Response.StatusCode
}
```

Expected: HTTP `404`, `application/problem+json`, no approximate match, no data from any other
request, and a safe `traceId`.

## 9. Health endpoint

```powershell
Invoke-WebRequest -Uri "$baseUrl/health"
```

Expected: a safe health status without connection strings, credentials, stack traces, or contact
request data.

## Scope reminder

This guide does not generate integration or performance suites, CI/CD, deployment, Azure
resources, credentials, collectors, dashboards, migrations, schema snapshots, or physical schema
updates.
