# TPT-Helpers.ps1
# Helper functions shared across all TPT modules for consistent behavior.

function Convert-tptYamlToPSCustomObject {
    <#
    .SYNOPSIS
        Parsea el YAML de configuración centralizada en un PSCustomObject.

    .DESCRIPTION
        Función privada. Parsea el fichero YAML centralizado en ~/.tpt/tpt_config.yaml
        usando un parser YAML simple y determinista. Soporta la estructura específica:
        plataformas -> {módulo} -> [plataforma1, plataforma2, ...] donde cada plataforma
        es un mapa con claves escalares (string, int, bool) y arrays inline.
        No soporta YAML multi-línea o complejo.

    .PARAMETER ConfigPath
        Ruta al fichero YAML (por defecto: ~/.tpt/tpt_config.yaml).

    .OUTPUTS
        [PSCustomObject] Con el contenido YAML parseado.

    .EXAMPLE
        Convert-tptYamlToPSCustomObject
        Parsea el fichero YAML centralizado predeterminado.

    .EXAMPLE
        Convert-tptYamlToPSCustomObject -ConfigPath '/custom/path.yaml'
        Parsea un fichero YAML personalizado.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = '~/.tpt/tpt_config.yaml'
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Fichero de configuración YAML no encontrado: $ConfigPath"
    }

    try {
        $yamlContent = Get-Content -Path $ConfigPath -Raw
        
        $yamlData = @{}
        $yamlData.platforms = [PSCustomObject]@{}
        
        $sections = $yamlContent -split '^([a-zA-Z_-]+):$'
        
        for ($i = 1; $i -lt $sections.Count; $i += 2) {
            $sectionName = $sections[$i]
            $sectionContent = $sections[$i + 1]
            
            $sectionData = @()
            $currentObject = $null
            $sectionLines = $sectionContent -split '`r?`n'
            
            for ($j = 0; $j -lt $sectionLines.Count; $j++) {
                $line = $sectionLines[$j].Trim()
                if (-not $line) { continue }
                
                if ($line.StartsWith('-')) {
                    if ($currentObject) {
                        $sectionData.Add($currentObject)
                    }
                    $currentObject = [PSCustomObject]@{}
                } elseif ($line -match '^([a-zA-Z_-]+):\s*(.+)$') {
                    $key = $matches[1]
                    $value = $matches[2].Trim()
                    
                    if (($value.StartsWith("\'") -and $value.EndsWith("\'") -or ($value.StartsWith('"') -and $value.EndsWith('"')))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    
                    if ($value -match '^[0-9]+$') {
                        $value = $value -as [int]
                    } elseif ($value -match '^(true|false)$' -i) {
                        if ($value -eq 'true' -i) {
                            $value = $true
                        } else {
                            $value = $false
                        }
                    }
                    
                    if ($currentObject) {
                        $currentObject.$key = $value
                    }
                } elseif ($line -match '^([a-zA-Z_-]+):\s*\[(.*)\]$') {
                    $key = $matches[1]
                    $arrayContent = $matches[2]
                    
                    if ($arrayContent.Trim() -eq '') {
                        $parsedArray = @()
                    } else {
                        $parsedArray = @($arrayContent -split ',') | ForEach-Object { $_.Trim().Trim('\'', '"') }
                    }
                    
                    if ($currentObject) {
                        $currentObject.$key = $parsedArray
                    }
                }
            }
            
            if ($currentObject) {
                $sectionData.Add($currentObject)
            }
            
            $yamlData.platforms.$sectionName = $sectionData
        }
        
        $yamlData
    } catch {
        throw "No se pudo parsear el fichero YAML $ConfigPath. Error: $($_.Exception.Message)"
    }
}