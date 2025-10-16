# ClickHouse para Producción - Coolify Ready

Configuración optimizada de ClickHouse para despliegue en Coolify y análisis de datos.

## 🚀 Despliegue

### Coolify

1. Crear nuevo proyecto en Coolify
2. Conectar este repositorio
3. Coolify detectará automáticamente el `docker-compose.yaml`
4. Configurar variables de entorno (opcional)
5. Deploy automático

### Docker Compose Local

```bash
# Iniciar ClickHouse
docker compose up -d

# Verificar estado
docker compose ps

# Ver logs
docker compose logs -f clickhouse
```

## 📊 Información de Conexión

- **HTTP Interface**: `http://localhost:8123`
- **TCP Port**: `9000`
- **Web UI**: `http://localhost:8123/play`

### Credenciales por Defecto

| Usuario | Contraseña | Uso                     |
| ------- | ---------- | ----------------------- |
| `admin` | `admin123` | Administración completa |

## 🗄️ Base de Datos

- **Base de datos principal**: `andes_db`
- **Auto-inicialización**: Se crean tablas y datos de ejemplo automáticamente

### Tablas Incluidas

- `event_logs` - Eventos y logs de aplicaciones
- `performance_metrics` - Métricas de rendimiento del sistema
- `user_activity` - Actividad y comportamiento de usuarios
- `daily_summary` - Vista materializada con resúmenes diarios

## ⚙️ Variables de Entorno

Configura estas variables en Coolify o tu archivo `.env`:

```env
CLICKHOUSE_DB=andes_db
CLICKHOUSE_USER=admin
CLICKHOUSE_PASSWORD=SecurePassword123!
```

## 🔧 Comandos Útiles

### Conexión y Consultas

```bash
# Conectar con cliente
docker exec -it clickhouse-server clickhouse-client --user admin --password admin123

# Consulta HTTP directa
curl -u admin:admin123 "http://localhost:8123/?query=SELECT%20version()"

# Health check
curl http://localhost:8123/ping
```

### Consultas de Ejemplo

```sql
-- Cambiar a la base de datos
USE andes_db;

-- Ver todas las tablas
SHOW TABLES;

-- Consultar eventos
SELECT event_type, count() as total FROM event_logs GROUP BY event_type;

-- Ver métricas de rendimiento
SELECT service_name, avg(metric_value) FROM performance_metrics GROUP BY service_name;
```

## 🌐 API HTTP

ClickHouse expone una API HTTP completa:

```bash
# Consulta simple
curl "http://localhost:8123/?query=SELECT%20count()%20FROM%20andes_db.event_logs"

# Con autenticación
curl -u admin:admin123 "http://localhost:8123/?query=SELECT%20*%20FROM%20andes_db.event_logs%20LIMIT%205"

# Insertar datos JSON
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"id": 999, "event_type": "api_test", "user_id": 1}' \
     "http://localhost:8123/?query=INSERT%20INTO%20andes_db.event_logs%20FORMAT%20JSONEachRow"
```

## 📁 Estructura del Proyecto

```
clickhouse/
├── docker-compose.yaml    # Configuración principal
├── .env                  # Variables de entorno (opcional)
├── init/
│   └── 01-init-database.sql  # Script de inicialización automática
├── .gitignore
└── README.md
```

## 🔒 Seguridad para Producción

1. **Cambiar contraseñas**: Actualiza `CLICKHOUSE_PASSWORD` en variables de entorno
2. **Restringir acceso**: Configura firewall para limitar acceso a puertos
3. **SSL/TLS**: Habilita HTTPS en entornos de producción
4. **Backup**: Configura backups automáticos de los volúmenes

## 📈 Monitoreo

### Health Check

```bash
curl http://localhost:8123/ping
# Respuesta: Ok.
```

### Métricas del Sistema

```sql
-- Uso de disco por base de datos
SELECT
    database,
    formatReadableSize(sum(bytes_on_disk)) as size
FROM system.parts
GROUP BY database;

-- Estado de tablas
SELECT
    table,
    sum(rows) as total_rows,
    formatReadableSize(sum(bytes_on_disk)) as size_on_disk
FROM system.parts
WHERE database = 'andes_db'
GROUP BY table;
```

## 🐛 Troubleshooting

### Verificar Estado

```bash
# Estado de contenedores
docker compose ps

# Logs del servicio
docker compose logs clickhouse

# Conectividad
curl http://localhost:8123/ping
```

### Problemas Comunes

1. **Puerto ocupado**: Verificar que 8123 y 9000 estén libres
2. **Permisos**: Asegurar que Docker tenga permisos de volúmenes
3. **Memoria**: ClickHouse necesita al menos 1GB de RAM libre

## 🔄 Backup y Restauración

### Backup Manual

```bash
# Exportar datos
docker exec clickhouse-server clickhouse-client --query "SELECT * FROM andes_db.event_logs" > backup_events.csv

# Backup completo (requiere configuración adicional)
docker exec clickhouse-server clickhouse-backup create
```

---

**✅ ClickHouse listo para recibir datos del microservicio de analytics via NATS!**

Para conectar desde tu microservicio NestJS, usa:

- **Host**: `http://clickhouse-server:8123` (interno) o `http://localhost:8123` (externo)
- **Usuario**: `admin`
- **Contraseña**: `admin123`
- **Base de datos**: `andes_db`
