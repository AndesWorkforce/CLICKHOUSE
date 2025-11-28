# Análisis de Viabilidad: Data Warehouse en ClickHouse

## 📋 Resumen Ejecutivo

Este documento analiza la viabilidad de implementar la arquitectura de Data Warehouse propuesta en ClickHouse basándose en los schemas actuales de Prisma y la estructura de datos existente.

**Conclusión:** ✅ **Es viable**, pero requiere **adaptaciones importantes** en el payload del agente y en las transformaciones ETL.

---

## 🔍 Comparación: Estructura Actual vs Propuesta

### 1. Schema de Prisma - Event (EVENTS_MS)

#### ✅ Lo que SÍ tienes y coincide:

| Campo Propuesta | Campo Actual | Estado |
|----------------|--------------|--------|
| `event_id` | `id` (cuid) | ✅ Coincide |
| `contractor_id` | `contractor_id` | ✅ Coincide |
| `agent_id` | `agent_id` | ✅ Coincide |
| `session_id` | `session_id` | ✅ Coincide |
| `agent_session_id` | `agent_session_id` | ✅ Coincide |
| `timestamp` | `timestamp` | ✅ Coincide |
| `created_at` | `created_at` | ✅ Coincide |
| `payload` | `payload` (JSON) | ✅ Coincide |

#### ❌ Lo que NO tienes en el payload actual:

| Campo Requerido Propuesta | Estructura Actual | Diferencia |
|---------------------------|-------------------|------------|
| `keyboard_count` (UInt32) | `Keyboard.InactiveTime` (number) | ⚠️ Tienes tiempo inactivo, NO conteo de inputs |
| `mouse_clicks` (UInt32) | `Mouse.InactiveTime` (number) | ⚠️ Tienes tiempo inactivo, NO conteo de clicks |
| `mouse_distance` (Float64) | ❌ No existe | ❌ No se captura |
| `active_app` (String) | `AppUsage: { [app]: duration }` | ⚠️ Tienes duración acumulada, NO app activa en el momento |
| `active_window` (String) | `ActiveApplications[].window_title` (opcional) | ⚠️ Solo en formato alternativo |

### 2. Schema de Prisma - Otras Tablas (USER_MS)

#### ✅ Tablas RAW disponibles:

| Tabla Propuesta | Tabla Actual Prisma | Estado | Mapeo |
|----------------|---------------------|--------|-------|
| `sessions_raw` | `Session` | ✅ Disponible | Directo (session_id, contractor_id, session_start, session_end, total_duration) |
| `agent_sessions_raw` | `AgentSession` | ✅ Disponible | Directo (id, contractor_id, agent_id, session_start, session_end, total_duration) |
| `contractor_info_raw` | `Contractor` | ✅ Disponible | Directo + enriquecimiento con Client, Team |

#### ✅ Relaciones disponibles:

- `Contractor` → `Client` (client_id) ✅
- `Contractor` → `Team` (team_id) ✅
- `Contractor` → `ContractorApp` → `Application` (apps permitidas) ✅
- `Agent` → `Contractor` (contractor_id) ✅

---

## 🚨 Problemas Identificados y Soluciones

### Problema 1: Payload del Agente - Métricas Incrementales vs Acumulativas

**Problema:**
- **Actual:** El agente envía `InactiveTime` (tiempo desde última actividad) y `AppUsage` (duración acumulada)
- **Propuesta:** Necesita `keyboard_count`, `mouse_clicks`, `active_app` (snapshot por heartbeat)

**Solución A - Modificar el Agente (RECOMENDADO):**

Modificar `PY_AGENT/mini_agent.py` para capturar eventos incrementales:

```python
# En lugar de solo InactiveTime, capturar:
keyboard_count = 0  # Contador de teclas presionadas
mouse_clicks = 0    # Contador de clicks
mouse_distance = 0.0  # Píxeles recorridos
active_app = get_active_window_app()  # App actual
active_window = get_active_window_title()  # Ventana actual

# Resetear contadores cada 15s antes de enviar
```

