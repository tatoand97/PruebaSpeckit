# .NET SDD Guard Result

**Result:** PASS

| Check | Category | Severity | Status | Message | Evidence |
|---|---|---|---|---|---|
| SDK001 | sdk | HARD | PASS | .NET 10 target is configured. | SDK/framework declarations are consistent. |
| ARCH001 | architecture | HARD | PASS | Project reference direction is valid. | No prohibited ProjectReference edges found. |
| PERSIST001 | persistence | HARD | PASS | Persistence ownership is valid. | No prohibited persistence API/package found outside Infrastructure. |
| MIG001 | persistence | HARD | PASS | No EF Core migrations or substitute initialization detected. | Prohibited markers were absent. |
| WOLV001 | messaging | HARD | PASS | Wolverine dependency is present. | WolverineFx marker found. |
| WOLV002 | messaging | HARD | PASS | Wolverine is configured as mediator-only. | MediatorOnly marker found. |
| WOLV003 | messaging | HARD | PASS | No distributed Wolverine transport package was detected. | No explicit prohibited transport marker found. |
| AZURE001 | configuration | HARD | PASS | Azure App Configuration preparation is present. | Required package/API markers and external endpoint handling were checked without contacting Azure. |
| HTTP001 | http | HARD | PASS | Problem Details infrastructure is present. | HTTP error-handling markers were checked. |
| HTTP002 | http | HARD | PASS | Minimal API patterns are present. | Minimal API mapping marker found and no controller architecture marker found. |
| PERSIST002 | persistence | ADVISORY | PASS | Repository abstraction marker is present. | A conventional repository marker was found. |
| EXC001 | exceptions | ADVISORY | PASS | No exception ownership advisory was detected. | Module exception and Presentation markers were compared. |
| RESTORE001 | build | HARD | PASS | dotnet restore succeeded. | Exit code was evaluated; command output is not exported. |
| BUILD001 | build | HARD | PASS | Release build succeeded with warnings treated as errors. | Build used -warnaserror; output is not exported. |
| TEST001 | tests | HARD | PASS | Unit test execution succeeded. | executed=22; passed=22; failed=0; skipped=0 |
| COV001 | coverage | HARD | PASS | Business line coverage meets the 80% threshold. | lineCoveragePercent=93.75 |
| OPENAPI001 | openapi | HARD | PASS | Version-pinned Redocly lint succeeded. | 1 contract(s) checked; runtime equivalence was not claimed. |
