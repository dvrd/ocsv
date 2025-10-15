# Plan de Simplificación y Reorganización de Documentación OCSV

**Fecha:** 2025-10-15
**Objetivo:** Simplificar, des-duplicar y reorganizar la documentación del proyecto OCSV

---

## 1. Análisis del Estado Actual

### Estadísticas
- **Total de archivos markdown:** 52 archivos
- **Total de líneas de documentación:** ~24,000 líneas
- **Archivos en `/docs`:** 47 archivos
- **Documentación principal:** README.md (510 líneas)

### Problemas Identificados

#### A. Duplicación Masiva
- **PRP Results**: 18 archivos PRP-XX-RESULTS.md con información redundante
  - PRP-00 a PRP-14 (15 archivos)
  - PRP-16 con 6 variantes (BASELINE, PHASE1, PHASE2, PHASE3, PERFORMANCE, SIMD)
- **Archivos de Resumen**: 5 archivos con solapamiento:
  - `PHASE_0_SUMMARY.md`
  - `PHASE_1_PLAN.md`
  - `PHASE_1_PROGRESS.md`
  - `PROJECT_ANALYSIS_SUMMARY.md`
  - `ACTION_PLAN.md`
- **Sesiones Temporales**: 3 archivos SESSION-2025-10-13-*.md (desactualizados)

#### B. Documentación Confusa/Desactualizada
- **Métricas contradictorias:**
  - README dice "158 MB/s"
  - Algunos PRP dicen "66 MB/s"
  - Otros dicen "177 MB/s"
- **Estado de fases confuso:**
  - README: "Phase 0 Complete"
  - Pero existen PHASE_1_PLAN y PHASE_1_PROGRESS
  - PRP-16 tiene múltiples "phases" diferentes
- **Archivos CI/CD redundantes:**
  - `CI_CD_RESULTS_TEMPLATE.md`
  - `CI_CD_VALIDATION_CHECKLIST.md`

#### C. Estructura Poco Clara
- **Mezcla de tipos de documentos:**
  - Especificaciones (PRP-XX-SPEC.md)
  - Resultados (PRP-XX-RESULTS.md)
  - Análisis temporales (SESSION-*.md)
  - Planes (ACTION_PLAN, PHASE_1_PLAN)
  - Resúmenes (múltiples SUMMARY)
- **Sin jerarquía clara:**
  - No hay guías de "por dónde empezar"
  - Documentos técnicos mezclados con planes de proyecto

---

## 2. Propuesta de Reorganización

### 2.1 Nueva Estructura de Carpetas

```
/
├── README.md                    # Punto de entrada principal (simplificado)
├── CLAUDE.md                    # Contexto para Claude (mantener)
├── docs/
│   ├── 01-getting-started/
│   │   ├── README.md           # Guía de inicio rápido
│   │   ├── installation.md     # Instalación detallada
│   │   └── quick-examples.md   # Ejemplos básicos
│   ├── 02-user-guide/
│   │   ├── README.md           # Índice de guías de usuario
│   │   ├── api-reference.md    # Consolidado de API.md
│   │   ├── configuration.md    # Opciones de configuración
│   │   ├── error-handling.md   # Manejo de errores
│   │   └── cookbook.md         # Recetas comunes (COOKBOOK.md simplificado)
│   ├── 03-advanced/
│   │   ├── README.md           # Guía avanzada
│   │   ├── streaming.md        # Streaming API
│   │   ├── transforms.md       # Sistema de transformaciones
│   │   ├── plugins.md          # Desarrollo de plugins
│   │   ├── schema-validation.md # Validación de esquemas
│   │   └── parallel-processing.md # Procesamiento paralelo
│   ├── 04-internals/
│   │   ├── README.md           # Arquitectura interna
│   │   ├── architecture.md     # Consolidado de ARCHITECTURE_OVERVIEW.md
│   │   ├── rfc4180-compliance.md # RFC4180.md
│   │   ├── simd-optimization.md  # Consolidado de SIMD docs
│   │   ├── memory-management.md  # MEMORY.md
│   │   └── performance-tuning.md # PERFORMANCE.md simplificado
│   ├── 05-development/
│   │   ├── README.md           # Guía de desarrollo
│   │   ├── contributing.md     # CONTRIBUTING.md
│   │   ├── testing.md          # Guía de testing
│   │   ├── ci-cd.md           # CI/CD consolidado
│   │   └── code-quality.md    # CODE_QUALITY_AUDIT.md simplificado
│   └── 06-project-history/
│       ├── README.md           # Historia del proyecto
│       ├── roadmap.md          # Futuro del proyecto
│       ├── changelog.md        # Cambios por versión (NUEVO)
│       └── prp-archive/        # Archivo de PRPs (referencia histórica)
│           ├── README.md       # Índice de PRPs completados
│           └── [PRP files moved here]
├── benchmarks/
│   └── README.md               # Benchmark guide (mantener)
├── examples/
│   └── README.md               # Examples guide (mantener)
├── plugins/
│   └── README.md               # Plugin dev guide (mantener)
└── PRPs/                       # PRPs ACTIVOS solamente
    └── [Only active PRPs]
```