**Solución B - Transformar en ETL (ALTERNATIVA):**

Calcular aproximaciones desde `InactiveTime`:
- Si `Keyboard.InactiveTime == 0` → `keyboard_count = estimado` (basado en promedio histórico)
- Si `Mouse.InactiveTime == 0` → `mouse_clicks = estimado`
- `active_app` = App con mayor duración en `AppUsage` del intervalo anterior

⚠️ **Limitación:** Esta aproximación es menos precisa que capturar eventos reales.

### Problema 2: Estructura de `AppUsage` vs `ActiveApplications`

**Actual:**
```json
{
  "AppUsage": {
    "Chrome": 450,
    "Word": 1200,
    "Excel": 600
  }
}
```

**Propuesta necesita:**
- `active_app`: String con el nombre de la app activa en ese momento
- `active_window`: String con el título de la ventana

**Solución:**
- Agregar campos `active_app` y `active_window` al payload del agente
- Mantener `AppUsage` para análisis de duración acumulada

### Problema 3: Métricas de Mouse - Falta Distancia

**Actual:** Solo `Mouse.InactiveTime`

**Propuesta necesita:** `mouse_distance` (píxeles recorridos)

**Solución:**
- Implementar tracking de movimiento del mouse en el agente Python
- Acumular distancia en ventana de 15s

---

## ✅ Viabilidad de las Tablas RAW

### `events_raw`

**Estado:** ✅ **100% Viable**

```sql
CREATE TABLE events_raw (
  event_id String,
  contractor_id String,
  agent_id String,
  session_id String,
  agent_session_id String,
  timestamp DateTime,
  payload String,  -- JSON string (como viene de Postgres)
  created_at DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toDate(timestamp)
ORDER BY (contractor_id, timestamp);
```

**Fuente:** `EVENTS_MS.prisma.Event` → Sincronización directa via ETL

### `sessions_raw`

**Estado:** ✅ **100% Viable**

**Fuente:** `USER_MS.prisma.Session`

**Campos disponibles:**
- ✅ `session_id` → `id`
- ✅ `contractor_id` → `contractor_id`
- ✅ `session_start` → `session_start`
- ✅ `session_end` → `session_end`
- ✅ `total_duration` → `total_duration`

### `agent_sessions_raw`

**Estado:** ✅ **100% Viable**

**Fuente:** `USER_MS.prisma.AgentSession`

**Campos disponibles:**
- ✅ `agent_session_id` → `id`
- ✅ `contractor_id` → `contractor_id`
- ✅ `agent_id` → `agent_id`
- ✅ `session_start` → `session_start`
- ✅ `session_end` → `session_end`
- ✅ `total_duration` → `total_duration`

### `contractor_info_raw`

**Estado:** ✅ **100% Viable con Enriquecimiento**

**Fuente:** `USER_MS.prisma.Contractor` + `Client` + `Team`

**JOIN requerido:**
```sql
SELECT 
  c.id AS contractor_id,
  c.client_id,
  c.team_id,
  c.country,
  c.job_position,
  c.created_at,
  c.updated_at
FROM contractors c
```

---

## ⚠️ Viabilidad de las Tablas ADT

### `contractor_activity_15s`

**Estado:** ⚠️ **Viable con Modificaciones**

**Campos requeridos:**
- ✅ `contractor_id`, `agent_id`, `session_id`, `agent_session_id` → Disponibles
- ✅ `beat_timestamp` → `timestamp` del evento
- ⚠️ `keyboard_count` → **REQUIERE CAMBIO EN AGENTE** o aproximación ETL
- ⚠️ `mouse_clicks` → **REQUIERE CAMBIO EN AGENTE** o aproximación ETL
- ⚠️ `mouse_distance` → **REQUIERE CAMBIO EN AGENTE**
- ⚠️ `active_app` → **REQUIERE CAMBIO EN AGENTE** o inferencia desde `AppUsage`
- ⚠️ `active_window` → **REQUIERE CAMBIO EN AGENTE** o `ActiveApplications[].window_title`
- ✅ `is_idle` → Calculable desde `IdleTime > threshold`

