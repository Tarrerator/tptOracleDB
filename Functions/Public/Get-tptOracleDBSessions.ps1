# Using Windows-1252
function Get-tptOracleDBSessions {
    <#
    .SYNOPSIS
        Obtiene el inventario de sesiones activas de Oracle Database.

    .DESCRIPTION
        Función pública. Consulta la vista V\$SESSION para obtener sesiones activas:
        usuario, máquina, programa, estado, tiempo de conexión e ID de SQL. Solo sesiones con usuario no nulo.

    .PARAMETER Server
        Servidor o nombre de servicio/tnsalias (default: localhost).

    .PARAMETER Port
        Puerto TCP (default: 1521).

    .PARAMETER ServiceName
        Nombre de servicio Oracle. Si no se proporciona, construir SID como "server:port" si hay puerto,
        o solo el alias.

    .PARAMETER Credential
        Credenciales validadas de usuario Oracle (usuario y password). Requerido.

    .EXAMPLE
        Get-tptOracleDBSessions -Server myoracle.example.com -Credential (Get-Credential)
        Devuelve las sesiones activas usando el servidor por defecto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        User, Machine, Program, Status, LogonTime, SqlId.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [string]$Server = $null,

        [int]$Port = 1521,

        [string]$ServiceName = $null,

        [ValidateNotNull()][PSCredential]$Credential = $null
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
        $scriptContent = @(
            "SET DEFINE OFF"
            "SET HEADING OFF"
            "SET FEEDBACK OFF"
            "SET PAGESIZE 0"
            "SET LINESIZE 32767"
            "SELECT username || '|' || machine || '|' || program || '|' || status || '|' || to_char(logon_time,'YYYY-MM-DD HH24:MI:SS') || '|' || sql_id FROM v\$session WHERE username IS NOT NULL ORDER BY logon_time DESC;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        $sessions = @()
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -match "^[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+$" }

        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 6) {
                [PSCustomObject] @{
                    User = $parts[0]
                    Machine = $parts[1]
                    Program = $parts[2]
                    Status = $parts[3]
                    LogonTime = $parts[4]
                    SqlId = $parts[5]
                }
            }
        }

        $sessions
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}