### 2.2 Mapeo de Archivos (De → A)

#### Mantener y Mejorar
```
README.md → README.md (simplificado, ~200 líneas)
docs/API.md → docs/02-user-guide/api-reference.md (consolidado)
docs/COOKBOOK.md → docs/02-user-guide/cookbook.md (simplificado)
docs/RFC4180.md → docs/04-internals/rfc4180-compliance.md
docs/ARCHITECTURE_OVERVIEW.md → docs/04-internals/architecture.md
docs/PERFORMANCE.md → docs/04-internals/performance-tuning.md
docs/INTEGRATION.md → docs/02-user-guide/bun-integration.md
docs/CONTRIBUTING.md → docs/05-development/contributing.md
docs/MEMORY.md → docs/04-internals/memory-management.md
```

#### Consolidar (Múltiples → Uno)
```
# SIMD docs
docs/SIMD_INVESTIGATION.md +
docs/PRP-16-SIMD-ANALYSIS.md +
docs/SESSION-2025-10-13-SIMD-ANALYSIS.md
→ docs/04-internals/simd-optimization.md (1 documento consolidado)

# Project summaries
docs/PHASE_0_SUMMARY.md +
docs/PROJECT_ANALYSIS_SUMMARY.md +
docs/ACTION_PLAN.md
→ docs/06-project-history/roadmap.md +
  docs/06-project-history/changelog.md

# CI/CD docs
docs/CI_CD_RESULTS_TEMPLATE.md +
docs/CI_CD_VALIDATION_CHECKLIST.md
→ docs/05-development/ci-cd.md

# Code quality
docs/CODE_QUALITY_AUDIT.md
→ docs/05-development/code-quality.md (simplificado)
```

#### Archivar (Mover a project-history/prp-archive/)
```
docs/PRP-00-RESULTS.md → docs/06-project-history/prp-archive/PRP-00.md
docs/PRP-01-RESULTS.md → docs/06-project-history/prp-archive/PRP-01.md
... (todos los PRP-XX-RESULTS.md)
docs/PRP-16-*.md → docs/06-project-history/prp-archive/PRP-16/ (subfolder)
```

#### Eliminar (Temporales/Obsoletos)
```
ELIMINAR:
- docs/SESSION-2025-10-13-*.md (3 archivos - obsoletos)
- docs/PHASE_1_PLAN.md (duplicado en ACTION_PLAN)
- docs/PHASE_1_PROGRESS.md (obsoleto, Phase 1 completa)
- PHASE_1_DAY_1_SUMMARY.md (raíz, temporal)

MANTENER en PRPs/ solo:
- PRPs activos (fase actual)
- PRPs/javascript-api-improvements-prd.md (activo)
- PRPs/phase-1-config-and-errors.md (activo)
```

---

## 3. Plan de Implementación por Fases

### Fase 1: Análisis y Backup (30 min)
**Objetivo:** Proteger datos existentes

**Tareas:**
1. ✅ Crear backup completo: `cp -r docs docs.backup-2025-10-15`
2. ✅ Generar índice de contenidos: Script para mapear qué contiene cada doc
3. ✅ Identificar información única vs duplicada
4. ✅ Validar que no hay información crítica única en archivos a eliminar

**Comandos:**
```bash
# Backup
cp -r docs docs.backup-2025-10-15

# Índice de contenidos
for f in docs/*.md; do
  echo "=== $f ===" >> docs-content-index.txt
  head -50 "$f" >> docs-content-index.txt
  echo "" >> docs-content-index.txt
done

# Buscar información única
grep -r "CRITICAL" docs/*.md > critical-info.txt
grep -r "TODO" docs/*.md > todos-found.txt
```