**Materialized View Adaptada:**

```sql
CREATE MATERIALIZED VIEW mv_events_to_activity
TO contractor_activity_15s AS
SELECT
  contractor_id,
  agent_id,
  session_id,
  agent_session_id,
  timestamp AS beat_timestamp,
  
  -- Calculado desde payload actual
  if(JSONExtractFloat(payload, 'IdleTime', 0.0) > 0, 1, 0) AS is_idle,
  
  -- APROXIMACIONES (hasta modificar agente)
  if(JSONExtractFloat(payload, 'Keyboard', 'InactiveTime', 999) = 0, 
     multiIf(
       JSONExtractFloat(payload, 'IdleTime', 999) = 0, 50,  -- Activo → estimado
       0
     ), 0) AS keyboard_count,
     
  if(JSONExtractFloat(payload, 'Mouse', 'InactiveTime', 999) = 0,
     multiIf(
       JSONExtractFloat(payload, 'IdleTime', 999) = 0, 20,  -- Activo → estimado
       0
     ), 0) AS mouse_clicks,
     
  0.0 AS mouse_distance,  -- No disponible hasta modificar agente
  
  -- Inferir active_app desde AppUsage (app con mayor duración)
  arrayElement(
    arraySort((x, y) -> y,
      groupArray(
        (k, JSONExtractFloat(payload, 'AppUsage', k))
      )
    ), 1
  ) AS active_app,
  
  '' AS active_window,  -- No disponible consistentemente
  
  toDate(timestamp) AS workday,
  now() AS created_at
FROM events_raw;
```

⚠️ **Nota:** Esta MV usa aproximaciones. Para producción, modificar el agente.

### `contractor_daily_metrics`

**Estado:** ✅ **Viable** (depende de `contractor_activity_15s`)

Una vez que `contractor_activity_15s` esté poblada, las agregaciones son directas.

### `app_usage_summary`

**Estado:** ✅ **Viable con Adaptación**

Puede usar `AppUsage` directamente del payload:

```sql
CREATE MATERIALIZED VIEW mv_app_usage_summary
TO app_usage_summary AS
SELECT
  contractor_id,
  k AS app_name,  -- Key del diccionario AppUsage
  toDate(timestamp) AS workday,
  
  -- Aproximar beats activos desde duración
  round(JSONExtractFloat(payload, 'AppUsage', k) / 15.0) AS active_beats,
  
  -- Otras métricas desde payload
  now() AS created_at
FROM events_raw
ARRAY JOIN JSONExtractKeys(payload, 'AppUsage') AS k
WHERE JSONHas(payload, 'AppUsage', k);
```

### `session_summary`

**Estado:** ✅ **100% Viable**

Agregaciones desde `contractor_activity_15s` agrupando por `session_id`.

---

## 🔄 Estrategia de Implementación Recomendada

### Fase 1: Implementación Inmediata (Con Datos Actuales)

1. ✅ Crear tablas RAW en ClickHouse
2. ✅ Implementar ETL `Postgres → ClickHouse` para eventos, sesiones, agent_sessions
3. ⚠️ Crear `contractor_activity_15s` con aproximaciones (usando `IdleTime`)
4. ✅ Crear agregaciones diarias básicas
5. ⚠️ Implementar `productivity_score` simplificado (solo basado en `IdleTime`)

**Limitaciones:**
- `keyboard_count`, `mouse_clicks` serán aproximaciones
- `mouse_distance` = 0
- `active_app` será inferido (menos preciso)

### Fase 2: Mejora del Agente (Recomendado)

1. Modificar `PY_AGENT/mini_agent.py`:
   - Agregar contadores de teclas presionadas
   - Agregar contador de clicks de mouse
   - Agregar tracking de distancia de mouse
   - Agregar captura de `active_app` y `active_window` en cada heartbeat

2. Actualizar DTO en `EVENTS_MS/src/events/dto/create-event.dto.ts`:

