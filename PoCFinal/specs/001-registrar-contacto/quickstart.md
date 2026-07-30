# Quickstart — Registrar solicitud de contacto

## Objetivo

Validar end-to-end que el registro de solicitudes de contacto cumple `spec.md` y el contrato en
`contracts/openapi.yaml`.

## Prerrequisitos

- .NET SDK 10 instalado.
- Node.js compatible con Redocly (`>=22.12.0` o `>=20.19.0 <21.0.0`).
- npm `>=10`.
- Configuración local del proyecto disponible.

## Comandos base

```powershell
dotnet restore
dotnet build -c Release
dotnet test
dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura
npx --yes @redocly/cli@2.41.1 lint specs/001-registrar-contacto/contracts/openapi.yaml
```

## Escenarios de validación funcional

### 1) Registro exitoso

**Entrada**: `name` válido, `email` válido, `message` entre 10 y 1000 caracteres.  
**Esperado**:
- HTTP 201.
- Respuesta con `id`, `createdAt`, `status = Pending`.
- Se registra una nueva solicitud.

### 2) Validación de nombre inválido

**Entrada**: `name` vacío o >100 caracteres.  
**Esperado**:
- HTTP 400 con Problem Details.
- `errors.name` presente.
- Sin persistencia de la solicitud.

### 3) Validación de correo inválido

**Entrada**: correo sin formato válido.  
**Esperado**:
- HTTP 400 con Problem Details.
- `errors.email` presente.
- Sin persistencia de la solicitud.

### 4) Validación de mensaje inválido

**Entrada**: `message` con <10 o >1000 caracteres.  
**Esperado**:
- HTTP 400 con Problem Details.
- `errors.message` presente.
- Sin persistencia de la solicitud.

### 5) Duplicados válidos permitidos

**Entrada**: dos envíos consecutivos con el mismo `email` y `message` (válidos).  
**Esperado**:
- Ambos responden HTTP 201.
- Cada respuesta contiene `id` distinto.
- Se crean dos registros independientes con estado `Pending`.

## Referencias

- Especificación: [spec.md](./spec.md)
- Modelo de datos: [data-model.md](./data-model.md)
- Contrato HTTP: [openapi.yaml](./contracts/openapi.yaml)
- Plan técnico: [plan.md](./plan.md)
