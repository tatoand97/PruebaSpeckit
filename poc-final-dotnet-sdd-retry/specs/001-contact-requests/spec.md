# Feature Specification: Registro y consulta de solicitudes de contacto

**Feature Branch**: `001-contact-requests`

**Created**: 2026-07-29

**Status**: Ready for Implementation

**Input**: User description: "Construir la primera feature de un sistema sencillo de solicitudes de contacto que permita registrar y consultar solicitudes por su identificador exacto."

## Clarifications

### Session 2026-07-29

- Q: ¿Qué datos puede admitir esta feature si cualquier persona con el identificador exacto puede consultar el nombre, correo y mensaje? → A: Solo datos sintéticos o no sensibles en un entorno controlado.
- Q: ¿Qué política observable define un correo válido para esta PoC? → A: Se conserva exactamente como se recibe; no admite espacios ni caracteres no ASCII, debe contener un único `@`, partes local y dominio no vacías, y un dominio con etiquetas no vacías separadas por al menos un punto.
- Q: ¿Cómo se cuentan los límites de nombre, asunto y mensaje? → A: Por valores escalares Unicode después de retirar de ambos extremos todos los caracteres con la propiedad Unicode `White_Space`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar una solicitud de contacto (Priority: P1)

Un solicitante proporciona su nombre, correo electrónico, asunto y mensaje para dejar registrada una nueva solicitud de contacto y recibir un identificador con el que podrá consultarla posteriormente.

**Why this priority**: El registro es el propósito principal de la feature y genera la información necesaria para cualquier consulta posterior.

**Independent Test**: Puede probarse enviando datos válidos y verificando que una respuesta exitosa crea exactamente una solicitud nueva con un identificador único y una fecha y hora de creación.

**Acceptance Scenarios**:

1. **Given** un solicitante que proporciona nombre, correo electrónico, asunto y mensaje válidos, **When** registra la solicitud, **Then** el sistema crea exactamente una nueva solicitud y entrega su identificador único y su fecha y hora de creación.
2. **Given** una solicitud válida cuyo contenido coincide íntegramente con el de una solicitud existente, **When** el solicitante la registra, **Then** el sistema crea una solicitud nueva con un identificador único diferente.
3. **Given** valores de nombre, asunto o mensaje con espacios exteriores, **When** sus contenidos, después de eliminar esos espacios, cumplen los límites establecidos, **Then** el sistema registra los valores sin espacios exteriores.

---

### User Story 2 - Rechazar solicitudes inválidas de forma completa (Priority: P2)

Un solicitante recibe un rechazo cuando falta un campo o alguno de los valores incumple sus reglas, sin que quede una solicitud incompleta o parcial.

**Why this priority**: Evita conservar información inválida y permite que el solicitante corrija los datos antes de intentar nuevamente.

**Independent Test**: Puede probarse enviando por separado cada variante inválida y verificando que se rechaza en su totalidad, se informa la causa aplicable y no se crea ningún registro.

**Acceptance Scenarios**:

1. **Given** una solicitud en la que falta al menos uno de los cuatro campos obligatorios, **When** se intenta registrarla, **Then** el sistema rechaza la solicitud completa e identifica los campos inválidos.
2. **Given** una solicitud con un correo electrónico de formato inválido, **When** se intenta registrarla, **Then** el sistema rechaza la solicitud completa y no genera identificador ni fecha y hora de creación.
3. **Given** un nombre, asunto o mensaje que queda vacío o excede su longitud máxima después de eliminar espacios exteriores, **When** se intenta registrar la solicitud, **Then** el sistema la rechaza completa y no conserva ninguno de sus datos como una nueva solicitud.

---

### User Story 3 - Consultar una solicitud por su identificador (Priority: P3)

Cualquier solicitante que conozca el identificador exacto de una solicitud puede consultar posteriormente la información registrada, sin autenticarse ni demostrar que creó la solicitud.

**Why this priority**: Completa el ciclo mínimo de la feature al permitir recuperar una solicitud existente usando el identificador entregado al registrarla.

**Independent Test**: Puede probarse creando una solicitud y consultándola con el identificador entregado, así como consultando con un identificador desconocido o alterado.

**Acceptance Scenarios**:

