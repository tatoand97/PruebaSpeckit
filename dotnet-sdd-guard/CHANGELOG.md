# Changelog

## 1.0.1

- Corrected ARCH001 dependency-direction rules to align with module Clean Architecture.
- Restricted MIG001 scanning to implementation file types and excluded documentation/spec trees.
- Reworked external command execution to preserve complex arguments and process exit codes.
- Isolated raw test artifacts per run to avoid historical TRX double counting in TEST001.
- Added deterministic EXC001 ordering validation for specific vs fallback IExceptionHandler registrations.
- Expanded regression coverage in `tests/Invoke-GuardTests.ps1` for PoC-reported defects.

## 1.0.0

- Added deterministic guard, sanitized JSON/Markdown reports, mandatory
  `after_implement` hook, and synthetic fixture test suite.
