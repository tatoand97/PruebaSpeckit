# HU-001: Registrar solicitud de contacto

## Historia de usuario

Como visitante del sitio web,
quiero registrar una solicitud de contacto,
para que un asesor pueda comunicarse conmigo.

## Criterios de aceptación

1. El visitante debe proporcionar nombre, correo electrónico y mensaje.
2. El nombre es obligatorio y no puede superar los 100 caracteres.
3. El correo electrónico es obligatorio y debe tener un formato válido.
4. El mensaje es obligatorio y debe contener entre 10 y 1.000 caracteres.
5. Cuando la información sea válida, el sistema debe registrar la solicitud.
6. La respuesta debe incluir:
   - un identificador único;
   - la fecha y hora de creación;
   - el estado inicial `Pending`.
7. Cuando la información sea inválida, el sistema debe informar los campos con error.
8. Una solicitud inválida no debe almacenarse.

## Reglas de negocio

- Toda solicitud nueva inicia en estado `Pending`.
- El identificador es generado por el sistema.
- La fecha de creación es asignada por el sistema.

## Fuera de alcance

- Envío de correos electrónicos.
- Autenticación.
- Asignación automática de asesores.
- Integración con CRM.
- Consulta, actualización o eliminación de solicitudes.
- Despliegue e infraestructura.
