# Quickstart: Validación reproducible de creación y consulta

Este documento define la evidencia a ejecutar **después de implementar**. Phase 1 no crea la
solución, proyectos, scripts ni código citados.

## Prerequisites and controlled boundary

- .NET SDK `10.0.302` (runtime/ASP.NET Core `10.0.10`).
- PowerShell 7.
- Puerto loopback `5080` disponible.
- Working directory: raíz del repositorio.
- Ejecución Release, sin debugger y sin carga ajena para performance.
- Datos exclusivamente sintéticos como los ejemplos `acceptance-*`/`load-*`.
- No servidor DB, Docker, herramienta de load externa, credenciales reales ni Internet pública.

Verificar:

```powershell
dotnet --version
$PSVersionTable.PSVersion
git branch --show-current
```

Se esperan `10.0.302`, PowerShell 7 y rama Git `main`. `001-create-query-orders` es el ID de feature,
no una rama.

## Restore, build and automated gates

```powershell
dotnet restore .\Orders.slnx --locked-mode
dotnet build .\Orders.slnx --configuration Release --no-restore -warnaserror
dotnet test .\Orders.slnx --configuration Release --no-build
```

Resultado: lock files sin cambios, cero warnings/errores y todos los tests aprobados. El futuro
wrapper reproduce los mismos gates y retorna exit code no cero ante fallo:

```powershell
.\scripts\verify.ps1
```

## Start with persistent local storage

En una terminal:

```powershell
$quickstartData = Join-Path $PWD '.local\quickstart'
New-Item -ItemType Directory -Path $quickstartData -Force | Out-Null
$env:Orders__DatabasePath = Join-Path $quickstartData 'orders.db'
$env:ASPNETCORE_URLS = 'http://127.0.0.1:5080'
dotnet run --project .\src\Orders.Api\Orders.Api.csproj --configuration Release --no-build
```

Resultado: startup valida/crea schema v1, activa WAL/foreign keys/`synchronous=FULL`, verifica
`busy_timeout=500` y escucha sólo en loopback. Los logs son JSON y no muestran IDs, bodies, SQL,
connection string ni ruta física.

En otra terminal:

```powershell
$baseUri = 'http://127.0.0.1:5080'
```

## Create one valid order

```powershell
$validBody = @{
    customerId = 'acceptance-customer-001'
    items = @(
        @{ productId = 'acceptance-product-A'; quantity = 2 }
        @{ productId = 'acceptance-product-B'; quantity = 1 }
    )
} | ConvertTo-Json -Depth 4

$createResponse = Invoke-WebRequest `
    -Method Post `
    -Uri "$baseUri/orders" `
    -ContentType 'application/json' `
    -Body $validBody

if ($createResponse.StatusCode -ne 201) { throw "Expected 201" }
if ($createResponse.Headers.'Content-Type' -notlike 'application/json*') {
    throw "Expected application/json"
}
$created = $createResponse.Content | ConvertFrom-Json
if ($created.status -ne 'Pending') { throw "Expected Pending" }
if ($created.orderId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') {
    throw "Expected canonical UUID v4"
}
if ($createResponse.Headers.Location -cne "/orders/$($created.orderId)") {
    throw "Invalid Location"
}
$orderId = $created.orderId
```

Resultado: `201` sólo después del commit, exactamente `orderId`/`status`, UUID v4 y `Location`
relativo. Campos de respuesta adicionales hacen fallar contract tests.

## Query and prove the two-capability/three-operation contract

```powershell
$queryResponse = Invoke-WebRequest -Uri "$baseUri/orders/$orderId"
if ($queryResponse.StatusCode -ne 200) { throw "Expected 200" }
$order = $queryResponse.Content | ConvertFrom-Json
if ($order.orderId -cne $orderId) { throw "Wrong order" }
if ($order.customerId -cne 'acceptance-customer-001') { throw "Wrong customer" }
if ($order.status -ne 'Pending') { throw "Wrong status" }
if ($order.items.Count -ne 2) { throw "Wrong item count" }

$missingIdResponse = Invoke-WebRequest -Uri "$baseUri/orders" -SkipHttpErrorCheck
if ($missingIdResponse.StatusCode -ne 400) { throw "Expected missing-id 400" }
$missingIdProblem = $missingIdResponse.Content | ConvertFrom-Json
if ($missingIdProblem.type -cne 'urn:orders:problem:missing-order-id') {
    throw "Wrong missing-id problem"
}

$notFoundResponse = Invoke-WebRequest `
    -Uri "$baseUri/orders/not-a-generated-id" `
    -SkipHttpErrorCheck
if ($notFoundResponse.StatusCode -ne 404) { throw "Expected 404" }
```

