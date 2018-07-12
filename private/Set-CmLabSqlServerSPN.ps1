#requires -modules dbatools
#requires -modules ConfigurationManager

function Set-CmLabSqlServerSPN {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$False, HelpMessage="SQL Host Name")]
    [string] $SqlInstance = "cm01.contoso.local",
    [parameter(Mandatory=$False, HelpMessage="SQL Instance Name")]
    [string] $InstanceName = "MSSQLSvc",
    [parameter(Mandatory=$False, HelpMessage="SQL Server Account")]
    [string] $SqlAccount = "contoso\cm-sql"
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
