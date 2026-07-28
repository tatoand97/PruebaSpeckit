# Feature Specification: Creación y consulta de órdenes

**Feature Branch**: `main` *(rama activa; no se creó una rama específica para la feature)*

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "Construir la primera feature de un sistema sencillo de gestión de órdenes para crear órdenes válidas y consultarlas posteriormente por su identificador, sin incluir pagos, inventario, descuentos, envío, cancelación, modificación, autenticación ni integraciones externas."

## Scope

Esta feature contiene exactamente dos capacidades de negocio: crear una orden para un cliente con
uno o más productos y consultar posteriormente una orden mediante el identificador único asignado
por el sistema.

Quedan fuera del alcance los pagos, el inventario, los descuentos, el envío, la cancelación, la modificación de órdenes, la autenticación de usuarios y cualquier integración con sistemas externos. La especificación no define arquitectura, estructura de proyectos, tecnología de exposición, mecanismo de persistencia, base de datos, ORM, librerías ni código.

El contrato HTTP aprobado representa esas dos capacidades mediante tres operaciones:
`POST /orders`, `GET /orders/{orderId}` y `GET /orders`. La última existe exclusivamente para
rechazar con `400` una consulta que omitió el identificador; nunca enumera ni busca órdenes.

## Clarifications

### Session 2026-07-28

- Q: En esta PoC sin autenticación, ¿quién debe poder consultar una orden si conoce su identificador? → A: Cualquier solicitante que conozca el identificador exacto de la orden.
- Q: Si la misma solicitud válida de creación se envía dos veces, ¿qué resultado debe producir el segundo envío? → A: Cada envío válido crea una orden nueva con identificador distinto.
- Q: ¿Debe la PoC aceptar cualquier identificador no vacío de cliente y producto, o comprobar que corresponda a registros conocidos? → A: Aceptar cualquier identificador no vacío, sin comprobar su existencia.
- Q: Si el mismo producto aparece varias veces en una solicitud, ¿cómo debe quedar representado en la orden? → A: Rechazar toda la solicitud e informar el producto duplicado.
- Q: ¿Qué límites de capacidad deben formar parte del contrato verificable de la PoC? → A: Mantener 25 usuarios simultáneos, sin máximos de negocio para productos o cantidades.

## Approved Behavioral Decisions

- Una orden confirmada sobrevive reinicios del proceso y del host mientras se conserve el
  almacenamiento SQLite persistente. Recrear por completo el entorno o eliminar, reemplazar o
  perder ese almacenamiento queda fuera de la garantía.
- Una respuesta `201` sólo puede emitirse después de confirmar toda la orden. Todo `503` de
  creación garantiza que no se confirmó una orden. Si el commit terminó pero la respuesta se
  pierde o el cliente no puede saber si la recibió, la orden puede existir; como no hay
  idempotencia, reenviar la solicitud puede crear otra orden.
- Los identificadores de orden son UUID v4. La primary key persistente es la garantía definitiva
  de unicidad. Una colisión provoca rollback y un nuevo UUID, con tres intentos totales; agotar los
  tres produce `500` genérico y ninguna orden confirmada.
- La PoC ejecuta una sola instancia. Una lectura anterior al commit puede responder `404`, ninguna
  lectura puede observar una orden parcial y las consultas posteriores al commit pueden leer la
  orden. Ese `404` no impide que una creación concurrente se confirme después.
- `POST /orders` admite como máximo 1 MiB (1.048.576 bytes) de cuerpo HTTP. Es un límite operativo,
  no de negocio; excederlo produce `413`, no trunca datos y no crea ninguna orden.
- Todos los errores producidos por la aplicación usan Problem Details. Rechazos o fallos del host
  que ocurran fuera del pipeline controlado —por ejemplo ciertos `413`, `405`, timeouts o
  desconexiones— no tienen esa garantía.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Crear una orden válida (Priority: P1)

