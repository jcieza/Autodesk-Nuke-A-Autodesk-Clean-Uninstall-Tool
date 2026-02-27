# 🚀 Lanzamiento Oficial v2.0.2 / v2.0.2 | Autodesk-Nuke: El Limpiador Definitivo

## ⚠️ Nota Inicial del Desarrollador Principal

> **¡Bienvenido al Lanzamiento Estable de Autodesk-Nuke!**
> "He de confesar que esta versión principal (`v2.0.2` base) **fue más que suficiente en mi caso personal** para solucionar un terrible problema en el bucle de instalación de AutoCAD. Borró los instaladores ocultos, destrabó mi máquina y logré realizar una instalación limpia. Para el 95% de ustedes, este script enlazado será exactamente lo que necesitan: rápido, seguro y brutal con los bloqueos de carpetas."

Entonces, ¿por qué he publicado toda una arquitectura adicional en la carpeta `experimental/` del repositorio? 

A medida que me adentré en foros, hilos de Reddit y discusiones en Microsoft Support, descubrí que la comunidad padecía **escenarios atípicos aterradores**: administradores SCCM frustrados porque sus redes multi-usuario fallaban, claves de registro cifradas de ODIS trabando discos secundarios enteros, y el fatídico "Registro de Reinicio Pendiente" comportándose como un troyano inmortal.

Las demás versiones de la rama experimental nacieron exclusivamente del **mero aprendizaje e I+D inspirado en estos foros**.

---

## 🌟 En qué consiste este lanzamiento
**Autodesk-Nuke** ataca lo imposible rastreando desde cero los entresijos de Windows 10/11 en busca de restos del ecosistema Autodesk (incluso en discos E:, D:, Z:).

### ✅ Lo que logras descargándolo:
1. **Lanzallamas MSI:** Asesina los cachés de instalación "fantasmas" alojados en Windows Installer.
2. **Exterminador Multi-Perfil:** Eliminar las claves en `HKLM` y `HKCU` ya sea tu máquina personal o la de un aula de 30 estudiantes (si activas `-AllUsers`).
3. **Escudo de Operaciones de Sistema:** Filtra con precisión quirúrgica el Registro de "Reinicio Pendiente" de Windows, evitando borrar actualizaciones críticas del sistema atrapadas por error junto al software dañado de Autodesk.

---

## 🛠️ Instrucciones de Uso (Quick-Start)

1. Ve abajo a **Assets** y descarga el archivo `Autodesk-Nuke.ps1`.
2. Otorga al script **Permisos de Administrador** (Click derecho -> "Ejecutar con PowerShell").
3. Espera a que complete su magia (entre 3 a 5 minutos).
4. **Reinicia tu equipo** inmediatamente concluido el proceso.
5. Inicia el instalador oficial de Autodesk. Fluirá como el agua.

### Si tienes fallas corporativas severas (Plan B)
¿El administrador de tu escuela exige logs formales? ¿Tu antivirus lo frena por los archivos compartidos? Si te encuentras en un ambiente "Edge-Case", ignora esta release y ve al repositorio principal en GitHub, a la carpeta `/experimental/`. Allí encontrarás **las versiones de I+D**, mucho más robustas como la `v6.0.0` (Interactiva), o la `v4.0.0-rc` (Con retentativas por bucles lentos en disco duro).

---

> *Este proyecto y sus numerosas variantes son el testimonio y la sistematización de un esfuerzo comunitario de ingeniería inversa. Construido y liberado puramente para compartir el conocimiento.*
