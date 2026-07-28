# Data Model: Creación y consulta de órdenes

**Feature**: `001-create-query-orders`

**Source of truth**: [spec.md](./spec.md)

El modelo persistente contiene únicamente `Order` y `OrderItem`. `Cliente` y `Producto` no son
entidades administradas: sólo existen los valores opacos `customerId` y `productId`.

## Transport input before semantic validation

El DTO de `POST /orders` mantiene referencias y `quantity` anulables para distinguir documentos
deserializables de modelos de dominio válidos:

| Field | Transport type | Why nullable |
|---|---|---|
| `customerId` | `string?` | missing/null se acumula como regla semántica |
| `items` | collection of nullable item inputs or null | missing/null/element null se informa por ruta |
| `items[n].productId` | `string?` | missing/null se acumula junto con otras reglas |
| `items[n].quantity` | `Int64?` | missing/null se distingue de `0`; tipo/rango falla en JSON |

Un body ausente, top-level `null`, JSON malformado, tipo incorrecto, número fuera de `Int64`,
fracción, exponente o propiedad repetida no produce este DTO: termina como `400 invalid-body`.
Propiedades desconocidas se ignoran y no pasan al dominio.

## Order

Representa una orden aceptada, persistida completamente y confirmada.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `orderId` | string (UUID v4 `D`) | yes | Generado; pattern canónico lower-case; único entre órdenes retenidas; opaco; no incorpora datos. |
| `customerId` | string | yes | Al menos un carácter no-whitespace; preservado sin trim, case-fold o normalización; catálogo no consultado. |
| `status` | enum/string | yes | Único valor permitido: `Pending`. |
| `items` | collection of `OrderItem` | yes | Uno o más; un `productId` por igualdad ordinal dentro de la orden. |

### Identity

`orderId` es la primary key. Se genera con UUID v4 y sólo se expone después del commit. SQLite,
no la probabilidad del generador, es la garantía definitiva:

1. generar UUID;
2. intentar transacción;
3. colisión de `orders.order_id` → rollback;
4. repetir hasta tres intentos totales;
5. tercera colisión → rollback, `500` genérico, cero orden confirmada.

### State

- Initial and only state: `Pending`.
- Transitions: none in scope.
- Modification, cancellation, deletion and archival: out of scope.

## OrderItem

Representa un producto/cantidad confirmado dentro de una orden.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `orderId` | string | yes | Foreign key a la orden y parte de la identidad persistente. |
| `productId` | string | yes | No-whitespace; preservado; no lookup; único por comparación ordinal exacta. |
| `quantity` | signed 64-bit integer | yes | `1..Int64.MaxValue`; JSON original debió ser entero sin fracción/exponente; nunca se convierte, trunca o consolida. |

La identidad es (`orderId`, `productId`); no existe surrogate key.

## Relationships

```text
Order (1) ─── owns ─── (1..*) OrderItem
```

- Cada item pertenece a exactamente una orden.
- Una orden confirmada nunca existe sin items.
- No hay foreign key a Customer/Product.
- El orden de `items` no tiene semántica de negocio, no forma parte de identidad y el contrato no
  promete una posición estable. Sí se preservan todos los pares `productId`/`quantity`.

## Relational mapping (schema version 1)

### `orders`

| Column | SQLite type | Constraints |
|---|---|---|
| `order_id` | `TEXT` | `PRIMARY KEY`, `COLLATE BINARY`, `NOT NULL` |
| `customer_id` | `TEXT` | `NOT NULL`, `CHECK(length(customer_id) > 0)` |
| `status` | `TEXT` | `NOT NULL`, `CHECK(status = 'Pending')` |

### `order_items`

| Column | SQLite type | Constraints |
|---|---|---|
| `order_id` | `TEXT` | `NOT NULL`, foreign key to `orders(order_id)` |
| `product_id` | `TEXT` | `NOT NULL`, `COLLATE BINARY`, `CHECK(length(product_id) > 0)` |
| `quantity` | `INTEGER` | `NOT NULL`, `CHECK(quantity > 0)` |