**Criterio de Éxito:** Backup creado, índice generado, información crítica identificada

---

### Fase 2: Crear Nueva Estructura (45 min)
**Objetivo:** Establecer nueva organización de carpetas

**Tareas:**
1. Crear nueva jerarquía de carpetas `docs/01-getting-started/` a `docs/06-project-history/`
2. Crear README.md en cada carpeta con índice y descripción
3. Crear archivos `.gitkeep` donde sea necesario

**Script de Automatización:**
```bash
#!/bin/bash
# create-doc-structure.sh

mkdir -p docs/{01-getting-started,02-user-guide,03-advanced,04-internals,05-development,06-project-history/prp-archive}

# Create README.md files
cat > docs/01-getting-started/README.md << 'EOF'
# Getting Started with OCSV

Quick start guides for new users.

## Documents in this section:
- [Installation Guide](installation.md)
- [Quick Examples](quick-examples.md)
EOF

# ... (similar para otras carpetas)
```

**Criterio de Éxito:** Nueva estructura creada con READMEs descriptivos

---

### Fase 3: Consolidación de Documentos (2 horas)
**Objetivo:** Fusionar documentos duplicados

**Tareas prioritarias:**

#### 3.1 SIMD Documentation (30 min)
**Consolidar:**
- `docs/SIMD_INVESTIGATION.md` (475 líneas)
- `docs/PRP-16-SIMD-ANALYSIS.md`
- `docs/SESSION-2025-10-13-SIMD-ANALYSIS.md`

**→ Nuevo documento:** `docs/04-internals/simd-optimization.md`

**Contenido:**
```markdown
# SIMD Optimization in OCSV

## Overview
[Resumen de qué es SIMD y por qué importa]

## Implementation Details
[Detalles técnicos consolidados]

## Performance Results
[Benchmarks finales - una sola fuente de verdad]

## ARM NEON vs SSE4.2
[Comparación de implementaciones]

## Debugging and Profiling
[Tips consolidados]

## References
- PRP-13: SIMD Implementation
- PRP-16: Performance Refinement
```

#### 3.2 Project History (30 min)
**Consolidar:**
- `docs/PHASE_0_SUMMARY.md`
- `docs/PROJECT_ANALYSIS_SUMMARY.md`
- `docs/ACTION_PLAN.md` (extractar roadmap futuro)

**→ Nuevos documentos:**
1. `docs/06-project-history/roadmap.md` (futuro)
2. `docs/06-project-history/changelog.md` (pasado)

**Contenido de changelog.md:**
```markdown
# OCSV Changelog

## Version 0.11.0 (Phase 4 Complete) - 2025-10-14
### Added
- Plugin architecture (PRP-11)
- 4 plugin types
- 3 example plugins

### Performance
- Parser: 158 MB/s
- Writer: 177 MB/s

## Version 0.10.0 (Phase 3 Complete)
... (extraer de PHASE_0_SUMMARY)
```

#### 3.3 API Documentation (30 min)
**Consolidar:**
- `docs/API.md` (1150 líneas - muy largo)

**→ Dividir en:**
1. `docs/02-user-guide/api-reference.md` (API core - ~400 líneas)
2. `docs/03-advanced/streaming.md` (Streaming API - ~200 líneas)
3. `docs/03-advanced/transforms.md` (Transform API - ~200 líneas)
4. `docs/03-advanced/plugins.md` (Plugin API - ~200 líneas)

#### 3.4 README Principal (30 min)
**Simplificar:** README.md de 510 líneas → ~200 líneas

**Nueva estructura:**
```markdown
# OCSV - Odin CSV Parser

[Badges + descripción breve]

## Quick Start
[5 líneas de instalación]
[10 líneas de ejemplo básico]

## Key Features
[Lista de 8-10 features principales]

## Performance
[Tabla simple con métricas finales]

## Documentation
[Enlaces a docs/01-getting-started/, docs/02-user-guide/, etc.]

## Contributing
[Link a docs/05-development/contributing.md]

## License
MIT
```

**Criterio de Éxito:** 4 grupos de documentos consolidados, README simplificado

---

### Fase 4: Archivar PRPs (1 hora)
**Objetivo:** Mover PRPs completados a archivo histórico

