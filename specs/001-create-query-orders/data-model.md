# Data Model: Creación y consulta de órdenes

**Feature**: `001-create-query-orders`

**Source of truth**: [spec.md](./spec.md)

El modelo contiene únicamente `Order` y `OrderItem`. `Cliente` no se persiste como entidad: en esta
feature sólo existe `Order.customerId`.

## Order

Representa una orden aceptada y confirmada completamente.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `orderId` | string (UUID v4 en formato `D`) | yes | Generado por el sistema; no vacío; único globalmente entre órdenes retenidas; opaco para clientes; no incorpora contenido de la orden. |
| `customerId` | string | yes | Contiene al menos un carácter que no sea whitespace; se conserva exactamente, sin trim, cambio de case ni normalización; no se comprueba contra catálogo. |
| `status` | enum/string | yes | Único valor permitido en esta feature: `Pending`. |
| `items` | collection of `OrderItem` | yes | Al menos un elemento; cada `productId` aparece una sola vez por orden. |

### Identity

`orderId` es la identidad de la orden y la primary key de persistencia. Se genera con
`Guid.NewGuid()` y se confirma contra la restricción única de SQLite antes de exponerse.

### State

- Initial state: `Pending`.
- Transitions: ninguna dentro del alcance.
- Modification, cancellation, deletion and archival: fuera del alcance.

## OrderItem

Representa un producto y cantidad aceptados dentro de una orden.

| Field | Type | Required | Rules |
|---|---|---:|---|
| `orderId` | string | yes | Foreign key a la orden propietaria; parte de la identidad persistente. |
| `productId` | string | yes | Contiene al menos un carácter no-whitespace; se conserva exactamente; no se valida contra catálogo; único dentro de la orden mediante comparación ordinal exacta. |
| `quantity` | signed 64-bit integer | yes | Mayor que cero; debe poder representarse exactamente; nunca se trunca, redondea ni consolida. |

### Identity

La identidad de un elemento es la clave compuesta (`orderId`, `productId`). No se añade un
identificador sustituto porque ninguna operación lo requiere.

## Relationships

```text
Order (1) ─── owns ─── (1..*) OrderItem
```

- Cada `OrderItem` pertenece exactamente a una `Order`.
- Una `Order` no puede existir de forma confirmada sin al menos un `OrderItem`.
- No hay entidad o foreign key `Customer` ni `Product`; sus identificadores son valores opacos.
- El orden de los elementos en la colección no tiene semántica de negocio definida y no forma parte
  de la identidad.

## Relational mapping

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

Primary key: (`order_id`, `product_id`).

Ambas tablas se crean en modo `STRICT`. La validación C# sigue siendo responsable de la regla
Unicode completa de whitespace; los checks SQL son defensa adicional, no sustituto.

## Validation invariants

Antes de construir o persistir `Order`, se acumulan todos los errores semánticos detectables:

1. `customerId` no es nulo, vacío ni sólo whitespace.
2. `items` existe y contiene al menos un elemento.
3. Cada elemento existe.
4. Cada `productId` no es nulo, vacío ni sólo whitespace.
5. Cada `quantity` es un entero `Int64` mayor que cero.
6. Cada `productId` utilizable aparece una sola vez con igualdad ordinal exacta.

Los identificadores válidos se almacenan tal como llegaron. Las diferencias de case, whitespace
interno/externo o representación Unicode no se normalizan.

## Atomic creation invariant

Una creación confirmada cumple simultáneamente:

- exactamente una fila en `orders`;
- una fila en `order_items` por cada elemento solicitado;
- ninguna fila adicional o faltante;
- todas las filas pertenecen a la misma transacción ya confirmada.

Si cualquier insert, constraint o commit falla, la transacción completa revierte y la orden no está
disponible para consulta.

## Uniqueness under concurrency

- La primary key de `orders` impide aceptar un `orderId` repetido, aun ante concurrencia.
- Una colisión del generador reintenta con un GUID nuevo; nunca se devuelve un ID no confirmado.
- La primary key compuesta de `order_items` refuerza la prohibición de productos repetidos.
- Cada solicitud válida es independiente; no existe clave de idempotencia ni unicidad por contenido.