1. **Given** una solicitud previamente registrada, **When** cualquier solicitante consulta con su identificador exacto, **Then** el sistema devuelve esa solicitud con su nombre, correo electrónico, asunto, mensaje, identificador y fecha y hora de creación.
2. **Given** un identificador que no corresponde exactamente a una solicitud existente, **When** un solicitante intenta consultarlo, **Then** el sistema informa que la solicitud no fue encontrada y no devuelve otra solicitud.
3. **Given** una solicitud existente, **When** una persona que no fue su creadora consulta con el identificador exacto, **Then** el sistema permite la consulta sin exigir autenticación ni autorización.

### Edge Cases

- Un nombre, asunto o mensaje compuesto únicamente por espacios queda vacío después de eliminar los espacios exteriores y debe rechazarse.
- Los valores de nombre, asunto y mensaje situados exactamente en sus longitudes mínima y máxima permitidas deben aceptarse; los que excedan el máximo después de eliminar espacios exteriores deben rechazarse.
- Un correo ausente, vacío o con formato inválido debe provocar el rechazo completo de la solicitud.
- Dos o más registros simultáneos con contenido idéntico deben generar solicitudes diferentes, cada una con su propio identificador único.
- Si el sistema no logra asignar un identificador único dentro de su política de resiliencia, debe rechazar el alta sin dejar registro total ni parcial e indicar que el intento puede repetirse.
- Una consulta con un identificador incompleto, alterado o desconocido no debe devolver coincidencias aproximadas ni información de otra solicitud.
- Si se detectan varias reglas incumplidas en un mismo intento, el resultado completo sigue siendo un rechazo y no debe existir registro parcial.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir registrar una solicitud de contacto con nombre del solicitante, correo electrónico, asunto y mensaje.
- **FR-002**: El sistema DEBE exigir los cuatro campos; una solicitud con cualquier campo ausente o vacío DEBE considerarse inválida.
- **FR-003**: El sistema DEBE eliminar de ambos extremos del nombre, asunto y mensaje todos los caracteres con la propiedad Unicode `White_Space` antes de evaluar su longitud y conservarlos sin esos caracteres exteriores.
- **FR-004**: El nombre, después de eliminar `White_Space` exterior, DEBE contener entre 1 y 150 valores escalares Unicode, ambos límites incluidos.
- **FR-005**: El asunto, después de eliminar `White_Space` exterior, DEBE contener entre 1 y 200 valores escalares Unicode, ambos límites incluidos.
- **FR-006**: El mensaje, después de eliminar `White_Space` exterior, DEBE contener entre 1 y 2000 valores escalares Unicode, ambos límites incluidos.
- **FR-007**: El sistema DEBE conservar el correo exactamente como se recibe y aceptar solo 1–320 caracteres ASCII imprimibles U+0021–U+007E, con un único `@`, partes local y dominio no vacías y un dominio con al menos un punto y etiquetas no vacías.
- **FR-008**: Por cada solicitud válida respondida exitosamente, el sistema DEBE crear exactamente un registro nuevo con un identificador único y la fecha y hora de creación.
- **FR-009**: El sistema DEBE tratar cada registro válido como una solicitud nueva, aunque todos sus campos coincidan con una solicitud anterior; no DEBE deduplicar solicitudes ni aplicar idempotencia.
- **FR-010**: El sistema DEBE rechazar una solicitud inválida en su totalidad, informar las reglas de validación incumplidas y evitar que quede total o parcialmente registrada.
- **FR-011**: El sistema DEBE permitir consultar posteriormente una solicitud mediante la coincidencia exacta de su identificador.
- **FR-012**: Una consulta exitosa DEBE devolver el nombre, correo electrónico, asunto, mensaje, identificador y fecha y hora de creación de la solicitud correspondiente.
- **FR-013**: Una consulta cuyo identificador no coincida exactamente con una solicitud existente DEBE informar que la solicitud no fue encontrada y no DEBE devolver coincidencias aproximadas.
- **FR-014**: El registro y la consulta de solicitudes NO DEBEN exigir autenticación ni autorización; cualquier solicitante que conozca un identificador exacto PUEDE consultar la solicitud correspondiente.
- **FR-015**: La feature NO DEBE incluir notificaciones, modificación, eliminación, clasificación automática, archivos adjuntos ni integraciones externas funcionales o de negocio; no restringe la configuración técnica transversal exigida por la Constitución.
- **FR-016**: El sistema DEBE rechazar el registro si el objeto de entrada contiene propiedades distintas de nombre, correo electrónico, asunto y mensaje.
- **FR-017**: Si el sistema no puede asignar un identificador único dentro de su política de resiliencia, DEBE responder `503` Problem Details con `Retry-After: 1` y no dejar registro total ni parcial.
- **FR-018**: Un cuerpo HTTP mayor de 8192 bytes DEBE responder `413` Problem Details y no dejar registro total ni parcial.

