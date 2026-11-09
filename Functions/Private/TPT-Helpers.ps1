# TPT-Helpers.ps1
# Helpers privados compartidos del modulo TPT (sin exportar).
#
#   Convert-tptYamlToPSCustomObject : parseador YAML sin dependencias
#                                     (no usa ConvertFrom-Yaml).

function Convert-tptYamlToPSCustomObject {
    <#
    .SYNOPSIS
        Parsea el fichero YAML de configuracion TPT (estructura fija) a un objeto de PowerShell.

    .DESCRIPTION
        Funcion privada, sin dependencias (no usa ConvertFrom-Yaml, que no esta disponible).
        Soporta la estructura concreta de ~/.tpt/tpt_config.yaml:
          - Una seccion raiz 'platforms:'.
          - Secciones por modulo (identacion de 2 espacios, terminadas en ':').
          - Cada seccion, una lista de plataformas: marcadores '- ' (identacion 4) que inician
            un objeto, con la primera 'clave: valor' en la misma linea.
          - Propiedades del objeto con identacion de 6 espacios ('clave: valor').
          - Valores escalares (string, int, bool) y arrays inline [a, b, c].
        Retorna un PSCustomObject con la propiedad 'platforms' (hashtable modulo -> array de
        PSCustomObject, con valores tipados).

    .PARAMETER ConfigPath
        Ruta al fichero YAML. Por defecto, ~/.tpt/tpt_config.yaml.

    .OUTPUTS
        PSCustomObject.

    .EXAMPLE
        Convert-tptYamlToPSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0)]
        [string]$ConfigPath = '~/.tpt/tpt_config.yaml'
    )

    $resolved = $ConfigPath -replace '^~', ([Environment]::GetEnvironmentVariable('HOME'))
    if (-not (Test-Path -LiteralPath $resolved)) {
        throw "Fichero de configuracion no encontrado: $ConfigPath"
    }

    $raw = Get-Content -LiteralPath $resolved -Raw -ErrorAction Stop
    if ($null -eq $raw) { $raw = '' }
    $lines = @($raw -split '\r?\n')

    $result = [PSCustomObject]@{ platforms = [PSCustomObject]@{} }
    $currentModule = $null
    $currentPlatform = $null
    $platformsByModule = @{}

    foreach ($line in $lines) {
        if (-not $line -or $line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }

        $indent = $line.Length - $line.TrimStart().Length
        $content = $line.Trim()

        if ($content -eq 'platforms:') {
            $currentModule = $null
            continue
        }

        # Seccion por modulo: indentacion 2, 'nombre:'
        if ($indent -eq 2 -and $content -match '^([A-Za-z0-9_-]+):$') {
            if ($null -ne $currentPlatform) {
                $platformsByModule[$currentModule] += $currentPlatform
                $currentPlatform = $null
            }
            $currentModule = $matches[1]
            if (-not $platformsByModule.ContainsKey($currentModule)) {
                $platformsByModule[$currentModule] = @()
            }
            continue
        }

        if (-not $currentModule) { continue }

        # Nuevo objeto de plataforma: indentacion 4, '- clave: valor'
        if ($indent -eq 4 -and $content.StartsWith('- ')) {
            if ($null -ne $currentPlatform) {
                $platformsByModule[$currentModule] += $currentPlatform
            }
            $currentPlatform = [PSCustomObject]@{}
            $inner = $content.Substring(2).Trim()
            if ($inner -match '^([A-Za-z0-9_-]+)\s*:\s*(.*)$') {
                $currentPlatform | Add-Member -NotePropertyName $matches[1] -NotePropertyValue $matches[2].Trim()
            }
            continue
        }

        # Propiedad del objeto: indentacion 6, 'clave: valor'
        if ($indent -eq 6 -and $content -match '^([A-Za-z0-9_-]+)\s*:\s*(.*)$' -and $null -ne $currentPlatform) {
            $currentPlatform | Add-Member -NotePropertyName $matches[1] -NotePropertyValue $matches[2].Trim() -Force
        }
    }

    if ($null -ne $currentPlatform) {
        $platformsByModule[$currentModule] += $currentPlatform
    }

    # Tipado de valores (int, bool, array inline) en todas las plataformas
    foreach ($mod in $platformsByModule.Keys) {
        foreach ($p in $platformsByModule[$mod]) {
            foreach ($prop in $p.PSObject.Properties.Name) {
                $raw = "$($p.$prop)"
                if ($raw -match '^\[(.*)\]$') {
                    $inner = $matches[1].Trim()
                    if ($inner -eq '') {
                        $p.$prop = @()
                    } else {
                        $items = @($inner.Split(',') | ForEach-Object { $_.Trim().Trim([char]39, [char]34) } | Where-Object { $_ -ne '' })
                        $p.$prop = $items
                    }
                }
                elseif ($raw -match '^-?[0-9]+$') {
                    $p.$prop = [int]$raw
                }
                elseif ($raw -eq 'true') {
                    $p.$prop = $true
                }
                elseif ($raw -eq 'false') {
                    $p.$prop = $false
                }
            }
        }
        $result.platforms | Add-Member -NotePropertyName $mod -NotePropertyValue $platformsByModule[$mod] -Force
    }

    $result
}
