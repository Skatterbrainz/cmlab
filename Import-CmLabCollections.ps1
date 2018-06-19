#requires -modules ConfigurationManager

function Import-CmLabCollections {
    <#
    .DESCRIPTION
        Import or remove custom CM collections using a remote XML template
    .PARAMETER xmlurl
        URL to .xml source file.  Default is https://raw.githubusercontent.com/Skatterbrainz/cmlab/master/cmlab-queries.xml
    .PARAMETER DeviceLimitCollectionName
        Collection name for setting as Limiting Collection for new device collections
    .PARAMETER UserLimitCollectionName
        Collection name for setting as Limiting Collection for new user collections
    .PARAMETER RefreshIntervalDays
        Collection membership rule evaluation cycle recurrence interval in days. Default is 7 (days)
    .PARAMETER RemoveAll
        Remove all custom collections from CM site which aredefined in the referenced .xml template
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$False, HelpMessage="URI to XML source")]
            [ValidateNotNullOrEmpty()]
            [string] $xmlurl = 'https://raw.githubusercontent.com/Skatterbrainz/cmlab/master/cmlab-queries.xml',
        [parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [string] $DeviceLimitCollectionName = "All Systems",
        [parameter(Mandatory=$False)]
            [ValidateNotNullOrEmpty()]
            [string] $UserLimitCollectionName = "All Users",
        [parameter(Mandatory=$False)]
            [int] $RefreshIntevalDays = 7,
        [parameter(Mandatory=$False)]
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

    $colldata = $cdata.config.queries.query | Where-Object {$_.makecollection -eq 'true'}
    if (!($colldata.Count -gt 0)) {
        Write-Warning "none of the queries are marked for collection mapping"
        break
    }

    $sched = New-CMSchedule -RecurInterval Days -RecurCount $RefreshIntevalDays

    foreach ($query in $colldata) {
        $collName = $query.Name
        $collType = $query.'type'
        $queryText = $($query.'#text').Trim()
        Write-Host "name: $collName"
        Write-Host "type: $collType"
        Write-Host "text: $queryText"
        
        if (!($RemoveAll)) {
            switch ($collType) {
                'device' {
                    try {
                        $coll = New-CMDeviceCollection -Name $collName -LimitingCollectionName $DeviceLimitCollectionName -ErrorAction Stop
                        $coll | Set-CMDeviceCollection -RefreshType Both -RefreshSchedule $sched
                        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $collName -RuleName "1" -QueryExpression $queryText
                        Write-Host "created collection: $collName" -ForegroundColor Green
                    }
                    catch {
                        if ($_.Exception.Message -like "*already exists*") {
                            Write-Verbose "collection exists: $collName"
                        }
                        else {
                            Write-Error $_.Exception.Message
                        }
                    }
                    break
                }
                'user' {
                    try {
                        $coll = New-CMUserCollection -Name $collName -LimitingCollectionName $UserLimitCollectionName
                        $coll | Set-CMUserCollection -RefreshType Both -RefreshSchedule $sched
                        Add-CMUserCollectionQueryMembershipRule -CollectionName $collName -RuleName "1" -QueryExpression $queryText
                        Write-Host "created collection: $collName" -ForegroundColor Green
                    }
                    catch {
                        if ($_.Exception.Message -like "*already exists*") {
                            Write-Verbose "collection exists: $collName"
                        }
                        else {
                            Write-Error $_.Exception.Message
                        }
                    }
                    break
                }
            } # switch
        }
        else {
            switch ($collType) {
                'device' {
                    try {
                        Get-CMDeviceCollection -Name $collName |
                            Remove-CMDeviceCollection -Force
                        Write-Host "removed: $collName"
                    }
                    catch {
                        if ($_.Exception.Message -like "*not found*") {
                            Write-Warning "not found: $collName"
                        }
                        else {
                            Write-Error $_.Exception.Message
                        }
                    }
                    break
                }
                'user' {
                    try {
                        Get-CMUserCollection -Name $collName |
                            Remove-CMUserCollection -Force
                        Write-Host "removed: $collName"
                    }
                    catch {
                        if ($_.Exception.Message -like "*not found*") {
                            Write-Warning "not found: $collName"
                        }
                        else {
                            Write-Error $_.Exception.Message
                        }
                    }
                    break
                }
            } # switch
        }
    }
    Write-Host "completed" -ForegroundColor Green
}
