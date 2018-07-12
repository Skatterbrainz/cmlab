#requires -modules ConfigurationManager

# NOT FINISHED - PLACEHOLDER ONLY - 07-12-2018

function Import-CmLabApps {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory=$False, HelpMessage="XML source file path or URL")]
            [string] $XmlPath = "",
        [parameter(Mandatory=$True, HelpMessage="Path to staging folders")]
            [ValidateNotNullOrEmpty()]
            [string] $SourcesPath,
        [parameter(Mandatory=$False, HelpMessage="Path to temp download folder")]
            [ValidateNotNullOrEmpty()]
            [string] $TempPath = "$($env:TEMP)\cmlab\apps\temp",
        [parameter(Mandatory=$False, HelpMessage="Force new downloads")]
            [switch] $ForceDownload,
        [parameter(Mandatory=$False, HelpMessage="Remove All imported apps")]
            [switch] $RemoveAll
    )
    if (!($($(Get-Location).Provider).Name -eq 'CMSite')) {
        Write-Warning "This must be run from a ConfigMgr PowerShell session using the provider drive mapping"
        break
    }

    $cdata = Import-XmlData -XmlFilePath $XmlPath -AssetFile "cmlab-apps.xml"
    
    if (!($cdata.HasChildNodes)) {
        Write-Warning "failed to import xml template"
        break
    }

    if (!(Test-Path $TempPath)) {
        Write-Verbose "creating temporary folder: $TempPath"
        mkdir $TempPath -Force
    }
    else {
        Write-Verbose "temporary folder already exists: $TempPath"
    }

    foreach ($appSet in $cdata.config.applications.application) {
        $appName = $appSet.Name
        $appVer  = $appSet.Version
        $urls    = $appSet.url
        $icon    = $appSet.icon
        <#
        example...

        $appName = "7-Zip"
        $appVer  = "18.05"
        $urls    = "https://www.7-zip.org/a/7z1805.msi,https://www.7-zip.org/a/7z1805-x64.msi"
        $icon    = "http://foo.local/7zip.jpg"
        $cmdline = "/q"
        #>
        if ($RemoveAll) {
            try {
                Get-CMApplication -Name $appName | Remove-CMApplication -Force
                Write-Host "removed: $appName" -ForegroundColor Green
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }
        else {
            $AppSrc = Join-Path -Path $SourcesPath -ChildPath $appName
            $OldLoc = Get-Location
            Set-Location "C:"

            if (!(Test-Path $AppSrc)) { 
                Write-Verbose "folder path not found...: $AppSrc"
                Write-Verbose "creating folder path....: $AppSrc"
                try {
                    mkdir $AppSrc -Force 
                    $GetLinks = $True
                }
                catch {
                    Write-Warning $_.Exception.Message
                    break
                }
            }
            else {
                Write-Verbose "folder already exists...: $AppSrc"
            }
            Set-Location $OldLoc

            Write-Host $appName

            foreach ($link in ($urls -split ',')) {
                Write-Host $link
                $linklist = $link -split '/'
                $filename = $linklist[$linklist.Length -1]
                Write-Verbose "filename: $filename"
                $fileSrc = Join-Path -Path $AppSrc -ChildPath $filename
                $tempSrc = Join-Path -Path $TempPath -ChildPath $filename
                Set-Location "C:"
                if (!(Test-Path $FileSrc)) {
                    if (Test-Path $TempSrc) {
                        Write-Verbose "copying file from temp location to staging"
                        Copy-Item -Path $tempSrc -Destination $fileSrc -Force
                    }
                    else {
                        Write-Verbose "temp path not found: $tempsrc"
                    }
                }
                else {
                    Write-Verbose "file already staged for import: $filesrc"
                }
                Set-Location $OldLoc
                
                $fileExt = $filename.Split('.')[1]
                if ($filename -like "*64*") {
                    $dtName = "64bit"
                }
                else {
                    $dtName = "32bit"
                }
                Write-Verbose "deployment type name: $dtName"

                switch ($fileExt) {
                    'msi' {
                        $instCmd = "msiexec /i $filename /q"
                        break
                    }
                    'exe' {
                        $instCmd = "$filename /S"
                        break
                    }
                } # switch
                Write-Verbose "installation command: $instCmd"

                Write-Host "creating: $appName" -ForegroundColor Green
                
                try {
                    $app = New-CMApplication -Name $appName -SoftwareVersion $appVer
                    if ($fileExt -eq 'msi') {
                        Write-Verbose "creating msi deployment type"
                        $app | 
                            Add-CMMsiDeploymentType -ContentLocation $fileSrc -EnableBranchCache `
                                -DeploymentTypeName $dtName -CacheContent `
                                -Comment "$dtName install" `
                                -LogonRequirementType WhetherOrNotUserLoggedOn `
                                -UserInteractionMode Hidden `
                                -CacheContent -InstallCommand $instCmd -Force
                    }
                    else {
                        Write-Verbose "creating script deployment type"
                        $app | 
                            Add-CMScriptDeploymentType -DeploymentTypeName $dtName `
                                -Comment "$dtName install" `
                                -InstallCommand $instCmd -ScriptLanguage VBScript `
                                -ContentLocation $AppSrc -CacheContent -EnableBranchCache `
                                -LogonRequirementType WhetherOrNotUserLoggedOn `
                                -InstallationBehaviorType InstallForSystem `
                                -ScriptContent "1231231" -ForceScriptDetection32Bit -Force
                    }
                    Write-Verbose "deployment type created"
                }
                catch {
                    if ($_.Exception.Message -like "*already exists*") {
                        Write-Verbose "application already exists"
                    }
                    else {
                        Write-Error $_.Exception.Message
                    }
                }
            } # foreach
        }
    } # foreach
    Write-Host "completed"
}
