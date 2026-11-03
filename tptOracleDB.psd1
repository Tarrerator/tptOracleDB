@{
    # Identidad del módulo
    RootModule           = 'tptOracleDB.psm1'
    ModuleVersion        = '0.0.1'
    GUID                 = 'f3e5b2b7-8d4c-4a6b-9f1e-2d7c3b5a9e8d'
    Author               = 'Tarrerator'
    CompanyName          = 'Tarrerator'
    Copyright            = '(c) 2026 Tarrerator'

    # Descripción
    Description          = 'Módulo PowerShell que envuelve sqlplus para conectar y consultar Oracle Database: inventario, estado y operaciones. Parte de la suite *tarre pwsh tools* (TPT): prefijo `tpt` en módulos y funciones para evitar colisiones.'

    # Compatibilidad
    PowerShellVersion    = '7.2'
    CompatiblePSEditions = @('Desktop', 'Core')

    # Exporta funciones explícitamente: nada de comodines
    FunctionsToExport    = @(
        'Connect-tptOracleDB'
        'Get-tptOracleDBTablespaces'
        'Get-tptOracleDBUsers'
        'Get-tptOracleDBSessions'
        'Get-tptOracleDBTables'
        'Get-tptOracleDBStatus'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('Oracle', 'sqlplus', 'Database', 'Inventory', 'DBA')
            ProjectUri   = 'https://github.com/Tarrerator/tptOracleDB'
            ReleaseNotes = 'Esqueleto del módulo: manifiesto, cargador y estructura Public/Private.'
            # LicenseUri = ''
            # IconUri    = ''
            # ReleaseNotes file: CHANGELOG.md
        }
    }
}