Resultado: `GET /orders/{orderId}` es la consulta; `GET /orders` sólo produce `400` y nunca contiene
una colección. Un route value no blanco sin coincidencia produce `404`.

## Verify JSON and semantic validation

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Validation|TestCategory=JsonContract'
```

El conjunto debe cubrir de forma explícita:

- body ausente, vacío, top-level `null`, truncado y malformado con Content-Type correcto;
- required property ausente y nula;
- `items` nulo/vacío y elemento nulo;
- tipos incorrectos y strings usados como números;
- `0`, negativo, `Int64.MaxValue`, overflow, fracción y notación exponencial;
- propiedades desconocidas ignoradas;
- propiedades JSON repetidas rechazadas;
- Content-Type ausente/no soportado como `415`, incluso cuando body también falta;
- case-sensitive JSON property names;
- acumulación de todas las reglas semánticas detectables después de deserializar.

Caso semántico acumulativo:

```powershell
$invalidBody = @{
    customerId = '   '
    items = @(
        @{ productId = 'acceptance-duplicate'; quantity = 0 }
        @{ productId = 'acceptance-duplicate'; quantity = 2 }
        $null
    )
} | ConvertTo-Json -Depth 4

$invalidResponse = Invoke-WebRequest `
    -Method Post `
    -Uri "$baseUri/orders" `
    -ContentType 'application/json' `
    -Body $invalidBody `
    -SkipHttpErrorCheck

if ($invalidResponse.StatusCode -ne 400) { throw "Expected 400" }
$problem = $invalidResponse.Content | ConvertFrom-Json
if (-not $problem.errors.customerId) { throw "Expected customerId error" }
if (-not $problem.errors.'items[0].quantity') { throw "Expected quantity error" }
if (-not $problem.errors.'items[1].productId') { throw "Expected duplicate index error" }
if (-not $problem.errors.'items[2]') { throw "Expected null element error" }
```

El error de duplicado referencia índices, no repite el `productId`. La DB conserva cero filas de esa
solicitud.

## Verify the response matrix and Problem Details catalog

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Contract'
```

Las pruebas derivadas de [contracts/openapi.yaml](./contracts/openapi.yaml) deben verificar:

- POST: `201`, `400`, `413`, `415`, `500`, `503`;
- GET sin ID: `400`, `500`;
- GET por ID: `200`, `400`, `404`, `500`, `503`;
- `application/json` para éxito;
- `application/problem+json` y seis campos obligatorios para errores de aplicación;
- `errors` y sus claves cerradas sólo en validation problems;
- schemas de éxito/error sin propiedades adicionales;
- ausencia de `Retry-After`;
- `413`, `405`, timeout del host y disconnect sin expectativa de Problem Details.

## Verify the 1 MiB host limit

Esta categoría debe levantar Kestrel real en loopback; `TestServer` no sustituye el límite del host:

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=HostBoundary'
```

Casos mínimos:

- body válido dentro de 1.048.576 bytes alcanza la aplicación;
- `Content-Length` mayor que 1.048.576 y stream chunked que supera el límite producen `413`;
- `Content-Length` ausente no desactiva el límite y uno inconsistente no lo elude;
- nunca se trunca y los conteos DB permanecen sin cambios;
- no se asume content type/body para `413`.

## Prove atomicity, UUID retries and uncertain outcome documentation

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Atomicity|TestCategory=Identity'
```

Cobertura requerida:

1. validation failure no abre transacción;
2. gate timeout no abre transacción y devuelve `503`;
3. failure al abrir/BEGIN temporal y pre-commit probado devuelve `503`;
4. order insert, cada item insert y constraint failure hacen rollback total;
5. commit ocurre antes de construir `201`;
6. colisiones en intentos 1 y 2 hacen rollback/retry; colisión 3 da `500` y cero orden;
7. ningún `503` deja una orden confirmada;
8. un fallo/desconexión simulado después de commit conserva la orden y se clasifica como resultado
   incierto para el cliente, nunca `503`.

## Prove durability across process/host-equivalent restart

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Restart'
```

