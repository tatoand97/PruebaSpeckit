# Feature Specification: Crear y consultar órdenes

**Feature Branch**: `001-create-query-orders`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "Construir la primera feature de un sistema sencillo de gestión de órdenes para crear órdenes válidas y consultarlas posteriormente por su identificador, sin incluir pagos, inventario, descuentos, envío, cancelación, modificación, autenticación ni integraciones externas."

## Clarifications

### Session 2026-07-29

- Q: ¿Quién puede consultar una orden cuando conoce su identificador exacto? → A: Cualquier
  solicitante que conozca el identificador exacto.
- Q: ¿Qué ocurre cuando se reciben solicitudes válidas con datos idénticos? → A: Cada solicitud
  crea una orden nueva con un identificador diferente; no hay idempotencia.
- Q: ¿Qué identificadores de cliente y producto se aceptan y debe comprobarse su existencia? → A:
  Se acepta cualquier identificador con al menos un carácter distinto de espacio y no se valida su
  existencia contra otro sistema.
- Q: ¿Qué ocurre si un producto aparece más de una vez en la misma solicitud? → A: Se rechaza la
  solicitud completa y se identifica el producto duplicado.
- Q: ¿Qué capacidad simultánea debe considerar esta feature? → A: 25 usuarios simultáneos; el
  performance testing pertenece a una etapa posterior del SDLC y no forma parte de esta PoC local.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Crear una orden válida (Priority: P1)

Un solicitante registra una orden con un identificador de cliente y uno o más productos con sus
cantidades para obtener una orden identificable que pueda consultarse posteriormente.

**Why this priority**: La creación origina la información que administra esta primera feature y
entrega el valor mínimo del sistema.

**Independent Test**: Puede validarse presentando datos de orden válidos y comprobando que se
obtenga un identificador nuevo junto con los datos aceptados.

**Acceptance Scenarios**:

1. **Given** un identificador de cliente y una lista de productos válidos con cantidades positivas,
   **When** el solicitante crea la orden, **Then** el sistema registra una nueva orden y devuelve su
   identificador y sus datos.
2. **Given** una solicitud con datos inválidos, **When** el solicitante intenta crear la orden,
   **Then** el sistema rechaza la solicitud completa, explica los datos inválidos y no crea una
   orden parcial.
3. **Given** una solicitud sin productos, **When** el solicitante intenta crear la orden, **Then**
   el sistema la rechaza e indica que se requiere al menos un producto.
4. **Given** una solicitud que repite un producto, **When** el solicitante intenta crear la orden,
   **Then** el sistema rechaza la solicitud completa e identifica el producto duplicado.
5. **Given** dos solicitudes válidas con exactamente los mismos datos, **When** se aceptan ambas,
   **Then** el sistema crea dos órdenes con identificadores diferentes.

---

### User Story 2 - Consultar una orden por identificador (Priority: P2)

Un solicitante recupera una orden creada anteriormente mediante su identificador exacto para
conocer el cliente, los productos, las cantidades y la fecha de creación registrados.

**Why this priority**: La consulta completa el objetivo de recuperar posteriormente la información
creada, pero depende de que exista una orden.

**Independent Test**: Puede validarse partiendo de una orden conocida, consultándola por su
identificador y comparando la información recuperada con la registrada.

**Acceptance Scenarios**:

1. **Given** una orden existente, **When** se consulta con su identificador exacto, **Then** el
   sistema devuelve el identificador de la orden, el cliente, los productos, las cantidades y la
   fecha de creación registrados.
2. **Given** un identificador que no corresponde a una orden, **When** se realiza la consulta,
   **Then** el sistema informa que la orden no existe sin devolver datos de otra orden.
3. **Given** un identificador de orden vacío o inválido, **When** se realiza la consulta, **Then**
   el sistema rechaza la solicitud e identifica el dato inválido.

### Edge Cases

- Una solicitud de creación contiene el mismo producto más de una vez.
- Se reciben dos solicitudes de creación con exactamente los mismos datos.
- El identificador de cliente o de producto está vacío o contiene únicamente espacios.
- La cantidad de un producto es cero, negativa, superior a 2.147.483.647 o no es un número entero.
- Se consulta un identificador inexistente o con formato inválido.
- Varias solicitudes crean o consultan órdenes de manera simultánea.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema DEBE permitir crear una orden con un identificador de cliente y una lista
  no vacía de productos.
