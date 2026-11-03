# Using Windows-1252
function Get-tptOracleDBStatus {
    <#
    .SYNOPSIS
        Obtiene el estado de conexión de Oracle Database.

    .DESCRIPTION
        Función pública. Consulta v\$INSTANCE para obtener estado y versión:
        devuelve el estado de instancia, versión, servidor, puerto y servicio.

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
        Get-tptOracleDBStatus -Server myoracle.example.com -Credential (Get-Credential)
        Devuelve el estado usando el servidor por defecto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Server, Port, ServiceName, Status, Version.
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
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
            "SELECT 'UP' || '|' || version FROM v\$instance WHERE rownum = 1;"
            "SELECT status FROM v\$instance WHERE rownum = 1;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        $status = $null
        $version = $null
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -match "^[^|]+\|[^|]+$" }

        if ($lines.Count -ge 1) {
            $parts = $lines[0] -split "\|"
            if ($parts.Count -ge 2) {
                $status = $parts[0]
                $version = $parts[1]
            }
        }

        [PSCustomObject] @{
            Server = $Server
            Port = $Port
            ServiceName = $ServiceName
            Status = $status
            Version = $version
        }
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}