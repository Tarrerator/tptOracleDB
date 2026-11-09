# Using Windows-1252
function Connect-tptOracleDB {
    <#
    .SYNOPSIS
        Establece una conexión con Oracle Database usando sqlplus e invoca una consulta simple de inventario.

    .DESCRIPTION
        Función pública. Conecta a Oracle usando las credenciales y parámetros de conexión
        proporcionados, ejecuta una consulta de diagnóstico y devuelve los resultados. Requiere
        sqlplus (Oracle Instant Client o instalación completa de Oracle). Acepta -Platform
        para resolver la conexión desde la configuración centralizada.

    .PARAMETER Server
        Servidor o nombre de servicio/tnsalias (default: localhost). Si no se proporciona y se usa
        -Platform, se toma del YAML.

    .PARAMETER Port
        Puerto TCP (default: 1521). Si no se proporciona y se usa -Platform, se toma del YAML.

    .PARAMETER ServiceName
        Nombre de servicio Oracle. Si no se proporciona, construir SID como "server:port" si hay puerto,
        o solo el alias.

    .PARAMETER Credential
        Credenciales validadas de usuario Oracle (usuario y password). Requerido.

    .PARAMETER Platform
        Nombre de la plataforma desde la configuración centralizada (YAML).
        Si se proporciona, los valores de Server y Port se toman del YAML a menos que se proporcionen
        explícitamente.

    .EXAMPLE
        Connect-tptOracleDB -Server myoracle.example.com -Credential (Get-Credential)
        Conecta a Oracle con usuario/password, puerto 1521 y servidor por defecto.

    .EXAMPLE
        Connect-tptOracleDB -Credential (Get-Credential) -Platform oracle-prod
        Resuelve la plataforma oracle-prod desde el YAML centralizado.

    .EXAMPLE
        Connect-tptOracleDB -Platform oracle-prod -Credential (Get-Credential) -Port 1521
        Combina plataforma YAML y override explícito de puerto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Server, Port, ServiceName, User, Version, Connected.
    #>
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Platform = $null,

        [string]$Server = $null,

        [int]$Port = 1521,

        [string]$ServiceName = $null,

        [ValidateNotNull()][PSCredential]$Credential = $null
    )

    Import-Module (Join-Path $PSScriptRoot -ChildPath 'TPT-Helpers.ps1') -Force

    # Resolver parámetros desde YAML si -Platform está presente
    if ($Platform) {
        $config = Get-tptOracleDBConfig
        $selectedPlatform = $config | Where-Object { $_.name -eq $Platform }
        
        if (-not $selectedPlatform) {
            throw "Plataforma '$Platform' no encontrada en la configuración de tptOracleDB."
        }

        # Usar valores del YAML solo si los parámetros no fueron proporcionados explícitamente
        if (-not $Server) { $Server = $selectedPlatform.server }
        if ($Port -eq 1521 -and $selectedPlatform.port) { $Port = $selectedPlatform.port }
    }

    # Validar que Server está presente
    if (-not $Server) {
        throw "Se requiere -Server (o -Platform para resolver desde YAML)."
    }

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