```typescript
payload: {
  // Mantener existentes para backward compatibility
  Keyboard?: { InactiveTime?: number; Count?: number };
  Mouse?: { InactiveTime?: number; Clicks?: number; Distance?: number };
  IdleTime?: number;
  AppUsage?: { [app: string]: number };
  
  // Nuevos campos
  active_app?: string;
  active_window?: string;
  keyboard_count?: number;
  mouse_clicks?: number;
  mouse_distance?: number;
}
```

3. Reprocesar eventos históricos (opcional)

### Fase 3: Optimización

1. Calibrar `productivity_score` con datos reales
2. Ajustar pesos de las métricas
3. Agregar alertas y detección de anomalías
4. Optimizar queries para dashboards

---

## 📊 Adaptaciones Necesarias en la Propuesta

### Cambios en Materialized Views

Las MVs propuestas deben adaptarse para trabajar con:
- `Keyboard.InactiveTime` en lugar de `keyboard_count`
- `Mouse.InactiveTime` en lugar de `mouse_clicks`
- `AppUsage` dict en lugar de `active_app` (hasta que se agregue)

### Cambios en Cálculo de Productividad

**Productividad simplificada (Fase 1):**

```sql
-- Basado solo en IdleTime
productivity_score = 100 * (1 - (total_idle_time / total_time))
```

**Productividad completa (Fase 2):**

Usar la fórmula propuesta con todos los componentes.

### Cambios en Queries de Dashboard

Los queries deben adaptarse a la estructura actual:

```sql
-- En lugar de:
SELECT active_app, count() FROM contractor_activity_15s

-- Usar:
SELECT 
  k AS app_name,
  sum(JSONExtractFloat(payload, 'AppUsage', k)) AS total_duration
FROM events_raw
ARRAY JOIN JSONExtractKeys(payload, 'AppUsage') AS k
GROUP BY k
```

---

## ✅ Checklist de Viabilidad

| Componente | Viabilidad | Requisitos |
|------------|------------|------------|
| **Tablas RAW** | ✅ 100% | Solo ETL Postgres → ClickHouse |
| **events_raw** | ✅ 100% | Directo |
| **sessions_raw** | ✅ 100% | Directo |
| **agent_sessions_raw** | ✅ 100% | Directo |
| **contractor_info_raw** | ✅ 100% | JOIN con Client/Team |
| **Tablas ADT** | ⚠️ 70% | Requiere adaptaciones |
| **contractor_activity_15s** | ⚠️ Parcial | Aproximaciones o modificar agente |
| **contractor_daily_metrics** | ✅ 100% | Depende de activity_15s |
| **app_usage_summary** | ✅ 90% | Usar AppUsage dict |
| **session_summary** | ✅ 100% | Agregaciones |
| **ETL Pipelines** | ✅ 100% | Implementar consumers NATS → ClickHouse |
| **Productivity Score** | ⚠️ 60% | Simplificado en Fase 1, completo en Fase 2 |
| **Arquitectura** | ✅ 100% | NATS ya existe, agregar ClickHouse |

---

## 🎯 Recomendación Final

**✅ La propuesta ES VIABLE**, pero recomiendo:

1. **Implementar Fase 1 inmediatamente** con aproximaciones basadas en `IdleTime` y `AppUsage`
2. **Modificar el agente en Fase 2** para capturar métricas incrementales reales
3. **Migrar gradualmente** de aproximaciones a datos reales

**Beneficios de Fase 1:**
- Dashboard funcional inmediatamente
- Productividad calculable (aunque simplificada)
- Identificar gaps de datos antes de modificar agente

**Beneficios de Fase 2:**
- Precisión mejorada
- Métricas adicionales (mouse_distance, active_window)
- Productivity score más robusto

---

## 📝 Próximos Pasos

1. ✅ Validar este análisis con el equipo
2. ✅ Decidir si implementar Fase 1 con aproximaciones o esperar Fase 2
3. ✅ Diseñar arquitectura ETL (NATS → ClickHouse)
4. ✅ Crear scripts de migración de datos históricos
5. ✅ Definir calendario de implementación

