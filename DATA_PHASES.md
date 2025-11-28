Plan de implementación - ADT_MS

Fase 1: Configuración base ✅ COMPLETADA
Objetivo: Configurar la estructura base del microservicio.
Tareas realizadas:
- Crear carpeta config/ con variables de entorno
  - envs.ts - Variables de NATS y ClickHouse
  - logging.ts - Utilidades de logging
  - index.ts - Exportaciones centralizadas
- Instalar dependencias:
  - @clickhouse/client - Cliente ClickHouse
  - @nestjs/microservices - Soporte NATS
  - @nestjs/config - Configuración
  - nats, joi, dotenv, class-validator, class-transformer
- Configurar main.ts como microservicio NATS puro
- Crear filtro de excepciones RPC
Estado: ✅ Completada

Fase 2: Conexión a ClickHouse ✅ COMPLETADA
Objetivo: Establecer conexión con ClickHouse.
Tareas realizadas:
- Crear ClickHouseService:
  - Conexión automática al iniciar (onModuleInit)
  - Cierre de conexión al destruir (onModuleDestroy)
  - Métodos: query(), command(), insert(), tableExists()
  - Método ensureDatabase() para verificar/crear base de datos
  - Método ensureRawTables() para crear tablas RAW automáticamente
- Crear ClickHouseModule como módulo global
- Integrar en AppModule
- Verificar conexión con ping()
Estado: ✅ Completada

Fase 3: NATS Listeners ✅ COMPLETADA
Objetivo: Escuchar eventos de otros microservicios vía NATS.
Tareas realizadas:
- Crear estructura de listeners:
  - src/listeners/events.listener.ts - Escucha event.created de EVENTS_MS
  - src/listeners/sessions.listener.ts - Escucha session.created/updated de USER_MS
  - src/listeners/agent-sessions.listener.ts - Escucha agentSession.created/updated de USER_MS
  - src/listeners/contractors.listener.ts - Escucha contractor.created/updated de USER_MS
- Crear RawService para guardar datos en ClickHouse:
  - saveEvent() - Guarda en events_raw
  - saveSession() - Guarda en sessions_raw
  - saveAgentSession() - Guarda en agent_sessions_raw
  - saveContractor() - Guarda en contractor_info_raw
- Crear DTOs RAW:
  - EventRawDto, SessionRawDto, AgentSessionRawDto, ContractorRawDto
- Integrar listeners en AppModule
- Implementar @EventPattern() para cada tipo de evento
- USER_MS implementa interceptores para publicar eventos:
  - AdtSessionInterceptor - Publica session.created/updated
  - AdtAgentSessionInterceptor - Publica agentSession.created/updated
  - AdtContractorInterceptor - Publica contractor.created/updated
- EVENTS_MS publica event.created después de crear eventos
Estado: ✅ Completada

Fase 4: DTOs y servicios de transformación ETL ⏳ PENDIENTE
Objetivo: Crear DTOs y servicios para transformar RAW → ADT.
Tareas a realizar:
Crear DTOs para tablas ADT:

 
 
   src/etl/dto/
   ├── contractor-activity-15s.dto.ts
   ├── contractor-daily-metrics.dto.ts
   ├── app-usage-summary.dto.ts
   └── session-summary.dto.ts
 
 
 
Crear servicios de transformación:

 
 
   src/etl/transformers/
   ├── events-to-activity.transformer.ts      # events_raw → contractor_activity_15s
   ├── activity-to-daily-metrics.transformer.ts # contractor_activity_15s → contractor_daily_metrics
   ├── events-to-app-usage.transformer.ts     # events_raw → app_usage_summary
   └── activity-to-session-summary.transformer.ts # contractor_activity_15s → session_summary
 
 
 
- Lógica de transformación:
  - Extraer datos del payload JSON (usar JSONExtractString, JSONExtractFloat, etc.)
  - Calcular métricas agregadas (sumas, promedios, conteos)
  - Aplicar fórmulas de productividad (ver DATA_WAREHOUSE_ANALYSIS.md)
  - Generar DTOs listos para insertar en ClickHouse
- Consideraciones según DATA_WAREHOUSE_ANALYSIS.md:
  - Usar aproximaciones para keyboard_count y mouse_clicks (hasta modificar agente)
  - Inferir active_app desde AppUsage dict
  - mouse_distance = 0 hasta modificar agente
  - is_idle calculable desde IdleTime > threshold
Estado: ⏳ Pendiente