**Tareas:**
1. Mover todos `docs/PRP-XX-RESULTS.md` → `docs/06-project-history/prp-archive/`
2. Crear `docs/06-project-history/prp-archive/README.md` con índice
3. Actualizar referencias en otros documentos

**Script:**
```bash
#!/bin/bash
# archive-prps.sh

mkdir -p docs/06-project-history/prp-archive

# Move PRP results
for f in docs/PRP-*-RESULTS.md; do
  if [ -f "$f" ]; then
    mv "$f" docs/06-project-history/prp-archive/
  fi
done

# Create PRP index
cat > docs/06-project-history/prp-archive/README.md << 'EOF'
# PRP Archive

Historical PRPs (Product Requirement Prompts) for OCSV development.

## Completed PRPs

### Phase 0: Core Implementation
- [PRP-00: Foundation](PRP-00-RESULTS.md)
- [PRP-01: RFC 4180 Compliance](PRP-01-RESULTS.md)
...
EOF
```

**Criterio de Éxito:** 18+ archivos PRP movidos, índice creado

---

### Fase 5: Limpieza y Eliminación (30 min)
**Objetivo:** Eliminar archivos obsoletos/temporales

**Archivos a eliminar:**
```bash
# Temporales de sesiones
rm docs/SESSION-2025-10-13-*.md

# Planes obsoletos
rm docs/PHASE_1_PLAN.md
rm docs/PHASE_1_PROGRESS.md
rm PHASE_1_DAY_1_SUMMARY.md
```

**Criterio de Éxito:** 6 archivos eliminados, sin pérdida de información crítica

---

### Fase 6: Actualización de Referencias (1 hora)
**Objetivo:** Actualizar todos los enlaces internos

**Tareas:**
1. Buscar todos los enlaces markdown: `grep -r "\[.*\](.*.md)" docs/`
2. Actualizar enlaces rotos manualmente o con script
3. Actualizar CLAUDE.md con nueva estructura
4. Actualizar README con nuevos enlaces

**Script auxiliar:**
```bash
# find-broken-links.sh
#!/bin/bash

for f in docs/**/*.md README.md; do
  if [ -f "$f" ]; then
    echo "Checking $f..."
    grep -o '\[.*\](.*\.md)' "$f" | while read -r link; do
      file=$(echo "$link" | sed 's/.*(\(.*\))/\1/')
      if [ ! -f "$(dirname "$f")/$file" ] && [ ! -f "$file" ]; then
        echo "  BROKEN: $link in $f"
      fi
    done
  fi
done
```

**Criterio de Éxito:** Todos los enlaces internos funcionan, navegación fluida

---

### Fase 7: Validación Final (30 min)
**Objetivo:** Verificar que toda la información está accesible

**Checklist:**
- [ ] README.md tiene enlaces claros a todas las secciones principales
- [ ] Cada carpeta en `docs/` tiene un README.md descriptivo
- [ ] No hay enlaces rotos (verificado con script)
- [ ] Información crítica preservada (comparar con backup)
- [ ] Métricas consistentes en todos los documentos
- [ ] Estructura lógica y navegable
- [ ] Reducción de al menos 40% en archivos markdown

**Métricas objetivo:**
- **Antes:** 52 archivos, ~24,000 líneas
- **Después:** ~25 archivos activos, ~12,000 líneas útiles
- **Reducción:** ~50% en tamaño, 100% en claridad

**Comando de validación:**
```bash
# Count files and lines
echo "Active docs:"
find docs -name "*.md" -not -path "*/06-project-history/*" | wc -l
find docs -name "*.md" -not -path "*/06-project-history/*" | xargs wc -l

echo "Archived docs:"
find docs/06-project-history -name "*.md" | wc -l
```

---

## 4. Corrección de Información Falsa/Desactualizada

### 4.1 Métricas de Performance (CRÍTICO)
**Problema:** Múltiples valores contradictorios

**Solución:** Establecer **fuente única de verdad**

```markdown
# Performance (OFICIAL - Last Updated: 2025-10-14)

| Componente | Throughput | Test | Status |
|------------|------------|------|--------|
| Parser     | 158 MB/s   | 50MB file | ✅ Validated |
| Writer     | 177 MB/s   | 10MB file | ✅ Validated |
| SIMD Boost | +21%       | ARM NEON  | ✅ Implemented |

**Source:** `tests/test_performance.odin` + `benchmarks/`
```

