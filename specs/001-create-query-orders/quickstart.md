# Quickstart: Validación reproducible de creación y consulta

Este documento describe cómo verificar la feature **después de su implementación**. En Phase 1 aún
no existen la solución, proyectos, scripts ni código citados.

## Prerequisites

- .NET SDK `10.0.302` (incluye runtime/ASP.NET Core `10.0.10`).
- PowerShell 7.
- Puerto local `5080` disponible.
- Working directory: raíz del repositorio.
- No se necesita servidor de base de datos, Docker ni herramienta de load testing.

Verificar versiones:

```powershell
dotnet --version
$PSVersionTable.PSVersion
```

`dotnet --version` debe mostrar `10.0.302`. El host usado al redactar el plan tenía `10.0.203`;
debe actualizarse antes de ejecutar este quickstart, pero Phase 1 no instala software.

## Restore, build and tests

```powershell
dotnet restore .\Orders.slnx --locked-mode
dotnet build .\Orders.slnx --configuration Release --no-restore -warnaserror
dotnet test .\Orders.slnx --configuration Release --no-build
```

Resultado esperado: restore sin modificar lock files, build con cero warnings/errores y todas las
pruebas aprobadas.

El futuro wrapper ejecuta las mismas puertas y devuelve un exit code no cero ante cualquier fallo:

```powershell
.\scripts\verify.ps1
```

## Start the API with an isolated database

En una terminal PowerShell:

```powershell
$quickstartData = Join-Path $PWD '.local\quickstart'
New-Item -ItemType Directory -Path $quickstartData -Force | Out-Null
$env:Orders__DatabasePath = Join-Path $quickstartData 'orders.db'
$env:ASPNETCORE_URLS = 'http://127.0.0.1:5080'
dotnet run --project .\src\Orders.Api\Orders.Api.csproj --configuration Release --no-build
```

Resultado esperado: la aplicación inicia, crea/valida el esquema SQLite y escucha en
`http://127.0.0.1:5080`. Los logs son JSON y no muestran identificadores ni cuerpos.

En una segunda terminal:

```powershell
$baseUri = 'http://127.0.0.1:5080'
```

## Create a valid order

```powershell
$validBody = @{
    customerId = 'customer-001'
    items = @(
        @{ productId = 'product-A'; quantity = 2 }
        @{ productId = 'product-B'; quantity = 1 }
    )
} | ConvertTo-Json -Depth 4

$createResponse = Invoke-WebRequest `
    -Method Post `
    -Uri "$baseUri/orders" `
    -ContentType 'application/json' `
    -Body $validBody

if ($createResponse.StatusCode -ne 201) { throw "Expected 201, got $($createResponse.StatusCode)" }
$created = $createResponse.Content | ConvertFrom-Json
if ($created.status -ne 'Pending') { throw "Expected Pending" }
if ([string]::IsNullOrWhiteSpace($created.orderId)) { throw "Expected orderId" }
if ($createResponse.Headers.Location -ne "/orders/$($created.orderId)") { throw "Invalid Location" }
$orderId = $created.orderId
```

Resultado esperado: `201`, un `orderId` no vacío, status `Pending` y header `Location`.

## Reject an invalid order and duplicates

```powershell
$invalidBody = @{
    customerId = '   '
    items = @(
        @{ productId = 'product-A'; quantity = 0 }
        @{ productId = 'product-A'; quantity = 2 }
    )
} | ConvertTo-Json -Depth 4

$invalidResponse = Invoke-WebRequest `
    -Method Post `
    -Uri "$baseUri/orders" `
    -ContentType 'application/json' `
    -Body $invalidBody `
    -SkipHttpErrorCheck

