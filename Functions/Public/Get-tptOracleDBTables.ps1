# Using Windows-1252
function Get-tptOracleDBTables {
    <#
    .SYNOPSIS
        Obtiene el inventario de tablas de Oracle Database.

    .DESCRIPTION
        Función pública. Consulta la vista DBA_TABLES para obtener información de cada tabla:
        propietario, nombre, número de filas, tamaño en MB. Permite filtrar por propietarios
        (wildcard). Requiere privilegios DBA para acceder a DBA_TABLES.

    .PARAMETER Server
        Servidor o nombre de servicio/tnsalias (default: localhost).

    .PARAMETER Port
        Puerto TCP (default: 1521).

    .PARAMETER ServiceName
        Nombre de servicio Oracle. Si no se proporciona, construir SID como "server:port" si hay puerto,
        o solo el alias.

    .PARAMETER Credential
        Credenciales validadas de usuario Oracle (usuario y password). Requerido.

    .PARAMETER Owner
        Array opcional de propietarios a devolver (wildcard). Valores por defecto: @('SYS','SYSTEM').
        Si está vacío, devuelve todas las tablas.

    .EXAMPLE
        Get-tptOracleDBTables -Server myoracle.example.com -Credential (Get-Credential)
        Devuelve el inventario de tablas usando el servidor por defecto.

    .EXAMPLE
        Get-tptOracleDBTables -Owner 'SCOTT'
        Devuelve tablas del propietario SCOTT.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Owner, Name, RowCount, SizeMB.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [string]$Server = $null,

        [int]$Port = 1521,

        [string]$ServiceName = $null,

        [ValidateNotNull()][PSCredential]$Credential = $null,

        [string[]]$Owner = @('SYS','SYSTEM')
    )

    if (-not $Credential) {
        throw 'Se requiere -Credential.'
    }

    Test-tptOracleDBCommand

    # Resolución de la cadena de conexión
    $connectString = @()
    $user = $Credential.UserName
    $pass = $Credential.GetNetworkCredential().Password

    if ($ServiceName) {
        $connectString += "$user/$pass@//$Server`:$Port/$ServiceName"
    } elseif ($Port -ne 1521) {
        $connectString += "$user/$pass@//$Server`:$Port"
    } else {
        $connectString += "$user/$pass@$Server"
    }

    $finalConnectString = $connectString[0]

    $tempDir = [System.IO.Path]::GetTempPath()
    $scriptFile = [System.IO.Path]::Combine($tempDir, "tptOracleDB_$(Get-Random).sql")

    try {
        # Construir cláusula WHERE dinámica para propietarios
        $whereClause = @()
        if ($Owner.Count -gt 0) {
            $ownerConditions = @()
            foreach ($own in $Owner) {
                if ($own -match "[*?]" ) {
                    $ownerConditions += "owner LIKE '$own'"
                } else {
                    $ownerConditions += "owner = '$own'"
                }
            }
            $whereClause += "(" + ($ownerConditions -join " OR ") + ")"
        }

        $wherePart = if ($whereClause.Count -gt 0) { " WHERE " + ($whereClause -join " AND ") } else { "" }

        $scriptContent = @(
            "SET DEFINE OFF"
            "SET HEADING OFF"
            "SET FEEDBACK OFF"
            "SET PAGESIZE 0"
            "SET LINESIZE 32767"
            "SELECT owner || '|' || table_name || '|' || num_rows || '|' || ROUND((num_blocks*8192)/1024/1024,2) FROM dba_tables$wherePart ORDER BY owner, table_name;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        $tables = @()
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -match "^[^|]+\|[^|]+\|[^|]+\|[^|]+$" }

        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 4) {
                [PSCustomObject] @{
                    Owner = $parts[0]
                    Name = $parts[1]
                    RowCount = $parts[2]
                    SizeMB = [decimal]($parts[3])
                }
            }
        }

        $tables
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}