- **FR-002**: Cada producto de una solicitud DEBE incluir un identificador y una cantidad entera
  entre 1 y 2.147.483.647, ambos inclusive.
- **FR-003**: Los identificadores de cliente y producto DEBEN contener al menos un carácter
  distinto de espacio; el sistema no valida su existencia contra otro sistema, los conserva sin
  normalización y los compara exactamente con distinción entre mayúsculas y minúsculas.
- **FR-004**: El sistema DEBE rechazar una creación cuando falte el identificador de cliente, falte
  el identificador de algún producto o una cantidad no sea un entero positivo.
- **FR-005**: El sistema DEBE rechazar una creación que no contenga productos.
- **FR-006**: El rechazo de una creación DEBE ser atómico: no se crea ninguna orden ni se conserva
  una parte de la solicitud rechazada.
- **FR-007**: Cada solicitud válida DEBE crear una orden nueva con un identificador único, incluso
  cuando sus datos sean idénticos a los de otra solicitud; esta feature no aplica idempotencia.
- **FR-008**: El sistema DEBE conservar para cada orden su identificador, el identificador de
  cliente, los productos con sus cantidades y la fecha de creación.
- **FR-009**: El sistema DEBE permitir consultar una orden mediante su identificador exacto.
- **FR-010**: Cualquier solicitante que conozca el identificador exacto de una orden DEBE poder
  consultarla, sin autenticación en esta feature.
- **FR-011**: La consulta exitosa DEBE devolver los mismos datos de negocio que fueron registrados
  para la orden.
- **FR-012**: Cuando no exista una orden para el identificador consultado, el sistema DEBE informar
  la ausencia sin devolver datos de otra orden.
- **FR-013**: Las solicitudes inválidas DEBEN identificar los campos o productos que impiden
  aceptarlas, sin exponer información interna del sistema.
- **FR-014**: Si un producto aparece más de una vez en una solicitud, el sistema DEBE rechazar la
  solicitud completa e identificar el producto duplicado.
- **FR-015**: La feature DEBE limitarse a crear y consultar órdenes; no DEBE incluir pagos,
  inventario, descuentos, envío, cancelación, modificación, autenticación ni integraciones
  externas.

### Key Entities

- **Orden**: Registro identificable de una solicitud aceptada, con cliente, productos, cantidades y
  fecha de creación.
- **Producto de orden**: Producto incluido en una orden junto con la cantidad solicitada.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las solicitudes que cumplen las reglas documentadas crea una orden con un
  identificador consultable.
- **SC-002**: El 100% de las solicitudes inválidas se rechaza sin crear órdenes parciales y señala
  los datos que deben corregirse.
- **SC-003**: El 100% de las consultas con un identificador existente devuelve los datos
  registrados para esa orden, sin alterarlos.
- **SC-004**: El 100% de las consultas con un identificador inexistente informa la ausencia sin
  revelar datos de otras órdenes.
- **SC-005**: Un solicitante puede completar una creación válida y recuperar la orden resultante en
  una misma sesión de validación en menos de dos minutos.

## Assumptions

- Esta es la primera feature del sistema Orders y no depende de datos o servicios preexistentes.
- El solicitante proporciona los identificadores de cliente y producto y no se comprueba su
  existencia contra otro sistema.
- Los importes, precios y totales monetarios no forman parte de la información mínima de esta
  feature.
- No se establecen estados posteriores del ciclo de vida: una orden creada solo puede consultarse.

## Non-Functional Requirements

- **NFR-001**: La feature DEBE considerar una carga objetivo de 25 usuarios simultáneos para las
  operaciones de creación y consulta.
- **NFR-002**: Los resultados de rechazo no DEBEN revelar datos de otras órdenes ni detalles
  internos sensibles.
- **NFR-003**: La validación mediante performance testing pertenece a una etapa posterior del SDLC
  y no forma parte de esta PoC local.

## Interface and Contract Needs

- **Interface required**: Una interfaz de servicio para solicitar creación y consulta; su forma
  técnica se define durante la planificación.
- **Consumers**: Solicitantes que crean órdenes o conocen el identificador exacto de una orden.
- **Expected operations and outcomes**: Crear una orden válida y obtener su identificador; consultar
  una orden existente; informar solicitudes inválidas o una orden inexistente.
- **Relevant failure outcomes**: Datos de cliente o producto inválidos, lista vacía, cantidades
  inválidas, productos duplicados e identificador de orden inválido o inexistente.
