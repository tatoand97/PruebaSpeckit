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
wrapper ejecuta explícitamente locked restore, Release build con warnings-as-errors, unit,
integration, contract, persistence/atomicity, restart, concurrency, Kestrel host-boundary,
logging/security, SC-005 performance y validación de lock files; retorna exit code no cero ante
fallo:

```powershell
.\scripts\verify.ps1
```

`tests/Orders.Api.Tests/Orders.Api.Tests.csproj` debe contener
`<MSTestParallelizeScope>None</MSTestParallelizeScope>` y no debe declarar
`[assembly: Parallelize]` ni una política contradictoria. El assembly se ejecuta secuencialmente;
los 25 trabajos de T030 se liberan concurrentemente dentro de un único test. Esta política MSTest
es independiente de las marcas `[P]` de `tasks.md`.

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
- el caso válido grande serializa primero el JSON final, mide su longitud UTF-8 y falla salvo que
  sea exactamente **1.040.000 bytes**; usa muchos `productId` ASCII distintos, cantidades válidas,
  cero duplicados y padding calculado determinísticamente para alcanzar el objetivo;
- ese request de 1.040.000 bytes produce `201`; una consulta y la inspección SQLite comprueban que
  todos los productos se persistieron completos;
- `Content-Length` mayor que 1.048.576 y stream chunked que supera el límite producen `413`;
- `Content-Length` ausente no desactiva el límite y uno inconsistente no lo elude;
- nunca se trunca y los conteos DB permanecen sin cambios;
- no se asume content type/body para `413`.

Los casos `413` se construyen aparte con más de 1.048.576 bytes. El objetivo de 1.040.000 bytes no
es un máximo de negocio: demuestra que 1 MiB es un límite operativo de transporte.

## Prove atomicity, UUID retries and uncertain outcome documentation

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Atomicity|TestCategory=Identity'
```

Cobertura requerida de seams:

1. before BEGIN failure;
2. after order insert failure con rollback total;
3. after items failure con rollback total;
4. before commit failure: `CommitInvoker` nunca es invocado, rollback es seguro y no hay orden
   confirmada;
5. commit invocation with uncertain outcome: el `CommitInvoker` sustituido ejecuta el commit real y
   después lanza antes de retornar; el store no compensa, nunca responde `503`, usa `500` genérico si
   puede responder y la inspección SQLite posterior comprueba que el commit ocurrió;
6. confirmed after-commit failure: `CommitInvoker` retornó, falla el hook after-commit y la orden
   sigue confirmada sin rollback ni `503`;
7. post-commit/pre-response failure en el seam de `Program.cs`, conservando la orden confirmada sin
   rollback ni `503`;
8. reader snapshot before commit, que puede devolver `404` sin observar parciales;
9. reader after commit, que obtiene la orden completa.

Además, validation failure no abre transacción; gate timeout y open/BEGIN temporal probado devuelven
`503` sin commit; colisiones 1/2 hacen rollback/retry y la tercera da `500` con cero orden; ningún
`503` deja una orden confirmada.

Todos los delegates pertenecen a una única instancia interna de seams por host, compartida por
`SqliteOrderStore` y `Program.cs`, nunca a estado mutable `static`. Cada
`WebApplicationFactory` usa su propia instancia. Toda prueba conserva el valor anterior de cada
delegate modificado y lo restaura en `finally`; usa SQLite temporal propio cuando toca
persistencia/concurrencia y dispone obligatoriamente la factory y el storage temporal. No se usan
delays arbitrarios, paquetes, capas ni frameworks adicionales.

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
- `Barrier`, `ManualResetEventSlim` o equivalentes nativos controlan los hooks before/after commit,
  sin delays arbitrarios;
- reader pausado antes del commit puede obtener `404`;
- reader liberado después del commit obtiene la orden completa;
- reader nunca adquiere el writer gate;
- writer que espera 1.000 ms recibe `503` sin transacción;
- SQLite ocupado durante más de 500 ms produce `503` pre-commit sin retry general;
- creación, consulta y concurrencia evidencian una conexión dedicada por operación y ningún objeto
  ADO.NET compartido entre operaciones;
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
categorías de ASP.NET Core, SQLite y lifetime suprimidas no emiten eventos. El formatter JSON
nativo se configura con una entrada por línea, UTC,
`TimestampFormat="yyyy-MM-dd'T'HH:mm:ss.fff'Z'"` e `IncludeScopes=false`.
La prueba valida por separado el envelope nativo esperado (`Timestamp`, `EventId`, `LogLevel`,
`Category`, `Message`, `State`) y, dentro de `State`, sólo las seis propiedades aplicativas
`operation`, `httpStatus`, `outcome`, `durationMs`, `traceId`, `failureCategory`, permitiendo
metadata propia del formatter como `{OriginalFormat}`. En .NET 10 `Message` se espera normalmente
en el nivel superior, no duplicado en `State`. No puede aparecer otra propiedad aplicativa y
`traceId` debe coincidir exactamente con Problem Details.
También verifica categorías para startup/schema, validation, gate timeout, busy, rollback,
collision, commit, `503` y `500`, sin exception/SQL/path.

Los tests usan exclusivamente fixtures controlados del repositorio y marcan DB/reportes temporales
como sintéticos. La auditoría automática falla si detecta valores/campos prohibidos o fixtures
externos sin clasificación no sensible registrada.

## Reproducible SC-005 load protocol

Ejecutar en Release, loopback, máquina dedicada, sin debugger, antivirus scan iniciado durante la
ventana ni otras cargas controlables:

```powershell
dotnet test .\tests\Orders.Api.Tests\Orders.Api.Tests.csproj `
    --configuration Release `
    --no-build `
    --filter 'TestCategory=Load'
```

El harness usa las capacidades ya disponibles de `Microsoft.AspNetCore.Mvc.Testing`: configura
`WebApplicationFactory` para Kestrel real, loopback y puerto dinámico. `TestServer` no participa en
la medición. Debe implementar exactamente:

1. **Warm-up separado**: instancia y DB descartables, 25 usuarios, dos ciclos no medidos por
   usuario; detener y descartar ambos.
2. **Medición aislada**: instancia nueva y DB SQLite nueva e inicializada; crear secuencialmente 25
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

## Automated SC-006 synthetic-data gate

El gate inspecciona los fixtures controlados, requests generadas, archivos SQLite temporales, logs
y reportes de la suite. Debe demostrar que usan nombres sintéticos de los namespaces de prueba, que
no contienen credenciales ni canarios prohibidos y que no dependen de datasets externos. Cualquier
fixture no generado requiere un registro versionado de clasificación no sensible; su ausencia hace
fallar el gate. Toda la evidencia se obtiene automáticamente.