Un cliente registra una orden indicando su identificador y uno o más productos, cada uno con una cantidad positiva, para obtener una orden reconocible que pueda usarse posteriormente.

**Why this priority**: La creación es el origen del valor de la feature; sin una orden válida no existe información que consultar.

**Independent Test**: Se puede probar enviando datos válidos de un cliente con uno o varios productos y verificando que se crea exactamente una orden con un identificador único, estado `Pending` y los datos solicitados.

**Acceptance Scenarios**:

1. **Given** un identificador de cliente válido y un producto con cantidad 1, **When** el cliente solicita crear la orden, **Then** el sistema crea exactamente una orden, le asigna un identificador único y devuelve el estado `Pending`.
2. **Given** un identificador de cliente válido y varios productos distintos con cantidades enteras mayores que cero, **When** el cliente solicita crear la orden, **Then** el sistema crea exactamente una orden que contiene todos los productos y sus cantidades solicitadas.
3. **Given** dos o más solicitudes válidas, incluso si se procesan al mismo tiempo, **When** se crean sus órdenes, **Then** cada orden recibe un identificador diferente.
4. **Given** una orden ya creada, **When** se envía nuevamente una solicitud válida con datos idénticos, **Then** el sistema crea otra orden con un identificador diferente.
5. **Given** identificadores de cliente y productos no conocidos que contienen al menos un carácter distinto de espacio, **When** se envía una solicitud que cumple las demás reglas, **Then** el sistema crea la orden sin comprobar la existencia de esos identificadores.

---

### User Story 2 - Consultar una orden existente (Priority: P2)

Un solicitante que conoce el identificador único de una orden ya creada la consulta para conocer sus datos y su estado.

**Why this priority**: La consulta completa el ciclo mínimo de la PoC y permite recuperar el resultado de una creación previa.

**Independent Test**: Se puede probar partiendo de una orden existente conocida, consultándola por su identificador y verificando que se devuelven el identificador de la orden, el identificador del cliente, todos los productos con sus cantidades y el estado `Pending`.

**Acceptance Scenarios**:

1. **Given** una orden existente y cualquier solicitante que conoce su identificador exacto, **When** el solicitante consulta la orden, **Then** el sistema devuelve esa orden y no otra, con todos sus datos y su estado.
2. **Given** varias órdenes existentes para el mismo cliente o para clientes distintos, **When** se consulta el identificador de una de ellas, **Then** el resultado contiene únicamente la orden correspondiente.

---

### User Story 3 - Recibir errores claros sin alterar las órdenes (Priority: P3)

Un cliente recibe una explicación clara cuando intenta crear una orden inválida o consultar una orden inexistente, sin que el intento deje una orden parcial o modifique órdenes existentes.

**Why this priority**: Los errores comprensibles y la creación atómica protegen la integridad del registro y permiten corregir la solicitud.

**Independent Test**: Se puede probar con solicitudes que incumplan cada regla de validación y con identificadores inexistentes, comprobando el resultado informado y verificando que no aparece ninguna orden nueva o parcial.

**Acceptance Scenarios**:

1. **Given** una solicitud sin productos, **When** se intenta crear la orden, **Then** el sistema rechaza la solicitud, informa que se requiere al menos un producto y no crea una orden.
2. **Given** una solicitud con varios productos y al menos una cantidad inválida, **When** se intenta crear la orden, **Then** se rechaza la solicitud completa y no se crea ninguna parte de la orden.
3. **Given** un identificador de orden no asociado a ninguna orden, **When** se realiza la consulta, **Then** el sistema informa claramente que la orden no fue encontrada y no devuelve datos de otra orden.
4. **Given** una solicitud que repite un identificador de producto, **When** se intenta crear la orden, **Then** el sistema rechaza la solicitud completa, identifica el producto duplicado y no consolida ni crea elementos.

### Edge Cases

