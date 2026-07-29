---
name: speckit-dotnet-sdd-guard-verify
description: Run the deterministic .NET SDD Guard
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: dotnet-sdd-guard:commands/speckit.dotnet-sdd-guard.verify.md
---

Execute the following command from the project root and wait for it to finish:

```powershell
& ".specify/extensions/dotnet-sdd-guard/scripts/Invoke-SddGuard.ps1" -ProjectRoot (Get-Location).Path
exit $LASTEXITCODE
```

Display the script output and its exit code exactly as produced. Do not reinterpret,
override, fix, or retry a failing result. Exit `0` means PASS, `1` means validation
failure, and `2` means Guard configuration or execution error.