[CmdletBinding()]
param (
    [parameter(Mandatory=$False)]
    [string] $xmlurl = "https://gist.githubusercontent.com/Skatterbrainz/feac5f81de66a4a83ad42b4447b4bffd/raw/676040d9afe83496d9c06f492fbc6c36d37da370/cmlab-queries.xml"
)

[xml]$cdata = ((New-Object System.Net.WebClient).DownloadString($xmlurl))
if (!($cdata.HasChildNodes)) {
    Write-Warning "failed to import xml template"
    break
}

foreach ($query in $cdata.config.queries.query) {
    $queryName = $query.Name
    $queryText = $query.Query
    Write-Verbose "name: $queryName"
    Write-Verbose "text: $queryText"
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
Write-Host "completed" -ForegroundColor Green