- Si el identificador del cliente falta, está vacío o contiene solamente espacios, la solicitud completa se rechaza.
- Si la colección de productos falta o está vacía, la solicitud completa se rechaza.
- Si un producto no tiene identificador, su identificador está vacío o contiene solamente espacios, la solicitud completa se rechaza.
- Si un identificador de cliente o producto contiene al menos un carácter distinto de espacio, no se rechaza por ser desconocido.
- Si una cantidad falta, es nula, no usa una representación JSON aceptable como `Int64`, está fuera
  del rango `Int64`, es cero o es negativa, la solicitud completa se rechaza.
- Si una cantidad positiva no puede aceptarse exactamente, la solicitud completa se rechaza; el valor nunca se trunca, redondea ni altera silenciosamente.
- Si el mismo identificador de producto aparece más de una vez en una solicitud, la solicitud completa se rechaza indicando el duplicado.
- Si una solicitud contiene productos válidos e inválidos, ningún producto de esa solicitud da lugar a una orden parcial.
- Si ocurre cualquier fallo antes de confirmar la creación completa, no queda disponible una orden
  parcial. Un `503` de creación siempre significa que no hubo commit; un `500` o una desconexión
  durante una frontera de resultado incierto no autoriza a asumir que la orden no existe.
- Si se envía dos veces la misma solicitud válida, cada envío se considera una intención de creación independiente y produce una orden distinta con identificador único.
- Si varias solicitudes se crean simultáneamente, ninguna combinación de concurrencia puede producir identificadores de orden duplicados.
- Si el identificador de consulta falta, está vacío o contiene solamente espacios, la consulta se rechaza como inválida; si es un identificador no vacío que no corresponde a una orden, el resultado es "orden no encontrada".
- Los identificadores se consideran valores opacos: para consultar una orden se usa sin
  alteraciones la ruta `Location` devuelta al crearla.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El sistema MUST permitir solicitar la creación de una orden indicando un identificador de cliente y una colección de productos.
- **FR-002**: Cada producto solicitado MUST incluir un identificador de producto y una cantidad.
- **FR-003**: El identificador del cliente y cada identificador de producto MUST contener al menos un carácter distinto de espacio. Cualquier identificador que cumpla esta regla MUST aceptarse sin comprobar su existencia.
- **FR-004**: Una orden MUST contener como mínimo un producto.
- **FR-005**: La cantidad de cada producto MUST ser un número entero mayor que cero representable
  exactamente como `Int64`; fracciones, notación exponencial y valores fuera de ese rango MUST
  rechazarse sin conversión.
- **FR-006**: Cada identificador de producto MUST aparecer una sola vez dentro de una misma solicitud de creación; si se repite, el sistema MUST rechazar la solicitud completa e informar cuál producto está duplicado.
- **FR-007**: El sistema MUST validar la solicitud completa antes de crear cualquier parte de la orden.
- **FR-008**: Si un documento JSON correctamente deserializable incumple una o más reglas
  semánticas, el sistema MUST rechazarlo completo, informar todas las reglas semánticas
  incumplidas que puedan detectarse a partir de ese documento y MUST NOT crear una orden total ni
  parcial. Un fallo de parsing, tipo o rango puede impedir evaluar reglas semánticas posteriores,
  pero MUST comunicar que el body no pudo interpretarse.
- **FR-009**: Por cada solicitud válida aceptada, el sistema MUST crear exactamente una orden nueva,
  aunque sus datos sean idénticos a los de una solicitud anterior. La feature MUST NOT implementar
  claves de idempotencia.
- **FR-010**: El sistema MUST asignar a cada orden creada un UUID v4 único que no haya sido asignado
  a ninguna otra orden retenida. La restricción persistente de unicidad es definitiva; ante
  colisión se permiten tres intentos totales y, si se agotan, la solicitud MUST terminar en `500`
  genérico sin orden confirmada.
