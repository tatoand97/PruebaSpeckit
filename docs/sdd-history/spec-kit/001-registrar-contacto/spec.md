# Feature Specification: Registrar solicitud de contacto

**Feature Branch**: `[001-registrar-contacto]`

**Created**: 2026-07-30

**Status**: Draft

**Input**: User description: "Genera la especificación usando docs/HU-001-registrar-contacto.md."

## Clarifications

### Session 2026-07-30

- Q: ¿Cómo debe tratar el sistema los envíos repetidos con el mismo correo y el mismo mensaje? → A: Permitir duplicados; cada envío válido se registra como una nueva solicitud.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar solicitud válida (Priority: P1)

Como visitante del sitio, quiero enviar mis datos de contacto para que un asesor pueda comunicarse conmigo.

**Why this priority**: Es el objetivo principal de la historia de usuario y entrega valor directo al negocio al capturar oportunidades de contacto.

**Independent Test**: Se puede probar enviando una solicitud con nombre, correo y mensaje válidos, verificando que se registra y devuelve identificador, fecha/hora y estado inicial.

**Acceptance Scenarios**:

1. **Given** un visitante con nombre, correo y mensaje válidos, **When** registra una solicitud de contacto, **Then** la solicitud queda registrada y la respuesta incluye identificador único, fecha/hora de creación y estado `Pending`.
2. **Given** un visitante que ya registró una solicitud válida, **When** consulta el resultado inmediato de su envío, **Then** recibe los datos de confirmación de la solicitud recién creada.

---

### User Story 2 - Informar errores de validación (Priority: P2)

Como visitante del sitio, quiero recibir errores claros cuando ingreso datos inválidos para corregirlos antes de enviar la solicitud.

**Why this priority**: Evita registros defectuosos y reduce fricción para completar el contacto correctamente.

**Independent Test**: Se puede probar enviando combinaciones inválidas (campos vacíos, correo inválido, mensaje fuera de rango) y verificando que se informan campos con error y no se almacena la solicitud.

**Acceptance Scenarios**:

1. **Given** un visitante con uno o más campos inválidos, **When** intenta registrar la solicitud, **Then** recibe una respuesta con los campos en error y sus motivos.
2. **Given** un intento de registro inválido, **When** finaliza la validación, **Then** la solicitud no se almacena.

---

### Edge Cases

- ¿Qué sucede cuando el nombre tiene exactamente 100 caracteres? Se considera válido.
- ¿Qué sucede cuando el mensaje tiene exactamente 10 o 1.000 caracteres? Se considera válido.
- ¿Qué sucede cuando el nombre supera 100 caracteres o el mensaje supera 1.000 caracteres? Debe rechazarse e informarse el campo con error.
- ¿Qué sucede cuando el mensaje tiene menos de 10 caracteres o los campos obligatorios están vacíos? Debe rechazarse e informarse cada campo inválido.
- ¿Qué sucede cuando el correo tiene formato inválido (sin dominio o sin `@`)? Debe rechazarse e informarse el error del correo.
- ¿Qué sucede cuando un visitante envía varias veces el mismo correo y mensaje con datos válidos? Cada envío debe registrarse como una nueva solicitud.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir que un visitante registre una solicitud de contacto proporcionando nombre, correo electrónico y mensaje.
- **FR-002**: El sistema MUST exigir que el nombre sea obligatorio y tenga una longitud máxima de 100 caracteres.
- **FR-003**: El sistema MUST exigir que el correo electrónico sea obligatorio y cumpla formato válido definido como: una sola `@`, parte local no vacía, dominio con al menos un punto y sin espacios.
- **FR-004**: El sistema MUST exigir que el mensaje sea obligatorio y tenga una longitud entre 10 y 1.000 caracteres, inclusive.
- **FR-005**: El sistema MUST registrar la solicitud solo cuando todos los datos sean válidos.
- **FR-006**: El sistema MUST asignar automáticamente a toda nueva solicitud un identificador único, fecha/hora de creación y estado inicial `Pending`.
- **FR-007**: El sistema MUST responder al registro válido incluyendo identificador único, fecha/hora de creación y estado inicial `Pending`.
- **FR-008**: El sistema MUST informar de forma explícita los campos con error cuando la solicitud sea inválida.
- **FR-009**: El sistema MUST garantizar que una solicitud inválida no se almacene.
- **FR-010**: El sistema MUST limitar el alcance de esta feature al registro de nuevas solicitudes; quedan excluidos envío de correos, autenticación, asignación automática de asesores, integración con CRM y operaciones de consulta/actualización/eliminación.
- **FR-011**: El sistema MUST tratar nombre, correo y mensaje como datos de contacto y no exponer información adicional del visitante en la respuesta de confirmación.
- **FR-012**: El sistema MUST permitir envíos duplicados válidos (mismo correo y mismo mensaje), registrando cada envío como una nueva solicitud independiente.

### Key Entities *(include if feature involves data)*

- **Solicitud de Contacto**: Representa el registro de interés de un visitante. Atributos clave: identificador único, nombre, correo electrónico, mensaje, fecha/hora de creación y estado.
- **Resultado de Validación**: Representa el detalle de errores por campo cuando una solicitud no cumple las reglas de entrada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% de solicitudes con datos válidos quedan registradas y devuelven identificador, fecha/hora y estado `Pending`.
- **SC-002**: 100% de solicitudes con datos inválidos son rechazadas, incluyen detalle de campos con error y no generan registro persistido.
- **SC-003**: En una muestra de validación de al menos 20 intentos consecutivos con datos válidos, al menos 19 registros se completan exitosamente en el primer intento.
- **SC-004**: El 100% de solicitudes nuevas registradas inician en estado `Pending`.

## Assumptions

- El visitante realiza el registro sin autenticación previa.
- La validación de correo aplica exactamente la regla definida en FR-003.
- La fecha/hora de creación se expresa con la referencia temporal oficial del sistema.
- El estado `Pending` está definido como estado inicial válido del proceso comercial de contacto.
- El alcance de la feature se limita al alta de solicitudes y no incluye procesos posteriores de atención.
