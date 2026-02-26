# ☢️ Autodesk-Nuke | A Clean Uninstall Tool

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg?logo=powershell)
![Windows](https://img.shields.io/badge/OS-Windows_10%20%7C%2011-blue.svg?logo=windows)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![Status](https://img.shields.io/badge/Status-Stable-brightgreen.svg)

> **A powerful, automated PowerShell script to completely remove Autodesk remnants, fix the "reboot loop" (PendingFileRenameOperations), and achieve a clean installation. By SSM-Dealis.**

[English Version](#english) | [Versión en Español](#español)

---

<a name="english"></a>
## 🇬🇧 English

This repository contains an advanced PowerShell script designed to deeply clean any Autodesk installation (AutoCAD, Inventor, Maya, etc.) and fix the infamous "Please restart your computer" infinite loop error that prevents new installations.

### 🚀 Features
- **Auto-Privilege Elevation:** Automatically checks and requests Administrator rights.
- **Deep Process Termination:** Forcefully stops core licensing services (`AdskLicensingService`, `GenuineService`, `AdAppMgrSvc`) and processes preventing uninstallation.
- **Surgical Uninstallation:** Directly executes hidden backend uninstallers for tools like Autodesk Access (ODIS) and Identity Manager.
- **Ghost Entry Removal [v2.0]:** Scans and deletes orphaned "Add/Remove Programs" registry entries left behind by broken uninstallers.
- **Aggressive Forcible Deletion:** Clears locked leftover files from `C:\Autodesk`, `%TEMP%`, and `AppData` to solve locked-file errors.
- **Registry Repair (Reboot Loop Fix):** Specifically targets and deletes `PendingFileRenameOperations` and `RebootRequired` registry keys that trigger the infinite restart prompt during setup.

### 🛠️ Usage Instructions

1. Download the `Autodesk-Nuke.ps1` script.
2. Right-click the file and select **"Run with PowerShell"**.
3. Accept the Administrator privileges prompt (UAC).
4. Follow the color-coded console output as it performs the cleanup.
5. **Important:** Once finished successfully, **RESTART YOUR PC** before attempting to install any Autodesk product again.

### ⚠️ Disclaimer
This script modifies the Windows Registry and forcefully deletes system folders associated with Autodesk. Use it at your own risk. Creating a system restore point prior to execution is recommended.

---

<a name="español"></a>
## 🇪🇸 Español

Este repositorio contiene un script de PowerShell avanzado diseñado### 🌟 Características Principales (Features)

*   **💥 Aniquilación Total:** Cierra procesos críticos (`AdSSO`, `AutodeskAccess`) y detiene servicios a la fuerza, incluso "asesinando" procesos anfitriones si los servicios se resisten al cierre de Windows.
*   **🧠 Inteligencia ODIS:** Antes de usar fuerza bruta, busca y ejecuta el desinstalador subyacente oficial de Autodesk para productos modernos (2024+) `AdksUninstallHelper.exe` de forma silenciosa.
*   **💽 Soporte para Discos Secundarios:** Escanea dinámicamente el Registro de Windows para descubrir dónde está instalado Autodesk. ¡No importa si lo instalaste en la unidad `D:\` o `E:\`, el Nuke lo encontrará!
*   **🛠️ Modo "Troubleshooter":** Replica el comportamiento del *Microsoft Program Install and Uninstall Troubleshooter* purgando la base de datos oculta del instalador y eliminando físicamente los archivos `.msi` cacheados en `C:\Windows\Installer` que estén bloqueando nuevas instalaciones.
*   **🌀 Rompe el "Bucle de Reinicio":** Elimina la infame subclave `PendingFileRenameOperations`, causante directa de que Windows te pida reiniciar infinitamente al intentar instalar Autodesk.
*   **🧹 Limpieza Estética:** Elimina entradas huérfanas en el viejo Panel de Control (`C:\Windows\System32\*.cpl`) y borra la carpeta global de accesos directos del **Menú de Inicio**.

### 🛠️ Instrucciones de Uso

1. Descarga el archivo `Autodesk-Nuke.ps1`.
2. Haz clic derecho sobre el archivo y selecciona **"Ejecutar con PowerShell"**.
3. Acepta los permisos de Administrador si Windows te lo solicita (UAC).
4. Sigue las instrucciones generadas en la consola (con colores) que detallan cada paso de la limpieza.
5. **¡Importante!** Una vez que el script termine con éxito, **REINICIA TU COMPUTADORA** antes de intentar instalar cualquier producto de Autodesk de nuevo.

### ⚠️ Advertencia
Este script modifica el Registro de Windows y elimina de forma forzada carpetas de sistema asociadas a Autodesk. Úsalo bajo tu propio riesgo. Se recomienda encarecidamente crear un punto de restauración antes de ejecutarlo si no estás seguro de lo que haces.

---

## 📄 License and Authorship (Licencia y Autoría)
Created and Maintained by **SSM-Dealis**.
Distributed under the **MIT License** - Feel free to use, modify, and distribute this script. / Siéntete libre de usar, modificar y distribuir este script.