El test crea una orden, detiene la instancia, inicia una instancia nueva con **el mismo path
persistente** y consulta exitosamente la orden. Una variante termina el proceso después de commit
para probar recuperación WAL. También valida que usar una DB nueva representa recreación/pérdida
fuera de la garantía, no un defecto.

## Prove read/write concurrency and saturation

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Concurrency'
```

Resultado requerido:

- 25 creaciones liberadas a la vez nunca comparten ID ni dejan parciales;
- reader antes del commit puede obtener `404`;
- reader bloqueado hasta después del commit obtiene la orden completa;
- reader nunca adquiere el writer gate;
- writer que espera 1.000 ms recibe `503` sin transacción;
- SQLite ocupado durante más de 500 ms produce `503` pre-commit sin retry general;
- se documenta/acepta que `SemaphoreSlim` no garantiza FIFO;
- SQLite, no el gate, sigue imponiendo unicidad/atomicidad ante una conexión externa accidental.

## Verify logging and synthetic-data policy

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Logging|TestCategory=Security'
```

La prueba inyecta canarios sintéticos en customer/product/order path, body, header, connection
string y path de DB, captura logs JSON y exige que ninguno aparezca. También comprueba que las
categorías de ASP.NET Core, SQLite y lifetime suprimidas no emiten eventos. Cada evento de
`Orders.Api` sólo puede contener los campos/vocabularios de `plan.md`; `traceId` debe coincidir
exactamente con Problem Details.
También verifica categorías para startup/schema, validation, gate timeout, busy, rollback,
collision, commit, `503` y `500`, sin exception/SQL/path.

Antes de cualquier aceptación, registrar que fixtures, DB y reportes son sintéticos. Un dataset
externo requiere evidencia previa de clasificación no sensible; sin ella, no ejecutar.

## Reproducible SC-006 load protocol

Ejecutar en Release, loopback, máquina dedicada, sin debugger, antivirus scan iniciado durante la
ventana ni otras cargas controlables:

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Load'
```

El harness debe implementar exactamente:

1. **Warm-up separado**: DB descartable, 25 usuarios, dos ciclos no medidos por usuario.
2. **Base de medición**: reiniciar la API con DB limpia e inicializada; crear secuencialmente 25
   seed orders antes de iniciar timers.
3. **Concurrencia**: 25 usuarios virtuales, cada uno con cliente lógico propio.
4. **Sincronización**: una barrera antes de cada uno de cinco ciclos para que los 25 POST compitan.
5. **Mix por ciclo/usuario**: un POST válido de dos items, GET de la orden recién creada y dos GET
   de seed orders. Total exacto: 500 operaciones = 125 POST (25%) + 375 GET (75%).
6. **Medición**: iniciar cronómetro monotónico inmediatamente antes de enviar HTTP y detener sólo
   después de leer el body completo.
7. **Timeout del harness**: 5 segundos por operación como fail-safe; no redefine el objetivo.
8. **P95**: ordenar las N duraciones de respuestas exitosas (`201`/`200`) y seleccionar por
   nearest-rank la posición `ceil(0.95 × N)`.
9. **Reporte separado**: total, `201`, `200`, `503`, timeouts, otros 4xx/5xx y p95 exitoso.
10. **Gate de aceptación**: p95 exitoso estrictamente `< 2.000 ms`, `503=0`, timeouts=0, errores
    inesperados=0, IDs duplicados=0 y todas las órdenes creadas completas/consultables.

Un `503` es fallo de operación: no entra al percentil exitoso y nunca cuenta como cumplimiento de
latencia. El mix 25/75 estresa el único writer al comienzo de cada ciclo y ejercita con mayor
frecuencia la única capacidad de lectura; no añade listado.

Formato mínimo del reporte:

```text
environment=<os/cpu/storage/runtime>
users=25 measured=500 post=125 get=375
success201=<n> success200=<n> unavailable503=<n> timeout=<n> unexpected=<n>
p95SuccessfulMs=<n>
result=PASS|FAIL
```

## Verify SC-005 usability

Entregar a cada participante únicamente “Create one valid order” y la primera consulta de
“Query...”, con `$baseUri` listo y API iniciada. Medir desde la entrega hasta que muestra la orden.
No responder preguntas durante el intento.

Registrar inicio, fin, éxito/fallo y asistencia. Pasa si al menos 95% crea/consulta en menos de dos
minutos sin ayuda. Es evidencia humana separada de tests automatizados.
