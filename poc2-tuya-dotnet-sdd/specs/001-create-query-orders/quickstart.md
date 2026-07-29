# Quickstart: Crear y consultar órdenes

## Prerequisites

- .NET SDK 10.0.302 or a compatible 10.0 patch.
- Node.js compatible with Redocly CLI 2.41.1 for contract linting.
- A reachable SQL Server instance.
- A connection string supplied through configuration, not committed to source.

## Restore and build

```powershell
dotnet tool restore
dotnet restore Orders.slnx
dotnet build Orders.slnx -c Release --no-restore
```

The Release build must finish with zero errors and zero .NET warnings.

## Unit tests

```powershell
dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj `
  -c Release --no-build
```

Only xUnit unit tests are part of this local PoC.

## Coverage

```powershell
$coveragePrefix = Join-Path (Get-Location) 'artifacts\coverage\coverage'
dotnet test Orders/Modules/Orders/Tests/Orders.Test/Orders.Test.csproj `
  -c Release --no-build `
  /p:CollectCoverage=true `
  "/p:CoverletOutput=$coveragePrefix" `
  /p:CoverletOutputFormat=json `
  /p:Threshold=80 `
  /p:ThresholdType=line `
  /p:ThresholdStat=total
```

The command must pass and report at least 80% line coverage for referenced business-logic
projects.

## Prepare the local database

Set the connection string outside source control:

```powershell
$env:ConnectionStrings__Orders = '<local SQL Server connection string>'
dotnet tool run dotnet-ef database update `
  --project Orders/Modules/Orders/Infrastructure/Orders.Infrastructure.csproj `
  --startup-project Orders/Api/Orders.Server/Orders.Server.csproj
```

## Run the API

```powershell
dotnet run --project Orders/Api/Orders.Server/Orders.Server.csproj
```

Use the actual local base URL printed by ASP.NET Core.

## Scenario 1: create a valid order

Send:

```http
POST /orders
Content-Type: application/json

{
  "customerId": "customer-001",
  "items": [
    {
      "productId": "product-001",
      "quantity": 2
    }
  ]
}
```

Expected: `201 Created`, a `Location` header for `/orders/{orderId}`, and the accepted order data.

## Scenario 2: retrieve the created order

Send `GET /orders/{orderId}` with the identifier from Scenario 1.

Expected: `200 OK` and the same customer, products, quantities and creation timestamp.

## Scenario 3: invalid duplicate product

Create an order containing `product-001` twice.

Expected: `400 Bad Request` Problem Details with an `errors` entry identifying
`product-001`; no order is created.

## Scenario 4: order not found

Send `GET /orders/00000000-0000-0000-0000-000000000001`.

Expected: `404 Not Found` Problem Details with a trace identifier and no internal details.

## Contract

The authoritative feature contract is
[`contracts/openapi.yaml`](contracts/openapi.yaml). Before completion, compare its routes, schemas
and response statuses with the implemented endpoints.

Validate its syntax and OpenAPI rules from the repository root:

```powershell
npx --yes @redocly/cli@2.41.1 lint `
  specs/001-create-query-orders/contracts/openapi.yaml
```
