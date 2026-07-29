# Data Model: Crear y consultar órdenes

## Aggregate: Order

`Order` es la raíz del agregado y se crea de forma completa antes de persistirse.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `Id` | `Guid` | Yes | Nuevo y no vacío por cada solicitud válida |
| `CustomerId` | `string` | Yes | Contiene al menos un carácter distinto de espacio; se conserva sin normalizar y se compara con semántica ordinal sensible a mayúsculas |
| `CreatedAt` | `DateTimeOffset` | Yes | Instante UTC asignado al crear |
| `Items` | Colección de `OrderItem` | Yes | Al menos un elemento; `ProductId` no puede repetirse |

### Behavior

- `Create` rechaza una colección vacía.
- `Create` rechaza e identifica el primer `ProductId` duplicado.
- La orden no tiene transición de estado, modificación ni cancelación en esta feature.
- Cada invocación válida genera un `Id` distinto, aunque los datos sean idénticos.

## Entity: OrderItem

| Field | Type | Required | Rules |
|---|---|---:|---|
| `ProductId` | `string` | Yes | Contiene al menos un carácter distinto de espacio; se conserva sin normalizar y se compara con semántica ordinal sensible a mayúsculas |
| `Quantity` | `int` | Yes | Entre 1 y 2.147.483.647 |

`OrderItem` pertenece exclusivamente a una `Order` y no tiene ciclo de vida independiente.

## Relational Mapping

### `Orders`

| Column | Storage | Constraint |
|---|---|---|
| `Id` | `uniqueidentifier` | Primary key |
| `CustomerId` | `nvarchar(max)` | Not null |
| `CreatedAt` | `datetimeoffset` | Not null |

### `OrderItems`

| Column | Storage | Constraint |
|---|---|---|
| `OrderId` | `uniqueidentifier` | Foreign key to `Orders.Id`; composite primary key with shadow `LineNumber` |
| `LineNumber` | `int` | Shadow persistence key; composite primary key with `OrderId` |
| `ProductId` | `nvarchar(max)` | Not null |
| `Quantity` | `int` | Not null; greater-than-zero invariant enforced by domain |

The shadow `LineNumber` avoids imposing a persistence length limit on the opaque `ProductId`.
Duplicate detection remains a domain invariant using ordinal, case-sensitive equality. EF Core
saves the aggregate in one transaction.

## Application Messages

### `CreateOrderCommand`

- `CustomerId: string`
- `Items: IReadOnlyList<CreateOrderItem>`

Returns `OrderResult`.

### `GetOrderQuery`

- `OrderId: string`

The validator requires the canonical GUID textual form. The handler parses it only after successful
validation and returns `OrderResult` or raises the not-found application outcome.

### `OrderResult`

- `Id: Guid`
- `CustomerId: string`
- `CreatedAt: DateTimeOffset`
- `Items: IReadOnlyList<OrderItemResult>`

Application results contain no ASP.NET types or persistence details.
