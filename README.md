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
- **Deep Process Termination:** Forcefully stops core licensing services (`AdskLicensingService`, `FlexNet`, `AdAppMgrSvc`) and processes preventing uninstallation.
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

Este repositorio contiene un script de PowerShell avanzado diseñado para limpiar profundamente cualquier instalación de Autodesk (AutoCAD, Inventor, Maya, etc.) y solucionar el infame bucle infinito de "Reinicie antes de empezar la instalación" que bloquea nuevas instalaciones.

### 🚀 Características
- **Auto-elevación de privilegios:** El script verifica y solicita permisos de Administrador automáticamente.
- **Limpieza profunda de procesos:** Detiene forzosamente los servicios críticos de licencias (`AdskLicensingService`, `FlexNet`, `AdAppMgrSvc`) y procesos en segundo plano.
- **Eliminación Forzada Agresiva:** Borra archivos bloqueados en `C:\Autodesk`, `%TEMP%`, y `AppData` solucionando errores de archivos residuales.
- **Reparación del Registro (Loop de Reinicio):** Elimina automáticamente las claves del registro `PendingFileRenameOperations` y `RebootRequired` causantes de que el instalador pida reiniciar la PC infinitamente.

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