- **FR-011**: El identificador asignado MUST devolverse como parte de la confirmación de creación.
- **FR-012**: Toda orden nueva MUST comenzar en estado `Pending`.
- **FR-013**: La confirmación de creación MUST permitir conocer el identificador asignado y el estado inicial de la orden.
- **FR-014**: Una orden confirmada MUST quedar disponible para consultas posteriores y sobrevivir
  reinicios del proceso y del host mientras se conserve el almacenamiento SQLite persistente.
  Recrear el entorno o eliminar, reemplazar o perder ese almacenamiento queda fuera de la garantía.
- **FR-015**: El sistema MUST permitir que cualquier solicitante consulte una orden utilizando el identificador exacto devuelto al crearla, sin exigir otro dato para autorizar la consulta.
- **FR-016**: Una consulta exitosa MUST devolver el identificador de la orden, el identificador del cliente, cada identificador de producto con su cantidad solicitada y el estado de la orden.
- **FR-017**: La orden consultada MUST conservar sin pérdida ni sustitución los identificadores de producto y las cantidades aceptadas durante su creación.
- **FR-018**: Si `GET /orders/{orderId}` no encuentra coincidencia binaria para el identificador
  utilizable que llegó al endpoint, el sistema MUST responder `404`, informar que la orden no fue
  encontrada y MUST NOT devolver datos pertenecientes a otra orden.
- **FR-019**: `GET /orders` MUST responder `400` y nunca enumerar órdenes. Un `orderId` vacío o sólo
  whitespace que llegue a `GET /orders/{orderId}` también MUST responder `400` y distinguirse de
  `404`.
- **FR-020**: El sistema MUST garantizar que dos órdenes distintas nunca compartan el mismo identificador, incluso cuando sus solicitudes de creación sean simultáneas o contengan los mismos datos.
- **FR-021**: La feature MUST NOT establecer un máximo de negocio para la cantidad de productos
  distintos por orden ni para una cantidad positiva representable por producto. `POST /orders`
  MUST aplicar un límite de transporte de 1 MiB (1.048.576 bytes) al cuerpo HTTP; excederlo produce
  `413`, sin truncar, redondear ni crear total o parcialmente la orden.

### Security and Privacy Considerations *(mandatory)*

- **SR-001**: Todo identificador de cliente, identificador de producto, cantidad e identificador de consulta recibido desde fuera del límite de confianza MUST validarse antes de crear una orden o utilizarse para localizarla.
- **SR-002**: Debido a que la autenticación y autorización están fuera del alcance, conocer el
  identificador exacto MUST ser suficiente para consultar la orden. La PoC MUST ejecutarse sólo en
  loopback local o una red de desarrollo aislada, sin exposición pública a Internet, con datos
  exclusivamente sintéticos o clasificados como no sensibles y sin credenciales reales. TLS no es
  obligatorio en loopback; cualquier exposición fuera de loopback o de la red controlada queda
  fuera del alcance y requiere autenticación, autorización y revisión de seguridad.
- **SR-003**: El identificador de orden asignado MUST NOT incorporar de forma legible el identificador del cliente, los identificadores de producto ni el contenido de la orden.
- **SR-004**: Una consulta exitosa MUST exponer únicamente los datos de la orden solicitada necesarios para satisfacer FR-016; no debe incluir información de otras órdenes o clientes.
- **SR-005**: Los mensajes de validación y de orden no encontrada MUST ser suficientes para que el cliente comprenda el resultado, pero MUST NOT revelar datos de otras órdenes, secretos, credenciales ni detalles internos del sistema.
- **SR-006**: La feature MUST NOT solicitar ni conservar credenciales, tokens, información de pago, datos de envío ni otros datos personales que no sean necesarios para identificar al cliente en esta PoC.
- **SR-007**: Los registros operativos MUST ser JSON estructurado y limitarse al nombre lógico de
  operación, código HTTP, resultado lógico, duración en milisegundos, `traceId` y una categoría
  operacional segura. MUST NOT registrar request/response body, `customerId`, `productId`,
  `orderId`, ruta HTTP cruda con identificadores, query string cruda, headers sensibles,
  connection string, ruta física de SQLite, SQL ni parámetros SQL. Las respuestas MUST NOT exponer
  stack traces.