Primary key: (`order_id`, `product_id`). Foreign-key delete behavior is `NO ACTION`; deletion is
fuera de alcance.

Ambas tablas son `STRICT`. `COLLATE BINARY` y parámetros de texto conservan comparación exacta en
persistencia; C# y SQLite no hacen trim, case-fold ni normalización Unicode. Los `CHECK(length)>0`
son defensa mínima; `string.IsNullOrWhiteSpace` sigue siendo la regla completa del boundary.

## Schema initialization and connection invariants

- Startup transaction creates schema v1 only when absent and sets `PRAGMA user_version=1`.
- Existing storage must report schema v1, required tables/columns, `quick_check=ok` and no rows from
  `foreign_key_check`; otherwise startup fails instead of mutating un esquema desconocido.
- Startup sets/verifies WAL. Every connection applies `foreign_keys=ON`, `synchronous=FULL` and
  `busy_timeout=500`.
- Writers use `BEGIN IMMEDIATE`; each HTTP operation owns one connection and no ADO.NET object is
  shared across threads.
- Main DB and active WAL sidecars must stay on the same persistent storage. Preserving them permits
  recovery across process/host restart; deleting/replacing them or recreating the environment is
  fuera de la garantía.

## Validation invariants

For a correctly deserialized DTO, one deterministic pass accumulates:

1. missing/null/whitespace `customerId`;
2. missing/null/empty `items`;
3. each null element as `items[n]`;
4. missing/null/whitespace product as `items[n].productId`;
5. missing/null/non-positive quantity as `items[n].quantity`;
6. each repeated usable product after its first ordinal-equal occurrence.

Duplicate errors use the later `items[n].productId` key and reference only the first index; they
never echo the submitted ID. Invalid/null IDs are not entered in the duplicate set. Case,
whitespace and non-normalized Unicode differences remain distinct.

## Atomic creation invariant

A confirmed order always has:

- exactly one `orders` row;
- exactly one `order_items` row per accepted input item;
- no missing/additional item;
- status `Pending`;
- all rows committed by the same transaction.

Validation precedes any transaction. An insert/constraint failure rolls back the whole attempt.
`201` is possible only after commit. A read can observe either the pre-commit snapshot (possibly
`404`) or the complete committed aggregate, never a partial aggregate.

## Failure and outcome states

There is no persisted “Creating” state. Observable storage has only:

- **Absent / known pre-commit**: before `CommitInvoker` begins, after safe rollback, gate timeout,
  proven pre-commit `503`, or three UUID collisions.
- **Confirmed**: SQLite commit completed and the complete order is queryable. This includes the
  injected case where the real commit completed but `CommitInvoker` threw before returning to the
  store, even though the store cannot classify that outcome as confirmed without later inspection.
- **Application/client-uncertain**: `CommitInvoker` began but did not return normally, or commit was
  confirmed but the response path failed. Storage is still either Absent or Confirmed; this is an
  observation state, not a third database state. No rollback or compensation may presume Absent
  after commit invocation has begun.

If `CommitInvoker` returns successfully, failures in the after-commit store hook or the
post-commit/pre-response Program hook cannot change Confirmed storage and are never `503`.

No idempotency key or content uniqueness exists. Retrying a client-uncertain request can create a
second confirmed order.

## Concurrency invariants

- The in-process writer gate serializes writers and imposes a 1-second wait only.
- SQLite enforces transaction atomicity, binary uniqueness and reader snapshots.
- Readers never acquire the gate.
- A reader snapshot before commit may return `404`; this does not block a later commit.
- A reader after commit can retrieve the complete order.
- SQLite constraints remain effective if another process accesses the file, but multi-process or
  horizontal operation is unsupported.