**Acciones:**
1. Grep all docs para encontrar métricas antiguas
2. Reemplazar con valores oficiales
3. Añadir nota "Last Updated" en cada mención de performance

### 4.2 Estado de Fases
**Problema:** Confusión sobre qué fase está completa

**Solución:** Una sola sección de roadmap

```markdown
# Project Status (Last Updated: 2025-10-14)

✅ **Phase 0 COMPLETE** - All 14 PRPs implemented (PRP-00 to PRP-14)

📊 **Current Status:**
- Version: 0.11.0
- Tests: 203/203 passing (100%)
- Memory Leaks: 0
- Code Quality: 9.9/10
- Production Ready: ✅ YES

🔮 **Future Work:**
- Phase 1: JavaScript API improvements (IN PROGRESS)
- Phase 2: Advanced features (planned)
```

### 4.3 Platform Support
**Problema:** README dice "macOS only" en algunos lugares

**Solución:** Actualizar todas las referencias

```markdown
# Supported Platforms

✅ **Production Ready:**
- macOS (ARM64, x86_64)
- Linux (x86_64)
- Windows (x86_64)

**CI/CD:** Automated builds for all platforms
```

---

## 5. Estrategia de Migración Segura

### Principio: "Copy, Don't Delete"
1. **Nunca** eliminar hasta verificar
2. Crear nuevos docs antes de borrar viejos
3. Mantener backup durante 1 semana
4. Git commit incremental por fase

### Git Strategy
```bash
# Fase 1
git checkout -b doc-simplification
git commit -m "docs: create backup and analysis"

# Fase 2
git commit -m "docs: create new folder structure"

# Fase 3
git commit -m "docs: consolidate SIMD documentation"
git commit -m "docs: consolidate project history"
git commit -m "docs: split API documentation"
git commit -m "docs: simplify README"

# Fase 4
git commit -m "docs: archive completed PRPs"

# Fase 5
git commit -m "docs: remove obsolete files"

# Fase 6
git commit -m "docs: update all internal links"

# Fase 7
git commit -m "docs: final validation and cleanup"

# Final
git push origin doc-simplification
# Create PR for review
```

---

## 6. Métricas de Éxito

### Objetivos Cuantitativos
- ✅ Reducción del 50%+ en número de archivos markdown activos
- ✅ Reducción del 40%+ en líneas de documentación
- ✅ 0 enlaces rotos
- ✅ 100% de información crítica preservada
- ✅ Tiempo de onboarding reducido (medible con feedback)

### Objetivos Cualitativos
- ✅ Estructura lógica y navegable (1-2-3-4-5-6)
- ✅ Información consistente (una sola fuente de verdad para métricas)
- ✅ Documentación actualizada al 100%
- ✅ Fácil de mantener (estructura clara para futuros PRPs)

### Validación con Usuario
```
Preguntar a desarrollador nuevo:
1. ¿Puedes encontrar cómo instalar en < 1 minuto? (debe ser SÍ)
2. ¿Puedes encontrar ejemplo básico en < 2 minutos? (debe ser SÍ)
3. ¿Entiendes el estado actual del proyecto? (debe ser SÍ)
4. ¿La documentación tiene información contradictoria? (debe ser NO)
```

---

## 7. Mantenimiento Futuro

### Reglas para Nuevos Documentos
1. **Un documento, un propósito**
   - No mezclar tutorial con referencia API
   - No mezclar historia con roadmap

2. **Naming Convention:**
   - `docs/0X-category/descriptive-name.md`
   - Siempre lowercase, guiones
   - No usar números en nombres (excepto carpetas)

3. **Cada documento debe tener:**
   - Título claro
   - "Last Updated" date
   - Enlaces a documentos relacionados
   - Sección "Prerequisites" si aplica

4. **No crear PRPs en `/docs`:**
   - PRPs activos → `/PRPs/`
   - PRPs completados → `/docs/06-project-history/prp-archive/`

### Proceso para Nuevas Features
```
1. Create PRP in /PRPs/feature-name.md
2. Implement feature
3. Update relevant user docs (docs/02-user-guide/)
4. Update changelog (docs/06-project-history/changelog.md)
5. Move PRP to archive when complete
```

---

