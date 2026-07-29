# Feature Specification: Registrar solicitudes de contacto

**Feature Branch**: `main`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "Registrar y consultar por identificador exacto solicitudes de contacto con nombre, correo electrónico, asunto y mensaje, aplicando validación completa y sin idempotencia."

## Clarifications

### Session 2026-07-29

- Q: ¿Qué longitud máxima debe aceptar el sistema para el correo electrónico de una solicitud de contacto? → A: Sin máximo funcional adicional; debe cumplir el formato válido.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Registrar una solicitud de contacto (Priority: P1)

Como solicitante, quiero enviar mis datos de contacto y el motivo de mi consulta para que quede registrada una nueva solicitud que pueda identificar posteriormente.

**Why this priority**: El registro válido es la capacidad principal de la feature y genera el dato que habilita cualquier consulta posterior.

**Independent Test**: Puede probarse enviando nombre, correo electrónico, asunto y mensaje válidos, y verificando que se obtiene un identificador único y la fecha y hora de creación.

**Acceptance Scenarios**:

1. **Given** valores válidos para los cuatro campos obligatorios, **When** el solicitante registra la solicitud, **Then** el sistema crea una nueva solicitud y devuelve su identificador único y su fecha y hora de creación.
2. **Given** una solicitud ya registrada, **When** se vuelven a enviar los mismos valores válidos, **Then** el sistema registra otra solicitud con un identificador único diferente.
3. **Given** nombre, asunto o mensaje con espacios exteriores y contenido válido dentro de sus límites, **When** se registra la solicitud, **Then** el sistema elimina esos espacios exteriores y registra los valores normalizados.

---

### User Story 2 - Consultar una solicitud por identificador (Priority: P2)

Como solicitante que conoce el identificador exacto, quiero consultar una solicitud para recuperar sus datos y conocer cuándo fue creada.

**Why this priority**: La consulta permite recuperar posteriormente el registro creado y completa el ciclo de uso previsto.

**Independent Test**: Puede probarse registrando una solicitud y consultándola con el identificador entregado, sin aportar credenciales ni otros criterios de búsqueda.

**Acceptance Scenarios**:

1. **Given** una solicitud existente y su identificador exacto, **When** cualquier solicitante realiza la consulta, **Then** el sistema devuelve únicamente esa solicitud con sus cuatro campos, identificador y fecha y hora de creación.
2. **Given** un identificador que no corresponde a una solicitud existente, **When** se realiza la consulta, **Then** el sistema informa que la solicitud no fue encontrada y no devuelve datos de otras solicitudes.
3. **Given** un identificador existente, **When** se consulta usando un valor distinto aunque sea parcialmente coincidente, **Then** el sistema no devuelve la solicitud.

---

### User Story 3 - Rechazar solicitudes inválidas de forma completa (Priority: P3)

Como solicitante, quiero recibir un rechazo claro cuando algún dato sea inválido para poder corregirlo sin que quede una solicitud incompleta.

**Why this priority**: La validación protege la calidad del registro y evita solicitudes parciales o ambiguas.

**Independent Test**: Puede probarse enviando, de uno en uno y en combinación, campos ausentes, vacíos, fuera de límite o un correo con formato inválido, y verificando que no se crea ningún registro consultable.

**Acceptance Scenarios**:

1. **Given** que falta al menos uno de los cuatro campos, **When** se intenta registrar la solicitud, **Then** el sistema rechaza la solicitud completa e identifica los campos inválidos.
2. **Given** un nombre, asunto o mensaje que queda vacío después de eliminar espacios exteriores, **When** se intenta registrar la solicitud, **Then** el sistema rechaza la solicitud completa.
3. **Given** un correo electrónico con formato inválido, **When** se intenta registrar la solicitud, **Then** el sistema rechaza la solicitud completa.
4. **Given** que uno o más campos exceden sus límites, **When** se intenta registrar la solicitud, **Then** el sistema rechaza la solicitud completa y no genera identificador ni fecha de creación.

### Edge Cases

