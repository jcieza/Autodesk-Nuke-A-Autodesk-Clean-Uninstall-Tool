# Autodesk-Nuke | A Clean Uninstall Tool

> **A powerful, automated PowerShell script to completely remove Autodesk remnants, fix the "reboot loop" (PendingFileRenameOperations), and achieve a clean installation. Soluciona el error de reinicio infinito y limpia a fondo AutoCAD/Inventor. By SSM-Dealis.**

Este repositorio contiene un script de PowerShell avanzado diseñado para limpiar profundamente cualquier instalación de Autodesk (AutoCAD, Inventor, etc.) y solucionar el infame bucle de "Reinicie antes de empezar la instalación" o "Please restart your computer".

## 🚀 Características
- **Auto-elevación de privilegios:** El script verifica y solicita permisos de Administrador automáticamente.
- **Limpieza profunda de procesos:** Detiene servicios de licencias `AdskLicensingService`, `FlexNet`, `AdAppMgrSvc` y procesos asociados que previenen la desinstalación.
- **Eliminación Forzada:** Borra archivos remanentes en `C:\Autodesk`, `%TEMP%`, y `AppData` solucionando errores de archivos bloqueados.
- **Reparación del Registro (Loop de Reinicio):** Elimina automáticamente las claves `PendingFileRenameOperations` y `RebootRequired` que causan que el instalador pida reiniciar la PC infinitamente.

## 🛠️ Cómo usarlo

1. Descarga el archivo `limpieza_autodesk.ps1`.
2. Haz clic derecho sobre el archivo y selecciona **"Ejecutar con PowerShell"**.
3. Si el sistema te lo pide, acepta los permisos de Administrador (UAC).
4. El script mostrará en consola (con colores) cada paso de la limpieza.
5. **¡Importante!** Una vez que el script termine de ejecutarse con éxito, **REINICIA TU PC** antes de intentar instalar cualquier producto de Autodesk de nuevo.

## ⚠️ Advertencia
Este script modifica el Registro de Windows y elimina carpetas de sistema asociadas a Autodesk. Úsalo bajo tu propio riesgo. Se recomienda crear un punto de restauración antes de ejecutarlo si no estás seguro.

## 📄 Licencia y Autoría
Creado y mantenido por **SSM-Dealis**.
Distribuido bajo la **MIT License** - Siéntete libre de usar, modificar y distribuir este script.