## 8. Riesgos y Mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Perder información crítica | Baja | Alto | Backup completo, verificación manual |
| Enlaces rotos post-migración | Media | Medio | Script de validación, testing manual |
| Usuario confundido por cambios | Media | Medio | README claro con "What changed" |
| Duplicar esfuerzo | Baja | Bajo | Plan detallado, checklist por fase |
| Revertir cambios difícil | Baja | Alto | Git commits incrementales |

---

## 9. Timeline Estimado

| Fase | Duración | Dependencias |
|------|----------|--------------|
| 1. Análisis y Backup | 30 min | Ninguna |
| 2. Nueva Estructura | 45 min | Fase 1 |
| 3. Consolidación | 2 horas | Fase 2 |
| 4. Archivar PRPs | 1 hora | Fase 2 |
| 5. Limpieza | 30 min | Fase 3, 4 |
| 6. Actualizar Referencias | 1 hora | Fase 5 |
| 7. Validación Final | 30 min | Todas anteriores |
| **TOTAL** | **6.5 horas** | |

**Timeline realista:** 1-2 días de trabajo (con pausas y revisión)

---

## 10. Checklist de Implementación

### Pre-Implementación
- [ ] Leer plan completo
- [ ] Entender estructura propuesta
- [ ] Confirmar con stakeholder (si aplica)
- [ ] Crear backup

### Durante Implementación
- [ ] Fase 1: Backup y análisis
- [ ] Fase 2: Estructura de carpetas
- [ ] Fase 3: Consolidar docs
- [ ] Fase 4: Archivar PRPs
- [ ] Fase 5: Eliminar obsoletos
- [ ] Fase 6: Actualizar enlaces
- [ ] Fase 7: Validación final

### Post-Implementación
- [ ] Commit todos los cambios
- [ ] Push a branch
- [ ] Create PR
- [ ] Self-review
- [ ] Test navegación manualmente
- [ ] Actualizar CLAUDE.md si necesario

---

## Apéndice A: Scripts de Automatización

### Script 1: Backup Completo
```bash
#!/bin/bash
# backup-docs.sh

DATE=$(date +%Y-%m-%d)
BACKUP_DIR="docs.backup-$DATE"

echo "Creating backup: $BACKUP_DIR"
cp -r docs "$BACKUP_DIR"
cp README.md "$BACKUP_DIR/"
cp CLAUDE.md "$BACKUP_DIR/"

echo "Backup created successfully!"
echo "Location: $(pwd)/$BACKUP_DIR"
```

### Script 2: Análisis de Contenido
```bash
#!/bin/bash
# analyze-docs.sh

OUTPUT="docs-analysis.txt"

echo "=== OCSV Documentation Analysis ===" > "$OUTPUT"
echo "Date: $(date)" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "File Count:" >> "$OUTPUT"
find docs -name "*.md" | wc -l >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "Line Count by File:" >> "$OUTPUT"
wc -l docs/*.md | sort -n >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "Performance Mentions:" >> "$OUTPUT"
grep -r "MB/s\|throughput" docs/*.md >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "Phase Mentions:" >> "$OUTPUT"
grep -r "Phase [0-9]" docs/*.md | cut -d: -f1 | sort | uniq -c >> "$OUTPUT"

echo "Analysis saved to: $OUTPUT"
```

### Script 3: Validación de Enlaces
```bash
#!/bin/bash
# validate-links.sh

BROKEN_LINKS=0

echo "=== Validating Internal Links ==="

for f in $(find docs -name "*.md"); do
  echo "Checking: $f"

  grep -o '\[.*\](.*\.md)' "$f" | while read -r link; do
    target=$(echo "$link" | sed 's/.*(\(.*\))/\1/')

    # Check relative to file location
    dir=$(dirname "$f")
    full_path="$dir/$target"

    if [ ! -f "$full_path" ] && [ ! -f "$target" ]; then
      echo "  ❌ BROKEN: $link"
      ((BROKEN_LINKS++))
    fi
  done
done

if [ $BROKEN_LINKS -eq 0 ]; then
  echo "✅ All links valid!"
  exit 0
else
  echo "❌ Found $BROKEN_LINKS broken links"
  exit 1
fi
```

---

## Conclusión

Este plan proporciona una estrategia completa y segura para simplificar la documentación de OCSV, reduciendo la duplicación, eliminando información falsa, y creando una estructura clara y mantenible.

**Próximo Paso:** Revisar este plan con el equipo y comenzar Fase 1 (Backup y Análisis).
