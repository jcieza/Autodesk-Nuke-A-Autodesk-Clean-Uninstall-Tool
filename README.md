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
*   **👥 Soporte Multi-Usuario (Intune/SCCM):** Elimina la basura de Autodesk de *todos* los perfiles de usuario de la máquina (Appdata) e incluso monta silenciosamente sus colmenas de registro (`NTUSER.DAT`) para purgarlos offline. Disponible vía prompt interactivo o flag silencioso.
*   **💽 Soporte para Discos Secundarios:** Escanea dinámicamente el Registro de Windows para descubrir dónde está instalado Autodesk. ¡No importa si lo instalaste en la unidad `D:\` o `E:\`, el Nuke lo encontrará!
*   **🛠️ Modo "Troubleshooter":** Replica el comportamiento del *Microsoft Program Install and Uninstall Troubleshooter* purgando la base de datos oculta del instalador y eliminando físicamente los archivos `.msi` cacheados en `C:\Windows\Installer` que estén bloqueando nuevas instalaciones.
*   **🌀 Rompe el "Bucle de Reinicio":** Elimina la infame subclave `PendingFileRenameOperations`, causante directa de que Windows te pida reiniciar infinitamente al intentar instalar Autodesk.
*   **🧹 Limpieza Estética:** Elimina entradas huérfanas en el viejo Panel de Control (`C:\Windows\System32\*.cpl`) y borra la carpeta global de accesos directos del **Menú de Inicio**.

### 🛠️ Instrucciones de Uso

**⚠️ ADVERTENCIA:** Guarda tu trabajo y cierra cualquier producto de Autodesk o archivos CAD antes de proceder.

**Modo Interactivo (Recomendado):**
1.  Haz clic derecho en `Autodesk-Nuke.ps1` y selecciona **Ejecutar con PowerShell**.
2.  (Opcional) Si no lo ejecutas como Administrador, el script pedirá permisos UAC y se reiniciará automáticamente.
3.  El script te preguntará si deseas limpiar tu usuario actual o **TODOS** los usuarios. Responde `Y` o `N`.

**Modo Silencioso / Enterprise (Intune, PDQ, SCCM):**
Si quieres desplegar el script a nivel corporativo sin que haya prompts estancando la ejecución:
```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\Autodesk-Nuke.ps1" -AllUsers
```
5. **¡Importante!** Una vez que el script termine con éxito, **REINICIA TU COMPUTADORA** antes de intentar instalar cualquier producto de Autodesk de nuevo.

---

### 🛡️ Casos de Uso Comprobados (¿Para qué sirve este script?)

Esta herramienta no es un simple desinstalador; es un "sanador de entornos". Aquí detallamos los escenarios reales donde `Autodesk-Nuke.ps1` brilla y soluciona problemas que el desinstalador tradicional (o incluso herramientas de terceros como Revo Uninstaller) no pueden arreglar:

1.  **El Bucle Infinito de Instalación ("Reinicie antes de empezar..."):** El clásico error donde el instalador de Autodesk se niega a iniciar exigiendo un reinicio. El script rompe este bucle aniquilando la clave de registro `PendingFileRenameOperations`.
2.  **Corrupción por Plugins de Terceros (DLL Hell):** Si instalaste un plugin (ej. PyRx, loaders externos) que corrompió las variables de entorno o la carpeta `ApplicationPlugins` impidiendo que AutoCAD cargue, el script limpia estas carpetas huérfanas permitiendo una reinstalación ("Clean Slate") exitosa.
3.  **Servicios "Stop-Pending" (Error 1603):** Desinstalaciones fallidas porque el nuevo `Autodesk Access Service Host` se queda congelado en estado "Not Stoppable". El script rastrea el proceso anfitrión WMI a nivel de núcleo y lo asesina para destrabar el sistema.
4.  **"Fantasmas" en Agregar o Quitar Programas:** Cuando borras los archivos a la fuerza pero la aplicación sigue apareciendo en el Panel de Control y al intentar desinstalarla dice "Windows no puede encontrar Installer.exe". El escaneo profundo del registro (HKLM/Uninstall) borra las firmas huérfanas independientemente de las docenas de GUIDs aleatorios que Autodesk utilice.
5.  **Entornos Multi-Usuario (SCCM / Intune):** Ideal como script de pre-requisito (Requirement Rule) antes de desplegar masivamente versiones 2025/2026. Con el flag `-AllUsers`, purga la basura (AppData y Registry) de todos los perfiles de la máquina, solucionando errores de AutoCAD que solo le ocurren al "Usuario 2" pero no al Administrador.
6.  **Desinstalaciones Oficiales Sucias:** Incluso si usas la herramienta oficial de Autodesk para desinstalar, esta suele dejar atrás `AdskIdentityManager`, la aplicación de escritorio (`Access`), y servicios SSO. Correr el Nuke *después* de la desinstalación oficial garantiza una limpieza real.

---

### 🔬 Cómo Funciona bajo el Capó (Technical Deep Dive)

Para los administradores de sistemas que necesitan saber exactamente qué se está alterando en sus máquinas, esta es la secuencia de aniquilación:

#### Fase 1: Asesinato de Interbloqueos (Procesos y Servicios)
El script comienza una caza despiadada de procesos en memoria (`AdSSO.exe`, `AutodeskAccess.exe`, `Node.exe`). Si los servicios vinculados (ej. `AdskLicensingService`) rechazan los comandos estándar de detención de Windows, el script ejecuta una consulta de Instrumental de Administración de Windows (WMI) para encontrar el PID (Identificador de Proceso) exacto del contenedor y lo termina forzosamente (`Stop-Process -Force` / `taskkill`).

#### Fase 2: Ejecución del Asistente ODIS (Soft-Kill)
Para productos de la era 2024+, el script busca silenciosamente en `C:\ProgramData\Autodesk\Uninstallers\` el ejecutable `AdksUninstallHelper.exe` y lo lanza con parámetros de interfaz invisible y permisos de sistema. Esto permite a Autodesk intentar limpiar sus propias licencias de red antes de aplicar fuerza bruta.

#### Fase 3: Purga de Archivos Físicos y Rutas Dinámicas
No dependemos solo de rutas codificadas como `C:\Program Files`. El Nuke consulta el Registro de Windows en tiempo real interrogando la propiedad `InstallLocation` de cada programa. Si detecta que AutoCAD se instaló en un disco secundario (ej. `D:\CAD\AutoCAD`), lo agrega a la lista de destrucción. Luego, borra implacablemente:
*   Carpetas principales y carpetas de compartición de red (`Public`).
*   Configuraciones de licencias profundas en `C:\ProgramData\FLEXnet\adsk*`.
*   Accesos directos huérfanos del Menú de Inicio global.
*   Con `-AllUsers`: Itera la carpeta `C:\Users\` y destruye `%AppData%\Autodesk` y `%LocalAppData%\Autodesk` de cada perfil descubierto.

#### Fase 4: Limpieza Quirúrgica del Registro (El Bucle Principal)
Se peinan los sub-árboles nativos de 64-bit y los nodos heredados `Wow6432Node` en `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\`. En lugar de buscar GUIDs específicos (que cambian constantemente), usamos heurística de PowerShell buscando nombres o editores (Publishers) que coincidan con la cadena "*Autodesk*". Esto borra las entradas "Fantasma" de Agregar/Quitar programas. También limpiamos configuraciones globales en `HKLM\SOFTWARE\Autodesk`.

#### Fase 5: El Modo "Troubleshooter" (Limpieza de Caché MSI)
Esta es la función más avanzada. Microsoft Installer mantiene una base de datos oculta (`C:\Windows\Installer`) donde guarda copias de rutinas `.msi` para autorreparaciones. Si esta base se corrompe, nada se puede instalar. El script:
1.  Borra las firmas de producto en `HKLM:\SOFTWARE\Classes\Installer\Products\`.
2.  Desencripta la ubicación del paquete local consultando la clave profunda `UserData\S-1-5-18\Products` y borra **físicamente** el viejo `.msi` bloqueado en el caché de Windows Installer.

#### Fase 6: Montaje de Colmenas Multi-Usuario (Hive Loading)
Si se invoca `-AllUsers`, el script no solo limpia el registro del usuario activo (`HKCU:\Software\Autodesk`). Encuentra los archivos bloqueados de base de datos de registro (`NTUSER.DAT`) de perfiles desconectados, los monta virtualmente en la memoria del sistema (`reg.exe load HKU`), purga las llaves de Autodesk de ese usuario dormido, descarga la memoria, y fuerza al recolector de basura de .NET a liberar el archivo para no causar perfiles temporales dañados. Finalmente, limpia rastros del registro, como las listas de archivos recientes en Paint o Wordpad que apunten a rutas de Autodesk.


### ⚠️ Advertencia
Este script modifica el Registro de Windows y elimina de forma forzada carpetas de sistema asociadas a Autodesk. Úsalo bajo tu propio riesgo. Se recomienda encarecidamente crear un punto de restauración antes de ejecutarlo si no estás seguro de lo que haces.

---

## 📄 License and Authorship (Licencia y Autoría)
Created and Maintained by **SSM-Dealis**.
Distributed under the **MIT License** - Feel free to use, modify, and distribute this script. / Siéntete libre de usar, modificar y distribuir este script.
