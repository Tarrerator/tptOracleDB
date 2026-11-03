# tptOracleDB

## Descripción

Módulo PowerShell que envuelve sqlplus para conectar y consultar Oracle Database: inventario, estado y operaciones. Parte de la suite *tarre pwsh tools* (TPT): prefijo `tpt` en módulos y funciones para evitar colisiones.

## Funciones

| Función | Descripción |
|---------|-------------|
| `Connect-tptOracleDB` | Establece conexión con Oracle Database y devuelve información de conexión. |
| `Get-tptOracleDBTablespaces` | Obtiene inventario de tablespaces (requiere privilegios DBA). |
| `Get-tptOracleDBUsers` | Obtiene inventario de usuarios (requiere privilegios DBA). |
| `Get-tptOracleDBSessions` | Obtiene inventario de sesiones activas. |
| `Get-tptOracleDBTables` | Obtiene inventario de tablas con filtrado opcional por propietario. |
| `Get-tptOracleDBStatus` | Obtiene estado de instancia de Oracle. |

## Requisitos

- **sqlplus**: Oracle Instant Client o instalación completa de Oracle. Debe estar en PATH.
- **Privilegios DBA**: Requeridos para consultas que acceden a vistas DBA_* (tablespaces, usuarios, sesiones, tablas, estado).
- **PowerShell 7.2+**: Compatible con Desktop y Core editions.

## Ejemplo de Uso

```powershell
# Conectar a Oracle
$cred = Get-Credential
Connect-tptOracleDB -Server myoracle.example.com -Credential $cred

# Obtener inventario de tablespaces
Get-tptOracleDBTablespaces -Server myoracle.example.com -Credential $cred

# Obtener inventario de usuarios
Get-tptOracleDBUsers -Server myoracle.example.com -Credential $cred

# Obtener inventario de sesiones
Get-tptOracleDBSessions -Server myoracle.example.com -Credential $cred

# Obtener inventario de tablas para propietario específico
Get-tptOracleDBTables -Server myoracle.example.com -Credential $cred -Owner 'SCOTT'

# Obtener estado de instancia
Get-tptOracleDBStatus -Server myoracle.example.com -Credential $cred
```

## Configuración Futura

Se planea añadir configuración manual en `~/.tpt/tptOracleDB.yaml` para conexión persistente y parámetros por defecto. No programática inicialmente.

## Licencia

GPL-3.0