function Get-ModulePath {
    param (
        [parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName
    )
    $ModuleData = Get-Module $ModuleName
    $result = $ModuleData.Path -replace $ModuleName+'.psm1', ''
    Write-Output $result
}