Fase 5: Creación de tablas RAW y ADT en ClickHouse ⚠️ PARCIALMENTE COMPLETADA
Objetivo: Definir y crear las tablas en ClickHouse.
Tareas realizadas:
- ✅ Tablas RAW creadas en CLICKHOUSE/init/01-init-database.sql:
  - events_raw - MergeTree, particionado por fecha, TTL 365 días
  - sessions_raw - MergeTree, particionado por fecha, TTL 365 días
  - agent_sessions_raw - MergeTree, particionado por fecha, TTL 365 días
  - contractor_info_raw - ReplacingMergeTree, TTL 730 días
- ✅ ClickHouseService.ensureRawTables() crea/verifica tablas RAW al iniciar
- ✅ Tablas RAW funcionando y recibiendo datos de los listeners
Tareas pendientes:
- ❌ Crear scripts SQL para tablas ADT:
  - contractor_activity_15s
  - contractor_daily_metrics
  - app_usage_summary
  - session_summary
- ❌ Crear Materialized Views para transformaciones automáticas (opcional)
- ❌ Agregar método ensureAdtTables() en ClickHouseService
Estado: ⚠️ Parcialmente completada (RAW ✅, ADT ❌)

Fase 6: Integración completa ⏳ PENDIENTE
Objetivo: Conectar listeners → transformadores → ClickHouse.
Tareas realizadas:
- ✅ Listeners guardan datos RAW inmediatamente al recibir eventos
- ✅ RawService maneja inserción en ClickHouse
- ✅ Manejo de errores no bloqueante (logs pero no interrumpe flujo)
Tareas pendientes:
- ❌ Conectar listeners con transformadores ETL:
  - Cuando llega evento → guardar RAW (✅ hecho) → transformar a ADT (❌ pendiente)
  - Procesar ADT en batch o tiempo real
- ❌ Implementar lógica de procesamiento ADT:
  - Trigger de transformación (tiempo real vs batch)
  - Agregación de datos para métricas diarias
  - Cálculo de productivity_score
- ❌ Mejorar logging y monitoreo:
  - Logs de eventos procesados (✅ básico implementado)
  - Métricas de rendimiento (❌ pendiente)
  - Alertas de errores (❌ pendiente)
- ❌ Implementar procesamiento batch para ADT:
  - Job scheduler para agregaciones diarias
  - Procesamiento de eventos acumulados
Estado: ⏳ Pendiente (RAW funcionando, ADT pendiente)

Fase 7: Optimización y testing ⏳ PENDIENTE
Objetivo: Optimizar y probar el sistema completo.
Tareas a realizar:
- Optimización:
  - ✅ Índices básicos en ClickHouse (ORDER BY en tablas RAW)
  - ❌ Índices adicionales según queries frecuentes
  - ❌ Batch processing para ADT
  - ❌ Caché si es necesario
- Testing:
  - ❌ Tests unitarios de transformadores
  - ❌ Tests de integración con ClickHouse
  - ❌ Tests de listeners NATS
  - ❌ Tests end-to-end del flujo completo
- Documentación:
  - ❌ README del microservicio
  - ❌ Documentación de DTOs
  - ❌ Guía de deployment
  - ❌ Diagramas de arquitectura
Estado: ⏳ Pendiente

---

## 📊 Resumen del Estado Actual

| Fase | Estado | Progreso |
|------|--------|----------|
| **Fase 1: Configuración base** | ✅ Completada | 100% |
| **Fase 2: Conexión ClickHouse** | ✅ Completada | 100% |
| **Fase 3: NATS Listeners** | ✅ Completada | 100% |
| **Fase 4: DTOs y ETL** | ⏳ Pendiente | 0% |
| **Fase 5: Tablas ClickHouse** | ⚠️ Parcial | 50% (RAW ✅, ADT ❌) |
| **Fase 6: Integración completa** | ⏳ Pendiente | 30% (RAW ✅, ADT ❌) |
| **Fase 7: Optimización y testing** | ⏳ Pendiente | 0% |

## 🎯 Próximos Pasos Recomendados

1. **Fase 4**: Crear DTOs y transformers para ADT (prioridad alta)
2. **Fase 5**: Completar creación de tablas ADT en ClickHouse
3. **Fase 6**: Integrar transformers con listeners para generar ADT
4. **Fase 7**: Testing y optimización

## 📝 Notas Importantes

- Las tablas RAW están funcionando y recibiendo datos en tiempo real
- Los interceptores en USER_MS publican eventos de forma no bloqueante
- EVENTS_MS publica event.created con el ID real del evento
- El sistema RAW está listo para producción
- Las tablas ADT requieren implementación de Fase 4 antes de crearlas