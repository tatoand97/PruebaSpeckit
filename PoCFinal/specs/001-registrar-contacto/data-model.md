# Data Model — Registrar solicitud de contacto

## Entity: ContactRequest

**Description**: Solicitud de contacto registrada por un visitante.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| id | UUID | Yes | Generado por el sistema; único por solicitud |
| name | string | Yes | 1..100 caracteres |
| email | string | Yes | Formato de correo válido |
| message | string | Yes | 10..1000 caracteres |
| status | enum | Yes | Valor inicial obligatorio: `Pending` |
| createdAt | datetime | Yes | Asignado por el sistema al crear |

### Validation Rules

- `name` obligatorio y máximo 100 caracteres.
- `email` obligatorio y con formato válido.
- `message` obligatorio y entre 10 y 1000 caracteres inclusive.
- Solicitudes inválidas no se persisten.
- Duplicados válidos (mismo `email` y `message`) se permiten como nuevas filas con distinto `id`.

### Lifecycle / State Transitions

- Estado inicial al crear: `Pending`.
- Cambios posteriores de estado fuera de alcance de esta feature.

## Entity: ValidationErrorDetail

**Description**: Estructura lógica para comunicar errores de validación en el formato del contrato HTTP.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| errors | map<string, string[]> | Yes | Clave: nombre canónico del campo inválido; valor: lista de mensajes de error |

### Relationships

- Un intento inválido puede tener 1..n `ValidationErrorDetail`.
- No tiene persistencia propia; es parte de respuesta de error.
