<#
.SYNOPSIS
  Move SUSDB file path
.PARAMETER NewFolderPath
  Destination file path
#>
function Move-CmLabSUSDBFilePath {
  [CmdletBinding()]
  param (
      [parameter(Mandatory=$True, HelpMessage="New Database Files Path")]
      [ValidateNotNullOrEmpty()]
      [string] $NewFolderPath
  )
  if (!(Test-Path $NewFolderPath)) {
    try {
      mkdir $NewFolderPath
    }
    catch {
      Write-Error $_.Exception.Message
      break
    }
  }
  $DatabaseName = "SUSDB"
  $ServiceName = "WsusService"
  $AppPool = "WsusPool"

  try {
    Write-Verbose "importing module: WebAdministration"
    Import-Module WebAdministration -ErrorAction Stop
  }
  catch {
    Write-Warning "Module not found: WebAdministration"
    break
  }
  try {
    Write-Verbose "importing module: SQLPS"
    Import-Module SQLPS -DisableNameChecking -ErrorAction Stop
  }
  catch {
    Write-Warning "Module not found: SQLPS"
    break
  }
  Write-Verbose "stopping WSUS application pool"
  Stop-WebAppPool -Name $AppPool
  
  Write-Verbose "stopping WSUS service"
  Get-Service -Name $ServiceName | Stop-Service
  
  $UpdateStatistics = $False
  $RemoveFullTextIndexFile = $False
  
  $ServerName = $env:COMPUTERNAME
  $ServerSource = New-Object "Microsoft.SqlServer.Management.Smo.Server" $ServerName
  
  Write-Verbose "detaching WSUS SUSDB database"
  $Db = $ServerSource.Databases | Where-Object {$_.Name -eq $DatabaseName}
  $CurrentPath = $Db.PrimaryFilePath
  Write-Verbose "current path is $CurrentPath"
  
  $ServerSource.DetachDatabase($DatabaseName, $True, $True)
  $files = Get-ChildItem -Path $CurrentPath -Filter "$DatabaseName*.??f"
  
  Write-Verbose "moving database files to $NewFolderPath"
  $files | Move-Item -Destination $NewFolderPath
  $files = (Get-ChildItem -Path $NewFolderPath -Filter "$DatabaseName*.??f") | Select-Object -ExpandProperty FullName
  
  Write-Verbose "attaching database files"
  $ServerSource.AttachDatabase("SUSDB", $files, 'sa')
  
  Write-Verbose "starting WSUS service"
  Get-Service -Name $ServiceName | Start-Service
  
  Write-Verbose "starting WSUS app pool"
  Start-WebAppPool -Name $AppPool
  
  Write-Host "WSUS database files have been moved to $NewFolderPath"
}
