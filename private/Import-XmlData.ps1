function Import-XmlData {
    param (
        [parameter(Mandatory=$True)]
        [string] $XmlFilePath = "",
        [parameter(Mandatory=$False)]
        [string] $AssetFile = ""
    )
    if ($XmlFilePath -eq "") {
        #$ModuleVer  = Get-ModuleVersion -ModuleName "cmlab"
	    $ModulePath = Get-ModulePath -ModuleName "cmlab"
	    Write-Verbose "module path..... $ModulePath"
        $XmlFilePath = Join-Path -Path $ModulePath -ChildPath "assets\$AssetFile"
        if (!(Test-Path $XmlFilePath)) {
            Write-Error "Unable to find $AssetFile under module assets folder"
            break
        }
    }
    if ($XmlFilePath.StartsWith('http')) {
        [xml]$results = ((New-Object System.Net.WebClient).DownloadString($XmlFilePath))
    }
    else {
        if (Test-Path $XmlFilePath) {
            [xml]$results = Get-Content -Path $XmlFilePath
        }
        else {
            Write-Warning "not found: $XmlFilePath"
            break
        }
    }
    Write-Output $results
}
