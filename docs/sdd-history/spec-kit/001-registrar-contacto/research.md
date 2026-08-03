# Phase 0 Research — Registrar solicitud de contacto

## Decision 1: Modelar como módulo DDD `ContactRequests`

- **Decision**: Crear un único módulo `ContactRequests` con capas Domain, Application,
  Infrastructure y Presentation.
- **Rationale**: La capacidad de registrar solicitudes de contacto es un límite funcional claro y
  autocontenido para aplicar reglas, validación y persistencia sin mezclar otros procesos.
- **Alternatives considered**:
  - Implementar en una capa transversal genérica de “forms” (rechazado por pérdida de cohesión de dominio).
  - Mezclar en `Server` sin módulo (rechazado por incumplir arquitectura del preset).

## Decision 2: Persistencia con EF Core + SQL Server y Repository Pattern

- **Decision**: Usar EF Core con SQL Server, con abstracción `IContactRequestRepository`.
- **Rationale**: Se requiere almacenar cada solicitud válida, incluyendo duplicados, con trazabilidad
  básica (`id`, `createdAt`, `status`) y reglas de consistencia simples.
- **Alternatives considered**:
  - EF Core + MongoDB (rechazado por no aportar ventaja para modelo transaccional simple).
  - Persistencia en memoria (rechazado porque no cumple requerimiento de registro persistido).

## Decision 3: Contrato HTTP único para alta de solicitud

- **Decision**: Exponer solo `POST /contact-requests` con respuesta 201 y errores 400/500.
- **Rationale**: Cubre completamente el alcance definido en `spec.md` y evita introducir endpoints
  fuera de alcance (consulta, actualización, eliminación).
- **Alternatives considered**:
  - Agregar endpoints GET/PATCH/DELETE (rechazado por explícito fuera de alcance).
  - Separar endpoint de validación previa (rechazado por complejidad innecesaria en V1).

## Decision 4: Validación con FluentValidation en Application

- **Decision**: Centralizar reglas de nombre/correo/mensaje en validator del command de Application.
- **Rationale**: Mejora testabilidad y mantiene endpoint delgado, consistente con flujo Wolverine.
- **Alternatives considered**:
  - Validar en Presentation únicamente (rechazado por dispersión y menor reutilización).
  - Validar parcialmente en Domain y parcialmente en Presentation (rechazado por duplicidad).

## Decision 5: Manejo de errores con Problem Details y ownership por capa

- **Decision**: Errores conocidos (validación/reglas) mapeados en `ContactRequests.Presentation`;
  fallback inesperado en `Common.Presentation`.
- **Rationale**: Cumple constitución y evita acoplamientos indebidos entre `Common.Presentation` y módulos.
- **Alternatives considered**:
  - Captura global única de todos los errores en Common (rechazado por perder ownership modular).

## Decision 6: Azure App Configuration obligatorio con activación condicional

- **Decision**: Integrar provider en código con `DefaultAzureCredential`, activándolo solo cuando
  exista endpoint de configuración externo.
- **Rationale**: Cumple baseline constitucional sin romper restore/build/tests locales.
- **Alternatives considered**:
  - Marcar Azure App Configuration como N/A (rechazado por incumplimiento constitucional).
  - Requerir conexión Azure siempre (rechazado por afectar reproducibilidad local).
