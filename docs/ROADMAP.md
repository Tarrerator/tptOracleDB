# ROADMAP.md

1. **Conexión**
   - [x] Connect-tptOracleDB: validación de conexión a Oracle vía sqlplus.
   - [ ] Configuración manual: `~/.tpt/tptOracleDB.yaml` (documentada, no programática).

2. **Inventario**
   - [x] Get-tptOracleDBTablespaces: inventario de tablespaces (requiere DBA).
   - [x] Get-tptOracleDBUsers: inventario de usuarios (requiere DBA).
   - [x] Get-tptOracleDBSessions: inventario de sesiones activas.
   - [x] Get-tptOracleDBTables: inventario de tablas con filtrado por propietario.
   - [ ] Get-tptOracleDBIndexes: inventario de índices.
   - [ ] Get-tptOracleDBJobs: inventario de trabajos programados (DBA_SCHEDULER_JOBS).
   - [ ] Get-tptOracleDBDataFiles: inventario de archivos de datos.
   - [ ] Get-tptOracleDBSequence: inventario de secuencias.

3. **Administración**
   - [ ] New-tptOracleDBUser: creación de nuevo usuario.
   - [ ] Remove-tptOracleDBUser: eliminación de usuario.
   - [ ] Set-tptOracleDBUserPassword: cambio de contraseña de usuario.
   - [ ] New-tptOracleDBTablespace: creación de nuevo tablespace.

4. **Mantenimiento**
   - [ ] Invoke-tptOracleDBStats: recolección de estadísticas (DBMS_STATS.gather_*).
   - [ ] Invoke-tptOracleDBShrink: Shrink de tablespaces.

5. **Observabilidad**
   - [ ] Get-tptOracleDBWaitEvents: inventario de eventos de espera.
   - [ ] Test-tptOracleDBHealth: test de salud del sistema.

6. **Calidad**
   - [ ] Testes Pester: suite de pruebas unitarias.
   - [ ] CI: integración continua para pruebas automatizadas.