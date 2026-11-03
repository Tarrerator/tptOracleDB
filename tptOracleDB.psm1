# tptOracleDB.psm1
# Cargador del módulo. Importa funciones públicas y privadas.

$moduleRoot = $PSScriptRoot

# Estado compartido del módulo (ámbito de script): último servidor conectado.
# Las funciones públicas lo leen/escriben para que el usuario no repita -Server.
$script:DefaultServer = $null

# --- Funciones privadas -------------------------------------------------------
$privateDir = Join-Path -Path $moduleRoot -ChildPath 'Functions/Private'
if (Test-Path $privateDir) {
    Get-ChildItem -Path $privateDir -Filter '*.ps1' -File | ForEach-Object {
        . $_.FullName
    }
}

# --- Funciones públicas -------------------------------------------------------
$publicDir = Join-Path -Path $moduleRoot -ChildPath 'Functions/Public'
if (Test-Path $publicDir) {
    Get-ChildItem -Path $publicDir -Filter '*.ps1' -File | ForEach-Object {
        . $_.FullName
    }
}

# No re-exportar: el manifiesto define FunctionsToExport.