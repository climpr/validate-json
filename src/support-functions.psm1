function Get-SchemaContent {
    [CmdletBinding()]
    param (
        $Uri
    )
    
    if (!$script:jsonSchemaMap) {
        $script:jsonSchemaMap = @{}
    }

    if ($script:jsonSchemaMap.ContainsKey($Uri)) {
        $schemaContent = $jsonSchemaMap[$Uri]
    }
    elseif (Test-Path $Uri) {
        #* Is local path
        $schemaContent = Get-Content -Raw -Path $Uri
        $script:jsonSchemaMap.Add($Uri, $schemaContent)
    }
    else {
        #* Assume its a uri
        $schemaContent = Invoke-WebRequest -Uri $Uri | Select-Object -ExpandProperty Content
        if ($schemaContent -is [System.Array]) {
            $schemaContent = [System.Text.Encoding]::UTF8.GetString($schemaContent)
        }
        $script:jsonSchemaMap.Add($Uri, $schemaContent)
    }

    return $schemaContent
}
