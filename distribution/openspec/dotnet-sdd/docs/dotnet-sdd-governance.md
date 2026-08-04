# Repository .NET SDD Governance

This document is the canonical architecture and quality policy for this repository. It preserves the mandatory controls from the former SDD constitution while expressing the active workflow in native OpenSpec terms.

## Metadata

- **Policy name**: Repository .NET SDD Governance
- **Version**: 1.0.1
- **Ratified**: 2026-07-29
- **Last amended**: 2026-07-30
- **Historical source**: `docs/sdd-history/spec-kit/constitution.md`

The ratification date is the author date of commit `569edc9`, where the constitution first appeared. The last-amended date is the author date of commit `c3b3349`, the final content-bearing commit before its later removal.

## 1. Specification First

Every production change MUST begin with sufficient OpenSpec artifacts before implementation. `proposal.md` establishes the problem and scope; capability specs define observable behavior; `research.md` resolves material uncertainty; `design.md` defines the technical approach; `review.md` gates task creation; and `tasks.md` defines executable work. Discoveries that change requirements, constraints, or decisions MUST update the corresponding artifact. Code MUST NOT silently redefine intent to match an implementation.

The active workflow is:

```text
proposal
├── specs
└── research
     └── design
specs + design
     └── review
specs + design + review
     └── tasks
tasks
     └── apply
```

Exploration, clarification, synchronization, verification, and archival are used when appropriate. No workflow marker substitutes for a resolved business or technical decision. Multi-agent execution is not introduced by this policy; parallelizable work does not itself authorize delegation.

## 2. Modular DDD and Clean Architecture

The solution MUST be a modular monolith. Modules MUST represent real domain capabilities or boundaries identified through DDD and MUST NOT be invented for technical convenience. Each module MUST contain `Domain`, `Application`, `Infrastructure`, and `Presentation` projects, with unit tests under `Tests`.

Authorized dependency directions are:

- `Domain` MAY depend on `Common.Domain` and MUST NOT depend on Application, Infrastructure, Presentation, or Api.
- `Application` MUST depend on Domain and MUST NOT know concrete infrastructure or Presentation.
- `Infrastructure` MUST depend on Application and `Common.Infrastructure`, and MAY depend on Domain when necessary.
- `Module.Presentation` MAY depend on Infrastructure, Application, and Domain from the same module when composing the module or translating its public failures, plus `Common.Presentation`; it MUST NOT directly access persistence or reference another module's layers.
- `Common.Presentation` MUST NOT reference any `Modules.<Module>.*` project.
- `<ProjectName>.Server` MUST be the composition root and reference `Common.Presentation` plus each `Module.Presentation` project.

Solution, assembly, and namespace names MUST come from the application. The workflow MUST NOT inject an organization prefix.

## 3. Simplicity and Justified Abstractions

Within the four mandatory layers, each feature MUST use the simplest design that satisfies its requirements. Every additional abstraction, interface, factory, service, wrapper, base class, mapper, DTO, domain event, or value object MUST answer a concrete need and be justified when that need is not self-evident. Generic repositories, ceremonial CQRS, and empty types created merely to resemble Clean Architecture are prohibited.

## 4. .NET Application Baseline

- The platform MUST be .NET 10 with its corresponding C# version, nullable reference types, and implicit usings enabled.
- HTTP APIs MUST use ASP.NET Core Minimal APIs.
- Wolverine MUST be the only mediator between Presentation and Application handlers and MUST run in `DurabilityMode.MediatorOnly`.
- The Repository Pattern is mandatory for Application access to persistence.
- Only Infrastructure MAY use EF Core, SQL Server, MongoDB, `DbContext`, or concrete database drivers.
- When persistence changes, `design.md` MUST justify EF Core with SQL Server or EF Core with MongoDB; it MUST NOT select an arbitrary engine or both engines without need.
- FluentValidation MUST validate input and use-case rules where applicable.

This policy does not use EF Core Migrations or its tooling. Implementations MUST NOT add migration directories, snapshots, `dotnet-ef` commands, or `EnsureCreated()` as an alternative schema-management policy. This prohibition does not remove legitimate `DbContext`, entity configuration, or repository code. Physical schema creation, upgrade, versioning, and deployment remain out of scope.

## 5. HTTP Contracts and Standardized Errors

Every endpoint MUST remain thin, delegate through Wolverine, document its responses, and appear in OpenAPI. Every HTTP feature MUST keep an OpenAPI contract linked from its design or durable history and MUST close with consistency among requirements, design, contract, and implementation. Contract-first is permitted but not mandated.

All OpenAPI contracts MUST pass Redocly CLI `2.41.1` with a pinned invocation:

```powershell
npx --yes @redocly/cli@2.41.1 lint <openapi-file>
```

