# ☢️ Autodesk-Nuke | Herramienta Completa de Limpieza y Desinstalación

![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg?logo=powershell)
![Windows](https://img.shields.io/badge/OS-Windows_10%20%7C%2011-blue.svg?logo=windows)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)
![Status](https://img.shields.io/badge/Status-Stable_v2.0.2-brightgreen.svg)
![Versions](https://img.shields.io/badge/Versions-2.0.2_to_6.0.0-blue.svg)
![Development](https://img.shields.io/badge/Development_Versions-Experimental-orange.svg)

> **Un potente script automatizado en PowerShell para eliminar por completo los restos de Autodesk, solucionar el "bucle de reinicio" (PendingFileRenameOperations) y lograr una instalación limpia.**

---

## 🛑 IMPORTANTE: Lee esto primero

**La versión `v2.0.2` (Latest Release) fue más que suficiente en mi caso personal para solucionar los problemas de instalación.** 

Si estás aquí, **te recomiendo encarecidamente que pruebes primero con la versión recomendada (`v2.0.2` o `v2.0.2` estable)**. Para la inmensa mayoría de los usuarios, esa versión básica limpiará todo y te permitirá volver a instalar Autodesk sin problemas.

### ¿Por qué hay tantas versiones entonces?
Las demás versiones (hasta la v6.0.0) nacieron de leer errores de **otras personas en foros de internet**, Reddit y soporte de Microsoft. El hecho de que existan arquitecturas tan distintas (orientadas a objetos, interactivas, empresariales) es por **mero aprendizaje e investigación**. 

He decidido no subir todo esto como *releases* oficiales que confundan a la gente. En su lugar, he colocado todo este I+D en una carpeta llamada `experimental/` en este repositorio de GitHub para demostrar todo este proceso de ingeniería a la comunidad. Si la versión principal falla en tu caso específico (archivos bloqueados, entornos multi-usuario severos, etc.), entonces y solo entonces, te invito a probar las versiones experimentales más recientes, ya que son mucho más robustas y manejan errores complejos.

---

## 🚀 Inicio Rápido

### Opción A (Recomendada): Usa v6.0 Interactiva (El Archivo Principal)
Esta es la versión más potente y amigable. Te permitirá elegir qué tan profundo quieres llegar.
```powershell
# 1. Click derecho en Autodesk-Nuke.ps1 → "Ejecutar con PowerShell"
# 2. Acepta el aviso de UAC (Permisos de Administrador)
# 3. Elige el Nivel de Limpieza (BASIC, ADVANCED, ENTERPRISE)
# 4. Sigue las instrucciones y REINICIA tu PC al finalizar.
```

### Opción B (Clásica): Usa v2.0.2 (ESTABLE Silenciosa)
Si prefieres el script original que no hace preguntas y ejecuta una limpieza rápida y directa (el que funcionó en un 95% de los casos históricos), usa el archivo Legacy adjunto en la raíz:
```powershell
# 1. Click derecho en Autodesk-Nuke-v2.0.2.ps1 → "Ejecutar con PowerShell"
# 2. Acepta el aviso de UAC
# 3. Espera a que termine. No hay progreso visual moderno, pero hace el trabajo.
# 4. REINICIA tu PC al finalizar.
```

### Si deseas revisar la evolución técnica, explora `/experimental/`:
Revisa nuestra [Guía de la Carpeta Experimental](#-guía-de-la-carpeta-experimental) abajo.

---

## 🎯 ¿Qué hace este script?

1. **💥 Aniquilación de Procesos**
   - Termina procesos bloqueantes: `AutodeskAccess.exe`, `AdSSO.exe`
   - Asesina servicios que se resisten a cierre estándar
   - Rastrea PID mediante WMI para terminación completa

2. **🧠 Detección Inteligente ODIS**
   - Localiza desinstaladores oficiales de Autodesk
   - Los ejecuta silenciosamente antes de usar la fuerza bruta
   - Permite limpieza de licencias de forma segura

3. **👥 Soporte Multi-Usuario (Listo para Intune/SCCM)**
   - Limpia TODOS los perfiles de usuario con el flag `-AllUsers`
   - Monta hives NTUSER.DAT offline para limpieza profunda del registro

4. **💽 Descubrimiento Dinámico de Rutas**
   - Escanea el Registro de Windows por ubicaciones reales
   - Encuentra y limpia instalaciones en discos secundarios (D:, E:, etc.)

5. **🌀 Rompe el Bucle de Reinicio**
   - Elimina la infame clave `PendingFileRenameOperations`
   - Remueve entradas `RebootRequired` bloqueantes
   - Soluciona: *"Por favor reinicia antes de instalar..."*

6. **🧹 Limpieza Integral**
   - Elimina entradas huérfanas de Agregar/Quitar Programas
   - Borra archivos MSI cacheados (`C:\Windows\Installer`)
   - Limpia accesos directos, rutas globales y variables de entorno

---

## 📋 Requisitos del Sistema

- **SO:** Windows 10 o Windows 11
- **PowerShell:** 5.1 o superior
- **Privilegios:** Administrador (el script se auto-eleva)
- **Espacio:** ~500 MB libres
- **Tiempo estimado:** 3-15 minutos según la versión y nivel de daño.

---

## 📁 Guía de la Carpeta `/experimental/`

Como se mencionó, esta carpeta documenta el viaje de ingeniería inspirado en foros:

| Versión Semántica | Ubicación | Propósito y Fiabilidad |
|:---|:---|:---|
| **`v2.0.2`** | Raíz / `v2.0.2/` | **[STABLE]** El script principal probado y recomendado. |
| `v2.4.0-alpha.broken` | `/experimental/v2.4.0...` | **[NO USAR]** Demuestra un intento fallido de refactorización. Su error de `param()` sirve como caso de estudio de mala arquitectura. |
| `v3.0.0-alpha.compact`| `/experimental/v3.0...` | **[PoC]** Prueba de concepto: ¿Se puede hacer un Nuke en solo 60 líneas? Ideal para aprendizaje. |
| `v3.0.0-alpha.oop` | `/experimental/v3.0...` | **[PoC]** Demuestra una arquitectura pesada con Clases de PowerShell y planes de Testing exhaustivos. |
| `v3.0.0-beta` | `/experimental/v3.0...` | **[BETA]** Primera fusión con bandera paramétrica de `DryRun` y barras de progreso. |
| `v4.0.0-rc` | `/experimental/v4.0...` | **[RELEASE CANDIDATE]** La versión *Equilibrada*. Añade reintentos de lectura/escritura en archivos bloqueados del sistema. |
| `v5.0.0-rc` | `/experimental/v5.0...` | **[CORPORATE CANDIDATE]** La versión corporativa con seguimiento de Windows EventLogs e integración SCCM. |
| **`v6.0.0`** | `/experimental/v6.0.0/` | **[INTERACTIVE FINAL]** El peso pesado definitivo. 800 líneas. Permite elegir nivel de borrado interactivamente (BASIC/ADVANCED/ENTERPRISE). |

---

## 🛠️ Solución de Problemas (Troubleshooting)

### Q: El script dice "Acceso Denegado" al intentar borrar una carpeta.
**A:** El archivo está siendo utilizado por el sistema. Usa la versión `v4.0.0-rc` o superior de la carpeta `/experimental/`, las cuales incluyen lógica de reintento automático (`Retry logic`).

### Q: Sigo recibiendo el mensaje "Reinicia tu computadora" al instalar Autodesk.
**A:** El bucle no se rompió completamente. Usa la versión `v6.0.0` y selecciona el nivel de limpieza `ENTERPRISE` para un borrado mucho más agresivo de las claves del registro.

### Q: ¿Puedo deshacer lo que hace este script?
**A:** Solo parcialmente si creaste un **Punto de Restauración** de Windows antes de ejecutarlo. Los archivos en disco se eliminan de forma permanente (sin pasar por la papelera). **¡Úsalo bajo tu propio riesgo!**

---

## ⚖️ Legal y Seguridad

**Aviso Legal:**
Este script modifica el Registro de Windows y elimina forzadamente carpetas críticas creadas por software de terceros. **El autor no asume ninguna responsabilidad por pérdida de datos, inestabilidad del sistema o problemas de licencias derivados de su uso.**

*Inspirado en problemas reales documentados transparentemente y compartido abiertamente.*
