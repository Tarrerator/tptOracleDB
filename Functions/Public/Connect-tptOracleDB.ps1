# Using Windows-1252
function Connect-tptOracleDB {
    <#
    .SYNOPSIS
        Establece una conexión con Oracle Database usando sqlplus e invoca una consulta simple de inventario.

    .DESCRIPTION
        Función pública. Conecta a Oracle usando las credenciales y parámetros de conexión
        proporcionados, ejecuta una consulta de diagnóstico y devuelve los resultados. Requiere
        sqlplus (Oracle Instant Client o instalación completa de Oracle).

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
        Connect-tptOracleDB -Server myoracle.example.com -Credential (Get-Credential)
        Conecta a Oracle con usuario/password, puerto 1521 y servidor por defecto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Server, Port, ServiceName, User, Version, Connected.
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [string]$Server = $null,

        [int]$Port = 1521,

        [string]$ServiceName = $null,

        [ValidateNotNull()][PSCredential]$Credential = $null
    )

    Test-tptOracleDBCommand

    if (-not $Credential) {
        throw 'Se requiere -Credential.'
    }

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
        # Escribir script SQL con configuraciones de formateo
        $scriptContent = @(
            "SET DEFINE OFF"
            "SET HEADING OFF"
            "SET FEEDBACK OFF"
            "SET PAGESIZE 0"
            "SET LINESIZE 32767"
            "SELECT 'CONNECTED' || '|' || version FROM v\$version WHERE rownum = 1;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        # Ejecutar sqlplus
        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        # Parsear salida
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -notmatch "^SQL\+\/\|^SQL\+.*CONECTADO$" }
        if ($lines.Count -gt 0) {
            $line = $lines[0].Trim()
            if ($line -match "^(?<version>.+)$") {
                $version = $matches['version'].Trim()
            } else {
                $version = $line
            }
        } else {
            throw "No se pudo parsear la salida de sqlplus: $result"
        }

        [PSCustomObject] @{
            Server = $Server
            Port = $Port
            ServiceName = $ServiceName
            User = $user
            Version = $version
            Connected = $true
        }
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}