- Nombre, asunto o mensaje compuesto únicamente por espacios exteriores se considera vacío.
- Nombre de exactamente 1 o 150 caracteres después de normalizarlo es válido; 151 caracteres es inválido.
- Asunto de exactamente 1 o 200 caracteres después de normalizarlo es válido; 201 caracteres es inválido.
- Mensaje de exactamente 1 o 2000 caracteres después de normalizarlo es válido; 2001 caracteres es inválido.
- Un correo con apariencia incompleta, espacios exteriores o ausencia de una parte local o dominio se rechaza como formato inválido.
- Un correo con formato válido no se rechaza por un máximo funcional de longitud no definido en esta feature.
- Dos o más envíos válidos con contenido idéntico crean solicitudes independientes.
- Una consulta con identificador vacío, parcial, alterado o inexistente no devuelve otra solicitud por aproximación.
- Ante registros y consultas simultáneos, cada solicitud válida conserva su propio identificador y datos, y ninguna solicitud inválida queda parcialmente registrada.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir registrar una solicitud de contacto con nombre del solicitante, correo electrónico, asunto y mensaje.
- **FR-002**: Los cuatro campos de una solicitud de contacto DEBEN ser obligatorios.
- **FR-003**: El sistema DEBE eliminar los espacios exteriores del nombre antes de validarlo y registrarlo.
- **FR-004**: El nombre normalizado DEBE contener entre 1 y 150 caracteres, inclusive.
- **FR-005**: El correo electrónico DEBE cumplir un formato sintáctico válido y NO TIENE un máximo funcional adicional en esta feature.
- **FR-006**: El sistema DEBE eliminar los espacios exteriores del asunto antes de validarlo y registrarlo.
- **FR-007**: El asunto normalizado DEBE contener entre 1 y 200 caracteres, inclusive.
- **FR-008**: El sistema DEBE eliminar los espacios exteriores del mensaje antes de validarlo y registrarlo.
- **FR-009**: El mensaje normalizado DEBE contener entre 1 y 2000 caracteres, inclusive.
- **FR-010**: Si cualquier campo es inválido, el sistema DEBE rechazar la solicitud completa e informar los campos que no cumplen las reglas aplicables.
- **FR-011**: Una solicitud rechazada NO DEBE generar un identificador, una fecha de creación ni un registro total o parcialmente consultable.
- **FR-012**: Cada envío válido DEBE crear exactamente una nueva solicitud de contacto.
- **FR-013**: Cada solicitud válida DEBE recibir un identificador único.
- **FR-014**: Cada solicitud válida DEBE registrar la fecha y hora correspondientes a su creación.
- **FR-015**: El contenido idéntico al de una solicitud previa NO DEBE impedir un nuevo registro ni reutilizar el registro o identificador anterior.
- **FR-016**: El sistema DEBE permitir consultar una solicitud únicamente mediante la coincidencia exacta con su identificador.
- **FR-017**: Cualquier solicitante que conozca el identificador exacto DEBE poder realizar la consulta sin autenticación ni autorización.
- **FR-018**: Una consulta exitosa DEBE devolver el nombre, correo electrónico, asunto, mensaje, identificador y fecha y hora de creación de la solicitud correspondiente.
- **FR-019**: Una consulta con un identificador desconocido o no exacto DEBE informar que la solicitud no fue encontrada y NO DEBE devolver una coincidencia parcial ni datos de otra solicitud.
- **FR-020**: La feature NO DEBE permitir listar, buscar por contenido, modificar, eliminar ni clasificar solicitudes.
- **FR-021**: La feature NO DEBE incluir autenticación, autorización, notificaciones, archivos adjuntos ni integraciones externas.

### Security and Privacy Considerations

- **SR-001**: El identificador exacto constituye el único dato exigido para consultar una solicitud; la feature no ofrece controles adicionales de identidad o permisos.
- **SR-002**: Los resultados de una consulta DEBEN limitarse a una única solicitud con coincidencia exacta y NO DEBEN revelar la existencia ni el contenido de otras solicitudes.
- **SR-003**: Los rechazos y resultados de ausencia NO DEBEN exponer datos pertenecientes a otras solicitudes.
- **SR-004**: Debido al acceso deliberadamente abierto por identificador, esta primera feature NO DEBE considerarse adecuada para información sensible sin controles posteriores fuera de su alcance.

### Key Entities

- **Solicitud de contacto**: Representa una petición nueva de contacto. Contiene nombre del solicitante, correo electrónico, asunto y mensaje normalizados según las reglas aplicables, además de un identificador único y la fecha y hora de creación.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las solicitudes que cumplen todas las reglas se registra como una solicitud nueva con identificador único y fecha y hora de creación.
- **SC-002**: El 100% de las solicitudes que incumplen al menos una regla se rechaza sin dejar un registro total o parcialmente consultable.
- **SC-003**: El 100% de las consultas con un identificador exacto existente devuelve la solicitud correcta, y las consultas con identificadores desconocidos o no exactos no devuelven otra solicitud.
- **SC-004**: Todos los valores situados exactamente en los límites definidos para nombre, asunto y mensaje se aceptan, y todos los valores que los exceden se rechazan.
- **SC-005**: Bajo la carga objetivo de 25 usuarios simultáneos, se conserva la unicidad de identificadores, la correspondencia exacta de las consultas y el rechazo completo de datos inválidos.
- **SC-006**: En una evaluación con solicitantes representativos y datos válidos, al menos el 90% puede completar el registro sin asistencia en menos de 2 minutos y reconocer el identificador que debe conservar para una consulta posterior.

## Assumptions

- “Espacios exteriores” comprende el espacio en blanco al inicio y al final del nombre, asunto o mensaje; el valor normalizado es el que se registra y se devuelve en consultas.
- La validez del correo es sintáctica; no se comprueba que la dirección exista, pueda recibir mensajes o pertenezca al solicitante.
- El identificador se utiliza como valor completo y exacto. No se admiten búsquedas parciales, por contenido ni listados.
- La fecha y hora representan el momento en que la solicitud válida queda creada; su representación concreta se definirá en una fase de diseño posterior.
- Como cualquiera que conozca un identificador puede consultar los datos, se asume un entorno controlado y el uso de datos sintéticos o no sensibles durante esta primera feature.
- No existen dependencias con sistemas externos para registrar o consultar solicitudes.

## Non-Functional Requirements

- **NFR-001**: El sistema DEBE soportar una carga objetivo de 25 usuarios simultáneos realizando registros o consultas sin mezclar datos, duplicar un único envío, perder solicitudes válidas ni conservar solicitudes inválidas.
- **NFR-002**: La validación formal mediante pruebas de performance queda fuera del alcance de esta feature y pertenece a una etapa posterior del SDLC, sin eliminar la carga objetivo como requisito.

## Interface and Contract Needs

- **Interface required**: Sí; se requiere una interfaz consumible para registrar y consultar solicitudes. Su modalidad y diseño concreto se definirán en la fase de planificación.
- **Consumers**: Solicitantes que registran una solicitud o conocen su identificador exacto.
- **Expected operations and outcomes**: Registrar una solicitud válida como un registro nuevo; consultar una solicitud por su identificador exacto; obtener los datos registrados, el identificador y la fecha y hora de creación.
- **Relevant failure outcomes**: Rechazo completo por campos obligatorios ausentes, formato de correo inválido o longitudes fuera de rango; resultado de solicitud no encontrada para identificadores desconocidos o no exactos.
