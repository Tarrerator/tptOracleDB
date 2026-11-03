# Using Windows-1252
function Test-tptOracleDBCommand {
    <#
    .SYNOPSIS
        Verifica que sqlplus está disponible en el PATH.

    .DESCRIPTION
        Función privada. Si sqlplus no está disponible, lanza un error con
        instrucciones de instalación. Devuelve el path absoluto de sqlplus.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $sqlplus = Get-Command -Name 'sqlplus' -ErrorAction SilentlyContinue

    if (-not $sqlplus) {
        throw 'sqlplus no está disponible. Requiere Oracle Instant Client o una instalación completa de Oracle. Documentación: https://www.oracle.com/database/technologies/instant-client.html'
    }

    $sqlplus.Path
}