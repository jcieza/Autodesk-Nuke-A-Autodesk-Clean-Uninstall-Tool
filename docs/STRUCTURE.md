# 📁 Estructura del Repositorio en GitHub y Guía de la Carpeta `/experimental/`

## 🎯 Arquitectura del Directorio

```
autodesk-nuke/
│
├── README.md                    ← COMIENZA AQUÍ (guía exhaustiva)
├── RELEASE_NOTES.md             ← La historia de evolución del proyecto
├── LICENSE                      ← Licencia MIT
│
├── experimental/                ← TODAS LAS VERSIONES (enseñanza & referencia)
│   │
│   ├── v2.0.2/
│   │   ├── Autodesk-Nuke.ps1   (LA VERSIÓN ESTABLE - EMPAQUETADA AQUÍ)
│   │   └── README.md            (Docs específicos de v2.0.2)
│   │
│   ├── v2.4.0-alpha.broken/
│   │   ├── Autodesk-Nuke.ps1   (ROTA - No usar)
│   │   ├── ERROR_ANALYSIS.md    (Qué salió mal y por qué)
│   │   └── README.md            (Explicación del valor de enseñanza)
│   │
│   ├── v3.0.0-alpha.compact/
│   │   ├── Autodesk-Nuke-Compact.ps1  (60 líneas - aprendizaje puro)
│   │   └── README.md                   (Compromisos del minimalismo)
│   │
│   ├── v3.0.0-alpha.oop/
│   │   ├── Autodesk-Nuke-OOP.ps1      (600 líneas - Diseño OOP)
│   │   ├── ARCHITECTURE.md             (Documentos de diseño de Clases)
│   │   ├── testing_plan.md             (Estrategia de pruebas)
│   │   └── README.md                   (Por qué OOP fue 'demasiado')
│   │
│   ├── v3.0.0-beta/
│   │   ├── Autodesk-Nuke-DryRun.ps1   (Primera funcionalidad de DryRun)
│   │   └── README.md                   (Nuevas características documentadas)
│   │
│   ├── v4.0.0-rc/
│   │   ├── Autodesk-Nuke-Equilibrada.ps1  (Enfoque equilibrado)
│   │   ├── FEATURES.md                     (Nuevo manejo de errores en sistema)
│   │   └── README.md                       (Por qué es la versión "equilibrada")
│   │
│   ├── v5.0.0-rc/
│   │   ├── Autodesk-Nuke-Enterprise.ps1   (Capacidades empresariales)
│   │   ├── ENTERPRISE_FEATURES.md         (Registro de Eventos, auditoría SOC)
│   │   └── README.md                      (Casos de uso para administradores)
│   │
│   └── v6.0.0/
│       ├── Autodesk-Nuke-FINAL-v6.0.ps1  (El gigante - todas las características)
│       ├── ARCHITECTURE.md                (Diseño interactivo detallado)
│       ├── COMPARISON.md                  (Matriz contra todas las versiones)
│       └── README.md                      (Instrucciones de uso en terminal)
│
├── docs/                        ← DOCUMENTACIÓN DETALLADA ADICIONAL
│   ├── STRUCTURE.md             (Este documento)
│   └── ...
```

---

## 🔍 Descifrando la Carpeta Experimental

La carpeta `experimental` no es un cementerio de código obsoleto. Las letras Griegas (alpha, beta, rc) no indican inestabilidad, sino más bien **etapas de evolución** del script intentando solucionar variantes muy concretas de problemas hallados en internet.

A continuación, una revisión rápida de las filosofías detrás de cada versión:

### 1. La Inicia: `v2.4.0-alpha.broken`
**Por qué existe:** Es un ejemplo vivo de por qué la refactorización a ciegas no siempre funciona.
**El error intencional:** El bloque `param()` de entrada de variables se definió por debajo de la creación de las funciones `Ensure-Admin`, rompiendo la sintaxis primordial de PowerShell en el parser. 
**Lección:** Un gran desarrollador siempre prueba antes de empujar código.

### 2. El Minimalismo: `v3.0.0-alpha.compact`
Estructura un `Autodesk-Nuke.ps1` comprimido en aproximadamente 60 líneas de código brutal y directo. Es perfecto para quienes deseen estudiar el núcleo anatómico del motor de borrado sin distracciones corporativas (barras de progreso, validaciones de logs, auditoría).

### 3. La Institucionalización: `v3.0.0-alpha.oop`
Introduce Programación Orientada a Objetos en PowerShell (`Classes` con decenas de métodos). Es inviable auditar a simple vista sus 600 líneas cuando la prioridad en ciberseguridad demanda entender instantáneamente qué hace una herramienta de escalada de privilegios con *ExecutionPolicy Bypass*. Su complejidad sentenció su abandono en la rama principal.

### 4. La Fase Beta y RC: `v3.0.0-beta` & `v4.0.0-rc`
Introdujeron las demandas más populares de arquitectos de sistemas en Reddit: `DryRun` (simulador de ejecución) y un capturador estricto pero inteligente que intentaba borrar archivos 3 veces y si el proceso hostil se resistía (FileInUse), pasaba al siguiente sin dar error fatal (`ErrorAction`).

### 5. Las Aspiraciones Empresariales: `v5.0.0-rc` & `v6.0.0`
Versiones sobredimensionadas que incluyen reportes JSON integrados por consola y flujos interactivos de menús (`BASIC`, `ADVANCED`, `ENTERPRISE`). Son excelentes para integradores SCCM experimentados y puristas del código.

---

## 💡 Filosofía de Repositorio de Código Abierto

Este repositorio rechaza la costumbre tradicional de GitHub de solo exponer el archivo de "Lanzamiento Final". Hemos destilado el caos para exponer de forma íntegra las iteraciones y callejones sin salida de un modelo de ingeniería real en Windows.

Empieza con la versión estable (`v2.0.2` en Releases / `v2.0.2` como base sólida) y **explora el resto para nutrir tu arsenal de PowerShell.**
