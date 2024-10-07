<#
.SYNOPSIS
    This script validates all JSON and JSONC files recursively
    under the Path parameter directory against their specified 
    JSON schemas.
.DESCRIPTION
    This script validates all JSON and JSONC files recursively
    under the Path parameter directory against their specified 
    JSON schemas.
    It will validate against the schema uri in the '$schema' 
    property in the json if present. If ValidateVSCodeJsonSchemaPatterns
    parameter is true, it will validate against all matching patterns
    in .vscode/settings.json [json.schemas] property.
    If a .json file matches multiple filters, or it has a different
    '$schema' property, it will be validated multiple times against
    each individual json schema.
.PARAMETER Path
    The path to the from where to process files.
.PARAMETER Depth
    The number of levels in the directory structure to process.
.PARAMETER ValidateVSCodeJsonSchemaPatterns
    If this is set to true, the script will try to get the json.schemas
    setting from the settings.json file in VSCode and validate agains the
    specified schemas.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ | Test-Path -PathType Container })]
    [string]
    $Path = ".",

    [Parameter(Mandatory = $false)]
    [int]
    $Depth = 10,

    [Parameter(Mandatory = $false)]
    [bool]
    $ValidateVSCodeJsonSchemaPatterns = $true
)

Write-Debug "Validate-Json.ps1: Started."
Write-Debug "Input parameters: $($PSBoundParameters | ConvertTo-Json -Depth 3)"

#* Establish defaults
$scriptRoot = $PSScriptRoot
Write-Debug "Working directory: '$((Resolve-Path -Path .).Path)'."
Write-Debug "Script root directory: '$(Resolve-Path -Relative -Path $scriptRoot)'."

#* Import Modules
Import-Module $scriptRoot/support-functions.psm1 -Force

#* Find local VS Code settings file in repository.
#* Note: Any workspace settings will not be loaded. Only the one located in the repo (if any) is loaded.
$vsCodeSettingsPath = "./.vscode/settings.json"
if ($ValidateVSCodeJsonSchemaPatterns -and (Test-Path $vsCodeSettingsPath)) {
    Write-Debug "ValidateVSCodeJsonSchemaPatterns set and .vscode/settings.json found."
    $vsCodeSettings = Get-Content -Path $vsCodeSettingsPath | ConvertFrom-Json -Depth 10 -AsHashtable -NoEnumerate
    $jsonSchemasSettings = $vsCodeSettings.'json.schemas'
}
else {
    $jsonSchemasSettings = @()
}

$nError = 0

$jsonFiles = @(Get-ChildItem -Recurse -Force -Depth $Depth -Path $Path -Include ('*.json', '*.jsonc'))
Write-Debug "Found $($jsonFiles.Count) .json and .jsonc files."
foreach ($jsonFile in $jsonFiles) {
    $relativePath = Resolve-Path -Relative -Path $jsonFile.FullName
    Write-Debug "Processing file: $relativePath."

    $jsonContent = Get-Content $relativePath -Raw
    $jsonObject = $jsonContent | ConvertFrom-Json -Depth 30 -AsHashtable -NoEnumerate
    
    # json arrays would normally be converted to a list, Object[], but we need an object to validate against a schema.
    if ($jsonObject.GetType().Name -ne "OrderedHashtable") {
        Write-Warning "File '$relativePath' could not be converted to an OrderedHashtable, JSON might be a list instead of object. Skipping file..."
        continue
    }
    
    if ($jsonObject.ContainsKey('$schema')) {
        Write-Debug "Found `"`$schema`" property: '$($jsonObject.'$schema')'."
        $schemaContent = Get-SchemaContent -Uri $jsonObject.'$schema'
        try {
            $null = Test-Json -Json $jsonContent -Schema $schemaContent -ErrorAction Stop
            Write-Host "Successfully validated '$relativePath'."
        }
        catch {
            Write-Error "Failed to validate '$relativePath'."
            Write-Error -Exception $_.Exception
            $nError++
        }
    }
    elseif ($jsonSchemasSettings) {
        foreach ($entry in $jsonSchemasSettings) {
            $pathMatchesGlob = $false
            foreach ($fileMatch in $entry.fileMatch) {
                if ($relativePath -replace "^\./" -in (git ls-files $entry.fileMatch)) {
                    $pathMatchesGlob = $true
                    break
                }
            }

            if ($pathMatchesGlob) {
                if ($entry.url) {
                    Write-Debug "Found file match in vscode settings.json. Url: '$($entry.url)'."
                    $schemaContent = Get-SchemaContent -Uri $entry.url
                }
                elseif ($entry.schema) {
                    Write-Debug "Found file match in vscode settings.json. Directly defined schema."
                    $schemaContent = $entry.schema | ConvertTo-Json -Depth 30
                }
                try {
                    $null = Test-Json -Json $jsonContent -Schema $schemaContent -ErrorAction Stop
                    Write-Host "Successfully validated '$relativePath'."
                }
                catch {
                    Write-Error "Failed to validate '$relativePath'."
                    Write-Error -Exception $_.Exception
                    $nError++
                }
            }
        }
    }
}

if ($nError -gt 0) {
    throw "$nError JSON files failed to validate against specified JSON schemas."
}