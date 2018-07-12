#requires -modules ConfigurationManager

function Import-CmLabQueries {
    <#
    .DESCRIPTION
        Import or remove custom CM queries using a remote XML template
    .PARAMETER XmlPath
        URL to .xml source file.  Default is "" (use internal example)
    .PARAMETER RemoveAll
        Remove all custom collections from CM site which aredefined in the referenced .xml template
    .PARAMETER NoFolder
        Do not create custom console folder for new items
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory=$False, HelpMessage="XML source file Path or URL")]
            [string] $XmlPath = "",
        [parameter(Mandatory=$False, HelpMessage="Remove Custom Queries")]
            [switch] $RemoveAll,
        [parameter(Mandatory=$False, HelpMessage="Place in root folder only")]
            [switch] $NoFolder
    )
  
    if (!($($(Get-Location).Provider).Name -eq 'CMSite')) {
        Write-Warning "This must be run from a ConfigMgr PowerShell session using the provider drive mapping"
        break
    }

    $cdata = Import-XmlData -XmlFilePath $XmlPath -AssetFile "cmlab-queries.xml"
    
    if (!($cdata.HasChildNodes)) {
        Write-Warning "failed to import xml template"
        break
    }
  
    if (!($NoFolder)) {
        $folderPath = "query"
        $folderName = "CMLab"
        if (!($RemoveAll)) {
            Write-Verbose "creating custom folder: $folderName"
            try {
                New-Item -Path "$SiteCode`:\$folderPath" -Name $folderName -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
        else {
            Write-Verbose "removing custom folder: $folderName"
            try {
                Remove-Item -Path "$SiteCode`:\$folderPath\$folderName" -Force -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
    }

    foreach ($query in $cdata.config.queries.query) {
        $queryName = $query.Name
        $queryType = $query.'type'
        $queryText = $($query.'#text').Trim()
        Write-Verbose "name: $queryName"
        Write-Verbose "type: $queryType"
        Write-Verbose "text: $queryText"
        if (!($RemoveAll)) {
            try {
                New-CMQuery -Name $queryName -Expression $queryText -ErrorAction SilentlyContinue
                Write-Host "creating query: $queryName" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*already exists*") {
                    Write-Verbose "query already exists: $queryName"
                }
                else {
                    Write-Error $_.Exception.Message
                }
            }
        }
        else {
            try {
                Get-CMQuery -Name $queryName | Remove-CMQuery -Force
                Write-Host "removed: $queryName" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Message -like "*not found*") {
                    Write-Warning "not found: $queryName"
                }
                else {
                    Write-Error $_.Exception.Message
                }
            }
        }
    } # foreach
    Write-Host "completed" -ForegroundColor Green
}
