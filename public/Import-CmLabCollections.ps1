#requires -modules ConfigurationManager

function Import-CmLabCollections {
    <#
    .DESCRIPTION
        Import or remove custom CM collections using a remote XML template
    .PARAMETER XmlPath
        .xml source file path or URL. Default is "" (use internal sample)
    .PARAMETER RefreshIntervalDays
        Collection membership rule evaluation cycle recurrence interval in days. Default is 7 (days)
    .PARAMETER RemoveAll
        Remove all custom collections from CM site which aredefined in the referenced .xml template
    .PARAMETER NoFolder
        Do not create custom console folder for new items

    .EXAMPLE
        Import-CmLabCollections 
    .EXAMPLE
        Import-CmLabCollections -XmlPath "c:\myfile.xml"
    .EXAMPLE
        Import-CmLabCollections -XmlPath "http://github.com/fakegithub/raw/myfile.xml"
    .EXAMPLE
        Import-CmLabCollections -RefreshIntervalDays 1
    .EXAMPLE
        Import-CmLabCollections -RemoveAll
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory=$False, HelpMessage="XML source file Path or URL")]
            [string] $XmlPath = "",
        [parameter(Mandatory=$False)]
            [int] $RefreshIntervalDays = 7,
        [parameter(Mandatory=$False)]
            [switch] $RemoveAll,
        [parameter(Mandatory=$False, HelpMessage="Place in root folder only")]
            [switch] $NoFolder
        )

    if (!($($(get-location).Provider).Name -eq 'CMSite')) {
        Write-Warning "This must be run from a ConfigMgr PowerShell session using the provider drive mapping"
        break
    }

    $cdata = Import-XmlData -XmlFilePath $XmlPath -AssetFile "cmlab-collections.xml"
    
    if (!($cdata.HasChildNodes)) {
        Write-Warning "failed to import xml template, or template has no items defined"
        break
    }

    if (!($NoFolder)) {
        $folderPath = "DeviceCollection,UserCollection"
        $folderName = "CMLab"
        if (!($RemoveAll)) {
            try {
                foreach ($p in $folderPath -split ',') {
                    Write-Verbose "creating custom folder: $p\$folderName"
                    New-Item -Path "$SiteCode`:\$p" -Name $folderName -ErrorAction SilentlyContinue | Out-Null
                }
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
        else {
            try {
                foreach ($p in $folderPath -split ',') {
                    Write-Verbose "removing custom folder: $p\$folderName"
                    Remove-Item -Path "$SiteCode`:\$p\$folderName" -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
            catch {
                Write-Error $_.Exception.Message
            }
        }
    }


    Write-Verbose "reading file: $XmlPath"
    $colldata = $cdata.config.collections.collection

    if (!($colldata.Count -gt 0)) {
        Write-Warning "found no collection items to import"
        break
    }
    else {
        Write-Host "found $($collData.Count) collection items to import" -ForegroundColor Green
    }

    Write-Verbose "creating schedule object for interval: $RefreshIntervalDays days"
    $sched = New-CMSchedule -RecurInterval Days -RecurCount $RefreshIntervalDays

    foreach ($coll in $colldata) {
        $collName  = $coll.Name
        $collLimit = $coll.Limit
        $collType  = $query.'type'
        $collRule  = $($query.'#text').Trim()
        Write-Verbose "name....: $collName"
        Write-Verbose "type....: $collType"
        Write-Verbose "limit...: $collLimit"
        Write-Verbose "text....: $collRule"
        
        if (!($RemoveAll)) {
            switch ($collType) {
                'device' {
                    try {
                        $coll = New-CMDeviceCollection -Name $collName -LimitingCollectionName $collLimit -ErrorAction Stop
                        $coll | Set-CMDeviceCollection -RefreshType Both -RefreshSchedule $sched
                        Add-CMDeviceCollectionQueryMembershipRule -CollectionName $collName -RuleName "1" -QueryExpression $collRule | Out-Null
                        Write-Host "created: $collName" -ForegroundColor Green
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
                        $coll = New-CMUserCollection -Name $collName -LimitingCollectionName $collLimit
                        $coll | Set-CMUserCollection -RefreshType Both -RefreshSchedule $sched
                        Add-CMUserCollectionQueryMembershipRule -CollectionName $collName -RuleName "1" -QueryExpression $collRule | Out-Null
                        Write-Host "created: $collName" -ForegroundColor Green
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
                            Remove-CMDeviceCollection -Force | Out-Null
                        Write-Host "removed: $collName" -ForegroundColor Green
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
                            Remove-CMUserCollection -Force | Out-Null
                        Write-Host "removed: $collName" -ForegroundColor Green
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
