# Contributing to Autodesk-Nuke

First off, thank you for considering contributing to **Autodesk-Nuke**! It's people like you that make the open-source community such a powerful and helpful place.

The goal of this project is to provide the most reliable, safe, and effective way to completely clean Autodesk installations and fix reboot loops. Every contribution that helps achieve this is highly appreciated.

---

## 🚀 How to Contribute

### 1. Report a Bug or Request a Feature
If you find a bug (e.g., the script missed a specific registry key for a new AutoCAD version) or have an idea for a massive improvement:
* Open an **Issue** on GitHub.
* Clearly describe the problem or suggestion.
* Include screenshots or error messages if applicable.

### 2. Submit a Pull Request (PR)
If you want to fix a bug or add a feature yourself:
1. **Fork** the repository to your own GitHub account.
2. Create a new branch: `git checkout -b feature/your-feature-name`
3. Make your changes to `Autodesk-Nuke.ps1` or the documentation.
4. **Test** your changes locally to ensure they don't break existing functionality.
5. Commit your changes: `git commit -m "Add some feature"`
6. Push to the branch: `git push origin feature/your-feature-name`
7. Open a **Pull Request** against our `main` branch.

---

## 🧑‍💻 Code Guidelines

When submitting code changes to the PowerShell script, please keep the following in mind:
* **Safety First:** We are dealing with the Windows Registry and system folders. Always use `-ErrorAction SilentlyContinue` where appropriate so the script doesn't crash if a file is heavily locked, unless a hard fail is absolutely necessary.
* **No dependas de la GUI:** Si Autodesk introduce una nueva herramienta, no escribas scripts que simulen clics. Encuentra la bandera silenciosa (`-q`, `/qn`, `--mode unattended`) de su desinstalador.
* **Variables de Entorno y Rutas Dinámicas:** Usa `$env:ProgramData` o `$env:APPDATA` en lugar de `C:\ProgramData`. Aún mejor, **NUNCA** "quemes" (hardcodees) rutas estáticas si puedes. Consulta el Registro de Windows (`InstallLocation`) para descubrir las rutas de instalación reales del usuario caso por caso (soporte para discos D:, E:, etc.).
* **Si no se borra, fuérzalo:** Si un servicio o proceso no se detiene con comandos estándar, busca el PID anfitrión vía WMI y destrúyelo, o usa la propiedad `-Force`. Autodesk es notoriamente persistente.
* **Keep it Clean:** Follow the existing color-coded `Write-Host` structure:
  * `Cyan` for Main Steps
  * `Yellow` for active tasks or warnings
  * `Green` for success messages
  * `DarkGray` for granular files being deleted
* **Comments:** Although the README is bilingual, it is preferred to keep code comments in Spanish (as it currently is) or bilingual if you are adding new heavy logic.

---

## 📜 License By Contributing
By contributing to Autodesk-Nuke, you agree that your contributions will be licensed under its MIT License.

*Happy Coding!* - **SSM-Dealis**
