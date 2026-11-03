# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).

## [0.0.1] - 2026-11-03

### Añadido
- Esqueleto del módulo: manifiesto, cargador y estructura Public/Private.
- Connect-tptOracleDB: validación de conexión a Oracle vía sqlplus.
- Get-tptOracleDBTablespaces: inventario de tablespaces (requiere DBA).
- Get-tptOracleDBUsers: inventario de usuarios (requiere DBA).
- Get-tptOracleDBSessions: inventario de sesiones activas.
- Get-tptOracleDBTables: inventario de tablas con filtrado por propietario.
- Get-tptOracleDBStatus: estado de instancia Oracle.

### Planificado
- Get-tptOracleDBIndexes
- Get-tptOracleDBJobs
- Get-tptOracleDBDataFiles
- Get-tptOracleDBSequence
- New-tptOracleDBUser
- Remove-tptOracleDBUser
- Set-tptOracleDBUserPassword
- New-tptOracleDBTablespace
- Invoke-tptOracleDBStats
- Invoke-tptOracleDBShrink
- Get-tptOracleDBWaitEvents
- Test-tptOracleDBHealth
- Testes Pester
- CI