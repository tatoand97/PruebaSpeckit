# Corporate MCP Setup (Windows, user scope)

Prerequisites:
- Python >= 3.10
- pip
- VS Code
- GitHub Copilot

Install (user scope, pinned):

```powershell
python -m pip install --user -r tools/mcp/requirements.txt
```

Verify:

```powershell
python -m pip show graphifyy
python -m graphify --version
python -c "import graphify.serve; print('Graphify MCP OK')"
```

Generate local graph (code-only, no LLM backend):

```powershell
python -m graphify extract . --code-only --force
```

Open VS Code and run `MCP: List Servers`.
Expected:
- context7: Running
- graphify: Running

Notes:
- No administrator rights required.
- No uv tooling required.
- No PowerShell installer required.
- Context7 is remote HTTP MCP for public docs only.
- Graphify graph generation is local and code-only by default in this setup.

Updating Graphify version:
1. Security approves a new version.
2. Update the pin in `tools/mcp/requirements.txt`.
3. Reinstall explicitly with the pinned version.
4. Regenerate graph.
5. Re-validate MCP servers.