if ($invalidResponse.StatusCode -ne 400) { throw "Expected 400" }
if ($invalidResponse.Headers.'Content-Type' -notlike 'application/problem+json*') {
    throw "Expected application/problem+json"
}
$problem = $invalidResponse.Content | ConvertFrom-Json
if (-not $problem.errors.customerId) { throw "Expected customerId error" }
if (-not $problem.errors.items) { throw "Expected duplicate product error" }
if (-not $problem.errors.'items[0].quantity') { throw "Expected quantity error" }
```

Resultado esperado: `400` con todos los errores detectados, incluido `product-A` duplicado. No se
crea ninguna orden total ni parcial.

## Query the existing order

```powershell
$queryResponse = Invoke-WebRequest -Uri "$baseUri/orders/$orderId"
if ($queryResponse.StatusCode -ne 200) { throw "Expected 200" }
$order = $queryResponse.Content | ConvertFrom-Json
if ($order.orderId -cne $orderId) { throw "Wrong order" }
if ($order.customerId -cne 'customer-001') { throw "Wrong customer" }
if ($order.status -ne 'Pending') { throw "Wrong status" }
if ($order.items.Count -ne 2) { throw "Wrong item count" }
```

Resultado esperado: `200` y exactamente la orden creada, con ambos productos, cantidades y status.

## Query a missing or invalid identifier

Identificador opaco no encontrado:

```powershell
$missingResponse = Invoke-WebRequest `
    -Uri "$baseUri/orders/not-a-generated-id" `
    -SkipHttpErrorCheck

if ($missingResponse.StatusCode -ne 404) { throw "Expected 404" }
$missing = $missingResponse.Content | ConvertFrom-Json
if ($missing.type -ne 'urn:orders:problem:not-found') { throw "Wrong problem type" }
```

Identificador ausente:

```powershell
$invalidIdResponse = Invoke-WebRequest -Uri "$baseUri/orders" -SkipHttpErrorCheck
if ($invalidIdResponse.StatusCode -ne 400) { throw "Expected 400" }
$invalidId = $invalidIdResponse.Content | ConvertFrom-Json
if (-not $invalidId.errors.orderId) { throw "Expected orderId error" }
```

Resultado esperado: un valor no vacío sin coincidencia da `404`; ausencia da `400`. Ambos usan
`application/problem+json` y no exponen datos de otras órdenes.

## Prove atomicity

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Atomicity'
```

La categoría debe probar dos niveles:

1. errores semánticos mezclados con items válidos crean cero filas;
2. un fallo forzado por constraint después del insert de `orders` revierte también la orden.

Resultado esperado: todas las pruebas aprobadas y conteos de `orders`/`order_items` sin parciales.

## Prove uniqueness under concurrency

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Concurrency'
```

Resultado esperado: 25 solicitudes válidas liberadas a la vez producen 25 respuestas exitosas,
25 identificadores distintos y 25 órdenes completas consultables.

## Verify the 25-user target

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Load'
```

El test usa una barrera para iniciar 25 usuarios simulados, mezcla creación y consulta, registra la
duración individual y calcula p95 desde cliente.

Resultado esperado:

- ninguna respuesta funcional incorrecta;
- ningún identificador duplicado;
- p95 menor a 2 segundos;
- cada orden creada queda consultable y completa.

## Verify the usability outcome

Para SC-005, entregar a cada participante únicamente las secciones “Create a valid order” y
“Query the existing order”, con `$baseUri` ya configurado y la API iniciada. Medir desde la entrega
de la guía hasta que muestra la consulta correcta. No responder preguntas durante el intento.

Registrar por participante: inicio, fin, éxito/fallo y si necesitó asistencia. El criterio pasa si
al menos el 95 % crea y consulta una orden válida en menos de 2 minutos sin asistencia. Esta
evidencia es manual porque el criterio mide comprensión humana; no sustituye las pruebas
automatizadas.

## Contract reference

Los status, headers, cuerpos y ejemplos esperados están en
[contracts/openapi.yaml](./contracts/openapi.yaml). Las pruebas de categoría `Contract` deben fallar
si la implementación se desvía.

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Contract'
```
