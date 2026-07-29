# Data Model: Registro y consulta de solicitudes de contacto

**Feature**: `001-contact-requests`
**Storage decision**: EF Core + SQL Server

## Aggregate: ContactRequest

`ContactRequest` es la raíz de agregado y la única entidad de esta feature.

| Field | Domain / storage type | Required | Rules |
|---|---|---:|---|
| `Id` | `Guid` / `uniqueidentifier` | Yes | Generado por el sistema como UUID v7; clave primaria; no modificable |
| `Name` | `string` / `nvarchar(300)` | Yes | Recortar `White_Space` exterior; 1–150 valores escalares; capacidad para pares sustitutos |
| `Email` | `string` / `nvarchar(320)` | Yes | 1–320 ASCII imprimibles; política FR-007; se conserva sin normalización |
| `Subject` | `string` / `nvarchar(400)` | Yes | Recortar `White_Space` exterior; 1–200 valores escalares; capacidad para pares sustitutos |
| `Message` | `string` / `nvarchar(4000)` | Yes | Recortar `White_Space` exterior; 1–2000 valores escalares; capacidad para pares sustitutos |
| `CreatedAtUtc` | `DateTimeOffset` / `datetimeoffset` | Yes | Instante UTC obtenido al aceptar la solicitud; no modificable |

## Identity and indexes

- `Id` es la clave primaria y única.
- La aplicación genera `Guid.CreateVersion7()` antes de insertar.
- No existe índice único por contenido: FR-009 exige que altas idénticas creen recursos distintos.
- No se requieren índices secundarios; la única consulta definida es por clave exacta.

## Construction and invariants

La factory de Domain:

1. recibe los cuatro valores de entrada, un `Id` generado y `CreatedAtUtc`;
2. recorta `White_Space` Unicode exclusivamente de los extremos de `Name`, `Subject` y `Message`;
3. valida obligatoriedad, longitudes por valores escalares y la política exacta de correo FR-007;
4. rechaza todo el agregado si alguna regla falla; y
5. devuelve una entidad inmutable desde fuera del agregado.

El validador de Application aplica la misma política antes del handler para producir detalles por
campo. Las guardas de Domain siguen siendo la autoridad que impide estado inválido.

## Relationships

No hay relaciones con otras entidades o módulos. Los identificadores de solicitantes, usuarios,
categorías, adjuntos o notificaciones no forman parte de esta feature.

## State transitions

```text
Input candidate
  ├─ invalid -> Rejected (no aggregate and no persistence)
  └─ valid   -> Created -> Persisted
```

`ContactRequest` no tiene transiciones posteriores: modificación, eliminación, clasificación y
notificación están fuera de alcance.

## Persistence and atomicity

- `IContactRequestRepository.AddAsync` agrega una sola raíz y confirma con un único
  `SaveChangesAsync`.
- Ante una colisión verificada de la PK, el repositorio descarta la entidad fallida del change
  tracker y comunica `ContactRequestIdentifierCollisionException`; otros fallos se propagan sin
  traducirse. Esto permite un intento limpio con otro UUID.
- Si la validación o persistencia falla antes del commit, no existe registro total ni parcial.
- Cada command válido crea una entidad nueva aun cuando su contenido sea idéntico.
- La unicidad de la clave se protege tanto por generación UUID v7 como por la clave primaria.
- La lectura usa comparación exacta de `Id`; no existen búsquedas parciales o aproximadas.
- Operaciones concurrentes usan unidades de trabajo independientes del `DbContext`; no se comparte
  una instancia entre solicitudes HTTP.

## EF Core mapping

La configuración de entidad vive en
`src/Modules/ContactRequests/Infrastructure/Persistence/Configurations/ContactRequestConfiguration.cs`.
El `DbContext` y el repositorio concreto viven exclusivamente en Infrastructure. Application y
Presentation no referencian EF Core, SQL Server ni `DbContext`.

El ciclo de vida físico del esquema es un prerrequisito externo. Esta feature no crea migrations,
snapshots, comandos `dotnet-ef`, `database update` ni llamadas a `EnsureCreated()`.

## Data classification

Aunque los campos podrían contener datos personales en un sistema real, esta PoC admite
únicamente datos sintéticos o no sensibles en un entorno controlado. Nombre, correo, asunto y
mensaje nunca se incluyen en logs, trazas, métricas ni errores.
