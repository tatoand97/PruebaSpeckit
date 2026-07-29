# Changelog

Todos los cambios notables de este preset se documentan en este archivo.

## [1.0.1] - 2026-07-29

### Changed

- Azure App Configuration ahora es una integración de código obligatoria, con activación remota
  condicionada por configuración externa y sin provisioning de recursos Azure.
- Se formalizó el ownership del manejo de excepciones: cada módulo traduce sus fallos conocidos y
  `Common.Presentation` conserva únicamente el fallback transversal inesperado.
- Redocly CLI `2.41.1` se convirtió en el validator OpenAPI estándar y reproducible.
- EF Core Migrations y su tooling fueron eliminados del estándar; el versionado y despliegue del
  esquema físico quedan fuera del alcance de la V1.

Esta versión es PATCH porque corrige y aclara el comportamiento esperado de la V1 sin cambiar su
arquitectura fundamental ni introducir una metodología nueva.

## [1.0.0] - 2026-07-29

### Added

- Constitución base para monolitos modulares greenfield en .NET 10.
- Templates de especificación, planificación y tareas adaptados al estándar reutilizable del
  preset.
- Addenda para los commands `speckit.constitution`, `speckit.plan`, `speckit.tasks`,
  `speckit.implement` y `speckit.converge`.
- Documentación de arquitectura, Definition of Done local y estrategia de unit testing.
- Propuesta separada de repository instructions para GitHub Copilot.