`@latest`, an unpinned global installation, or runtime tests as a substitute for static OpenAPI validation are prohibited. Static linting does not prove implementation equivalence; review and verification MUST check that separately.

Exception handling MUST use `IExceptionHandler`, `AddProblemDetails()`, and Problem Details. `Common.Presentation` MUST handle only unexpected or cross-cutting fallback failures and return 500 without knowing module types. Each `Module.Presentation` MUST translate known failures from its own domain and use cases. Unless functional requirements justify otherwise, mappings are validation 400, unauthenticated 401, unauthorized 403, not found 404, and business conflict 409.

Responses MUST NOT expose stack traces, connection strings, SQL, secrets, tokens, or sensitive internal details. Validation responses MAY include per-field `errors`; responses MUST include correlation or trace information where appropriate.

## 6. Meaningful Unit Testing and Coverage

This stage MUST use xUnit and Coverlet unit tests. Changed business logic, prioritizing Domain and Application, MUST achieve at least 80% line coverage. Tests MUST verify meaningful behavior and MUST NOT be fabricated only to raise a percentage.

DTOs without logic, `Program.cs`, dependency-injection setup, generated code, assembly markers, trivial bootstrap, and OpenAPI files do not require artificial coverage. When business logic legitimately resides elsewhere, it MUST be tested there. TDD is not mandatory; the design determines implementation and test ordering.

## 7. Observability, Configuration, and Safety

Designs MUST consider and apply Serilog, OpenTelemetry, and HealthChecks when relevant to the change and existing standard. Every ASP.NET Core application MUST integrate Azure App Configuration in code using `Microsoft.Azure.AppConfiguration.AspNetCore`, `Azure.Identity`, `AddAzureAppConfiguration(...)`, an externally supplied endpoint, and `DefaultAzureCredential` as the preferred authentication method.

The remote provider MUST activate only when its endpoint is configured, so local restore, build, and unit tests do not depend on Azure. Lack of connectivity or a provisioned Azure resource does not make the code integration optional. Service registration and middleware for refresh MUST be added only when the design adopts refresh behavior; complex refresh is not mandatory.

Hardcoded credentials and connection strings are prohibited. Logs and traces MUST NOT contain secrets, tokens, contact data, or other sensitive information without an explicit need and protection. This workflow does not provision collectors, dashboards, external infrastructure, Azure resources, credentials, secrets, or deployment pipelines.

## 8. Reproducibility and Deterministic Verification

Restore, warning-free Release build, unit tests, coverage, OpenAPI linting, and the deterministic guard MUST be reproducible through documented commands. The Release build MUST finish with zero errors and zero .NET warnings. A task MUST NOT be marked complete without its required evidence.

The explicit repository gate is:

```powershell
./scripts/Invoke-OpenSpecSddGuard.ps1
```

OpenSpec has no automatic equivalent to the former `after_implement` hook. Agents and CI MUST invoke the gate explicitly; documentation MUST NOT imply that OpenSpec runs it automatically.

## 9. Definition of Done

A change is complete only when all applicable conditions hold:

- all tasks are complete with observable evidence;
- `openspec validate --all --strict` passes;
- restore and Release build pass with zero errors and zero warnings;
- all unit tests pass and changed business logic meets at least 80% line coverage with xUnit and Coverlet;
- every affected HTTP contract is consistent and Redocly CLI `2.41.1` exits zero;
- DDD boundaries, four-layer dependencies, Repository Pattern, Wolverine mediator-only mode, Minimal APIs, FluentValidation, and Problem Details remain valid;
- applicable Serilog, OpenTelemetry, and HealthChecks obligations are covered;
- Azure App Configuration remains integrated without hardcoded secrets;
- known failures remain in the owning module's Presentation layer and the unexpected fallback remains in `Common.Presentation`;
- deterministic guard checks pass; and
- review and verification report no unresolved gaps.

Sonar, Veracode, SAST, DAST, performance testing, integration testing, deployment, Azure provisioning, and physical schema deployment remain later-SDLC activities unless a specific approved change brings one into scope. Their absence MUST NOT weaken requirements for security, quality, or performance.

## 10. Governance

This policy prevails over lower-level instructions that conflict with it. Project-specific rules MAY strengthen it but MUST NOT weaken or contradict it. Every exception MUST be tied to a concrete requirement, risk, or constraint, documented in `design.md`, and approved through the applicable governance process. An undocumented deviation blocks the Definition of Done.

Policy changes MUST state motivation and impact, update the version using Semantic Versioning, and propagate effects to the schema, templates, configuration, guard, and documentation. A change incompatible with the fundamental architecture or methodology requires MAJOR; a compatible new capability requires MINOR; a correction or clarification of expected behavior requires PATCH.