### Key Entities *(include if feature involves data)*

- **Orden**: Representa una solicitud registrada de productos para un cliente. Sus atributos relevantes son el identificador único de orden, el identificador del cliente, uno o más elementos de orden y el estado, que inicialmente es `Pending`.
- **Elemento de orden**: Representa un producto solicitado dentro de una orden. Contiene un identificador de producto y una cantidad entera mayor que cero. Un producto aparece como máximo una vez por orden.
- **Cliente**: Actor identificado en la solicitud de creación de una orden. Para esta feature se representa únicamente mediante un identificador opaco; la gestión del cliente y su autenticación están fuera de alcance. La consulta posterior puede realizarla cualquier solicitante que conozca el identificador exacto de la orden.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: El 100% de las solicitudes válidas del conjunto de aceptación crea exactamente una orden con identificador único y estado inicial `Pending`.
- **SC-002**: El 100% de las solicitudes inválidas del conjunto de aceptación crea cero órdenes.
  Para cada documento JSON correctamente deserializable comunica todas las reglas semánticas
  incumplidas detectables; para fallos de parsing, tipo o rango comunica de forma estable que el
  body no pudo interpretarse, sin exigir validaciones semánticas que ese fallo impide.
- **SC-003**: El 100% de las consultas de órdenes existentes del conjunto de aceptación devuelve la orden correcta con todos los identificadores de producto y cantidades aceptadas, sin datos de otra orden.
- **SC-004**: El 100% de las consultas con identificadores inexistentes del conjunto de aceptación informa claramente "orden no encontrada", mientras que el 100% de las consultas sin identificador utilizable se informa como solicitud inválida.
- **SC-005**: Al menos el 95% de los participantes de una prueba de aceptación puede crear una orden válida y consultarla por su identificador en menos de 2 minutos, sin asistencia.
- **SC-006**: Bajo el protocolo reproducible de carga definido en `quickstart.md`, con 25 usuarios
  virtuales concurrentes y mezcla explícita de creación y consulta, al menos el 95% de las
  operaciones exitosas medidas debe completar estrictamente en menos de 2 segundos end-to-end,
  desde el envío HTTP hasta leer la respuesta completa. Los `503` se contabilizan como operaciones
  fallidas, no como cumplimiento de latencia, y no puede haber errores inesperados.
- **SC-007**: El 100% de requests, archivos SQLite y evidencias de aceptación de la PoC usa datos
  sintéticos generados para la prueba o datos con clasificación no sensible registrada antes de
  usarlos; nunca credenciales ni datos reales no clasificados.

## Assumptions

- Una cantidad representa unidades enteras; no se admiten cantidades fraccionarias.
- Una orden permanece consultable tras reinicios de proceso y host mientras se conserve el archivo
  SQLite persistente y sus archivos auxiliares necesarios para recuperación. La recreación del
  entorno, la pérdida o eliminación del almacenamiento, el archivado y una política de retención de
  producción están fuera del alcance.
- Como no hay autenticación ni autorización, cualquier solicitante que conozca el identificador
  exacto puede consultar la orden. El responsable de ejecutar la PoC debe enlazarla a loopback o
  aislarla en una red de desarrollo y asegurar que sólo se usen datos sintéticos/no sensibles.
- La modificación, cancelación y transición de estado no forman parte de esta feature; por ello, las órdenes permanecen en `Pending` dentro de su alcance.
- No se requiere disponibilidad de pagos, inventario, descuentos, envío ni sistemas externos para crear o consultar órdenes.
- La interfaz de esta feature es HTTP JSON con las tres operaciones aprobadas. No se asume
  frontend, protocolo adicional ni exposición pública.