### Key Entities

- **Solicitud de contacto**: Representa una petición registrada por un solicitante. Contiene nombre, correo electrónico, asunto y mensaje, además del identificador único y la fecha y hora de creación generados al aceptarla.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100 % de las solicitudes que cumplen todas las reglas y completan la asignación de identidad dentro de tres intentos generan exactamente un registro nuevo con identificador único y un único instante de creación; el agotamiento falla sin registro.
- **SC-002**: El 100 % de las solicitudes que incumplen al menos una regla son rechazadas sin dejar registros totales ni parciales.
- **SC-003**: El 100 % de las consultas con un identificador exacto existente devuelven la solicitud correcta, y el 100 % de las consultas con identificadores desconocidos o alterados informan que no fue encontrada sin revelar otra solicitud.
- **SC-004**: Dos registros válidos con contenido idéntico que finalizan exitosamente generan identificadores diferentes y solicitudes independientes.
- **SC-005**: En aceptación manual, un operador puede completar el registro y la recuperación exacta usando únicamente el contrato OpenAPI y `quickstart.md`, sin conocimiento interno, asistencia adicional ni credenciales.
- **SC-006 (diferido al gate posterior de performance)**: Bajo responsabilidad de performance QA, 25 usuarios simultáneos durante 10 minutos, con una mezcla objetivo 50% POST válidos y 50% GET de identificadores creados en la misma ejecución, completan sin respuestas `5xx`, pérdida, mezcla, corrupción ni duplicación involuntaria; la evidencia futura es el reporte de esa ejecución y no bloquea la finalización de esta etapa V1.

## Assumptions

- La fecha y hora de creación corresponden al momento en que el sistema acepta la solicitud y representan un instante inequívoco para su consulta posterior.
- El identificador es generado por el sistema; el solicitante no lo elige ni lo modifica durante el registro.
- Las validaciones de longitud se realizan por valores escalares Unicode después de retirar `White_Space` Unicode exterior.
- Los detalles técnicos de la interfaz, la generación del identificador, el registro de la fecha y hora y la conservación de las solicitudes se decidirán durante la planificación.
- Las pruebas de performance no forman parte de esta feature en la etapa actual, aunque la carga objetivo permanece como requisito.

## Non-Functional Requirements

- **NFR-001**: El comportamiento funcional de registro y consulta DEBE soportar 25 usuarios simultáneos durante 10 minutos con mezcla objetivo 50% POST válidos y 50% GET exactos, cero respuestas `5xx` y cero pérdida, mezcla, corrupción o duplicación involuntaria.
- **NFR-002**: La validación de la carga objetivo mediante pruebas de performance se realizará en una etapa posterior del SDLC y queda fuera del alcance de la etapa actual.
- **NFR-003**: Cada rechazo DEBE identificar el campo y la regla incumplida sin repetir su valor; una solicitud no encontrada DEBE indicar únicamente que no existe coincidencia exacta e incluir un `traceId`, sin revelar datos de otras solicitudes.
- **NFR-004**: Esta PoC DEBE usar exclusivamente el dataset sintético de `quickstart.md` (Ada Lovelace, dominios `.test` y mensajes marcados como sintéticos) o variaciones generadas sin datos de personas reales.
- **NFR-005**: Antes de la aceptación manual, el operador de la PoC DEBE declarar que el despliegue está restringido al equipo o red de evaluación y que el conjunto utilizado contiene solo datos sintéticos o no sensibles; esa declaración y el conjunto de prueba constituyen la evidencia operacional.

## Interface and Contract Needs

- **Interface required**: Se requiere una interfaz para registrar y consultar solicitudes; su modalidad técnica se definirá en `plan.md`.
- **Consumers**: Solicitantes de contacto, sin autenticación ni autorización.
- **Expected operations and outcomes**: Registrar una nueva solicitud válida y recibir su identificador y fecha y hora de creación; consultar una solicitud existente mediante su identificador exacto.
- **Relevant failure outcomes**: Rechazo completo por campos ausentes, vacíos, fuera de longitud o correo con formato inválido; solicitud no encontrada cuando el identificador no tiene una coincidencia exacta. No aplican fallos de autenticación, autorización ni conflicto por contenido duplicado dentro de este alcance.
