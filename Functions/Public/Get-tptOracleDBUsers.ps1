# Using Windows-1252
function Get-tptOracleDBUsers {
    <#
    .SYNOPSIS
        Obtiene el inventario de usuarios de Oracle Database.

    .DESCRIPTION
        Función pública. Consulta la vista DBA_USERS para obtener información de cada usuario:
        nombre, estado de cuenta, fecha de expiración y perfil asignado. Requiere privilegios DBA.

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
        Get-tptOracleDBUsers -Server myoracle.example.com -Credential (Get-Credential)
        Devuelve el inventario de usuarios usando el servidor por defecto.

    .OUTPUTS
        System.Management.Automation.PSObject con propiedades:
        Name, AccountStatus, ExpiryDate, Profile.
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
            "SELECT username || '|' || account_status || '|' || to_char(expiry_date,'YYYY-MM-DD HH24:MI:SS') || '|' || profile FROM dba_users ORDER BY username;"
        )
        [System.IO.File]::WriteAllLines($scriptFile, $scriptContent, [System.Text.Encoding]::GetEncoding("iso-8859-1"))

        $result = sqlplus -s "$finalConnectString" "@$scriptFile"

        if ($LASTEXITCODE -ne 0) {
            throw "sqlplus falló con código de salida $LASTEXITCODE. Salida: $result"
        }

        $users = @()
        $lines = $result -split "\r?\n" | Where-Object { $_ -and $_ -match "^[^|]+\|[^|]+\|[^|]+\|[^|]+$" }

        foreach ($line in $lines) {
            $parts = $line -split "\|"
            if ($parts.Count -ge 4) {
                [PSCustomObject] @{
                    Name = $parts[0]
                    AccountStatus = $parts[1]
                    ExpiryDate = $parts[2]
                    Profile = $parts[3]
                }
            }
        }

        $users
    } finally {
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
    }
}