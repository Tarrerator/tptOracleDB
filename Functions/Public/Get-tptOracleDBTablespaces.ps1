# Using Windows-1252
function Get-tptOracleDBTablespaces {
    <#
    .SYNOPSIS
        Obtiene el inventario de tablespaces de Oracle Database.

    .DESCRIPTION
        Función pública. Consulta vistas DBA_DATA_FILES y DBA_FREE_SPACE para obtener
        métricas de tamaño y uso de cada tablespace. Requiere privilegios DBA.

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
        Get-tptOracleDBTablespaces -Server myoracle.example.com -Credential (Get-Credential)
        Devuelve el inventario de tablespaces usando el servidor por defecto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Name, SizeGB, FreeGB, UsagePercent, Contents.
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
            "SELECT a.tablespace_name || '|' || ROUND(a.bytes/1024/1024,2) || '|' || ROUND(nvl(f.free_bytes,0)/1024/1024,2) || '|' || ROUND(((a.bytes - nvl(f.free_bytes,0))/a.bytes)*100,1) || '|' || a.contents FROM dba_data_files a LEFT JOIN (SELECT tablespace_name, SUM(bytes) free_bytes FROM dba_free_space GROUP BY tablespace_name) f ON a.tablespace_name = f.tablespace_name GROUP BY a.tablespace_name, a.contents, a.bytes, f.free_bytes ORDER BY a.tablespace_name;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        $tablespaces = @()
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -match "^[^|]+\|[^|]+\|[^|]+\|[^|]+\|[^|]+$" }

        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 5) {
                [PSCustomObject] @{
                    Name = $parts[0]
                    SizeGB = [math]::Round([decimal]($parts[1] / 1024), 2)
                    FreeGB = [math]::Round([decimal]($parts[2] / 1024), 2)
                    UsagePercent = [decimal]($parts[3])
                    Contents = $parts[4]
                }
            }
        }

        $tablespaces
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}