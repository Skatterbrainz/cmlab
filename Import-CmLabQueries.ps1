function Import-CmLabQueries {
    <#
    .DESCRIPTION
      Import or remove custom CM queries using a remote XML template
    .PARAMETER xmlurl
      URL to .xml source file.  Default is https://raw.githubusercontent.com/Skatterbrainz/cmlab/master/cmlab-queries.xml
    .PARAMETER RemoveAll
      Remove all custom collections from CM site which aredefined in the referenced .xml template
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$False, HelpMessage="URI to XML source")]
        [ValidateNotNullOrEmpty()]
        [string] $xmlurl = 'https://gist.githubusercontent.com/Skatterbrainz/feac5f81de66a4a83ad42b4447b4bffd/raw/676040d9afe83496d9c06f492fbc6c36d37da370/cmlab-queries.xml',
        [parameter(Mandatory=$False, HelpMessage="Remove Custom Queries")]
        [switch] $RemoveAll
    )
  
    if (!($($(get-location).Provider).Name -eq 'CMSite')) {
        Write-Warning "This must be run from a ConfigMgr PowerShell session using the provider drive mapping"
        break
    }
  
    [xml]$cdata = ((New-Object System.Net.WebClient).DownloadString($xmlurl))
    if (!($cdata.HasChildNodes)) {
        Write-Warning "failed to import xml template"
        break
    }
  
    foreach ($query in $cdata.config.queries.query) {
        $queryName = $query.Name
        $queryText = $($query.'#text').Trim()
        Write-Verbose "name: $queryName"
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
