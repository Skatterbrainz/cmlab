#requires -modules dbatools
#requires -modules ConfigurationManager
<#
.SYNOPSIS
  Register SPN for SQL Instance and associated account
.PARAMETER SqlInstance
  Server FQDN Host Name
.PARAMETER InstanceName
  Name of SQL Instance.  Default is "MSSQLSvc"
.PARAMETER SqlAccount
  Name of SQL service account. Example "contoso\sql-svc"
#>

function Set-CmLabSqlServerSPN {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$True, HelpMessage="SQL Host Name")]
    [ValidateNotNullOrEmpty()]
    [string] $SqlInstance,
    [parameter(Mandatory=$False, HelpMessage="SQL Instance Name")]
    [string] $InstanceName = "MSSQLSvc",
    [parameter(Mandatory=$True, HelpMessage="SQL Server Account")]
    [ValidateNotNullOrEmpty()]
    [string] $SqlAccount
  )
  $SpnShort = $SqlInstance.split('.')[0]
  if (!(Test-DbaSpn -ComputerName $SqlInstance).InstanceServiceAccount[0] -eq $SqlAccount) {
    $Spn1 = "$InstanceName/$SpnShort:1433"
    $Spn2 = "$InstanceName/$SqlInstance:1433"
    try {
      Set-DbaSpn -SPN $Spn1 -ServiceAccount $SqlAccount -Credential (Get-Credential)
      Set-DbaSpn -SPN $Spn2 -ServiceAccount $SqlAccount -Credential (Get-Credential)
    }
    catch {
      Write-Error $_.Exception.Message
    }
  }
  else {
    Write-Warning "SPN already configured"
  }
}
