# 📝 NOTAS DE LANZAMIENTO (RELEASE NOTES) | La Historia de la Evolución

> **Este documento explica el viaje de aprendizaje que dio origen desde la versión base hasta la v6.0.0, por qué existe cada versión, dónde se encontraron los problemas y qué soluciona cada actualización.**

---

## 📖 La Historia de Origen

### El Problema Personal
En un inicio, me enfrenté a una pesadilla al tratar de hacer un despliegue limpio de software de Autodesk: **desinstalaciones rotas que impedían reinstalar el software de manera limpia**. El desinstalador oficial dejaba basura por todos lados, las claves de registro bloqueaban nuevas instalaciones y el infame bucle de "Por favor, reinicie su computadora" hacía imposible continuar.

La versión base de **Autodesk-Nuke** nació para resolver este problema específico. En mi caso, esa versión inicial fue suficiente y funcionó a la perfección.

### El Descubrimiento en Foros
A medida que profundizaba en el tema, descubrí que muchos usuarios reportaban distintas variaciones de esta misma pesadilla en diferentes foros de internet:
- **Stack Overflow:** Problemas severos de limpieza de registro.
- **Reddit (r/Autodesk):** Escenarios multi-usuario en laboratorios escolares fallando.
- **Comunidades de Microsoft:** Persistencia del bucle de reinicio atado a la caché de Windows Installer.
- **Issues de GitHub:** Problemas de archivos bloqueados (`FileInUse`) por procesos ocultos.

Cada reporte reveló **casos extremos (edge-cases) que la versión original no manejaba de manera óptima**, ya que mi problema personal nunca había sido tan complejo.

### La Decisión (I+D)
En lugar de crear un único monstruo de script que pudiera asustar a usuarios básicos, decidí transformar este proyecto en un **ejercicio de aprendizaje**:
1. Construir las variaciones necesarias (creando diferentes ramas y versiones).
2. Experimentar con diferentes arquitecturas (desde minimalismo hasta Orientado a Objetos).
3. Colocar todo este ecosistema en una carpeta `/experimental/` para enseñar y compartir este viaje de ingeniería con la comunidad.

---

## 📊 Cronología de Versiones y Justificación

### v2.0.2 / v2.0.2 | La Original (ESTABLE)
**Por qué existe:** 
- Es la solución directa al problema real: los usuarios no podían reinstalar tras un error. 
- Realiza una limpieza agresiva pero probada.
- **Esta es la versión que deberías usar por defecto.**

### v2.4.0-alpha.broken | El Error de Aprendizaje (NO USAR)
**Por qué existe:** 
- Fue el primer intento de modularizar el código.
- Se colocó el bloque `param()` incorrectamente *después* de las definiciones de función, rompiendo por completo la sintaxis de PowerShell.
- **Valor educativo:** Demuestra que no toda refactorización mejora el código y enseña una regla de oro estricta de sintaxis en PowerShell.

### v3.0.0-alpha.compact | La Minimalista
**Por qué existe:** 
- Respuesta a la pregunta: *"¿Se puede hacer esto en 60 líneas?"*
- Condensa todo en 4 bloques operativos sin validaciones. 
- Estupendo para entender qué hace exactamente el script sin distraerse leyendo funciones auxiliares.

### v3.0.0-alpha.oop | La Sobre-Ingeniería
**Por qué existe:** 
- Un experimento de 600 líneas utilizando Clases (`Classes`) y programación orientada a objetos (OOP).
- **Lección aprendida:** A los administradores de sistemas (SysAdmins) no les agrada tener que auditar 600 líneas de código orientado a objetos solo para borrar carpetas. Una arquitectura excelente pero poco práctica para despliegues rápidos.

### v3.0.0-beta | El Primer Gran Avance
**Por qué existe:** 
- Los administradores de entornos corporativos en foros demandaban una forma de **auditar antes de destruir**.
- Se introdujo la bandera de seguridad `-DryRun` y barras de progreso nativas.

### v4.0.0-rc | El Enfoque Equilibrado
**Por qué existe:** 
- Usuarios de foros reportaron fallas silenciosas cuando el sistema tenía los archivos "tomados" (*File in Use*).
- Se equilibró el código añadiendo una lógica robusta de reintento transaccional (vuelve a intentar borrar el archivo bloqueado hasta 3 veces).

### v5.0.0-rc | La Edición Corporativa
**Por qué existe:** 
- Solución a las demandas de integración SOC y cumplimiento de auditorías.
- Empezó a inyectar directamente en el Registro de Eventos de Windows (`Windows Event Log`) para trazar quién, cuándo y cómo se ejecutó el borrado masivo en redes gestionadas por SCCM.

### v6.0.0 | La Síntesis Definitiva (INTERACTIVA)
**Por qué existe:** 
- Se condensó todo lo aprendido. Agregó Interfaz de Usuario Textual (TUI).
- Introduce **Niveles Adaptativos** de borrado interactivos:
  - `BASIC` (2 minutos, riesgo bajísimo).
  - `ADVANCED` (borra temporales además del software).
  - `ENTERPRISE` (caza brutal de perfiles multi-usuario).
- Es una joya de ingeniería con 520 líneas, sin código duplicado.

---

## 🔮 Por qué mostrar la carpeta `/experimental/`

1. **Transparencia:** Muestra exactamente cómo y por qué se toman decisiones arquitectónicas.
2. **Educación:** Puedes comparar un script estructural fallido con uno orientado a objetos.
3. **Comunidad:** Otros ingenieros pueden utilizar este progreso como plantilla para crear limpiadores de otras suites pesadas (ej. Adobe).

**El viaje de la comunidad:**
*Inspirado por problemas presentados en foros, Reddit, y GitHub. Documentado honestamente. Compartido abiertamente.*
