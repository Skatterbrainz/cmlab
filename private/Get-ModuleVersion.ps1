function Get-ModuleVersion {
    param (
        [parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName
    )
    $ModuleData = Get-Module $ModuleName
    $result = $ModuleData.Version -join '.'
    Write-Output $result
}
