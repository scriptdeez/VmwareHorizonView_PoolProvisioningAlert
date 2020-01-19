
############################################################################
# Scriptname:     Pool_prov.ps1
# Description:     Checks against ADAM for Pool Status
# By:            Adam Baldwin
#
# Usage: Use this script to check whether any pools are in a non-provisioning
# state and send an email alert with a list of errors
#
############################################################################

#Import Quest AD module for LDAP queries
Import-Module -Name "C:\Program Files\Quest Software\Management Shell for AD\Quest.ActiveRoles.ArsPowerShellSnapIn.dll"

$EmailFrom = Read-Host -Prompt 'Email From: '
$EmailTo = Read-Host -Prompt 'Email To: '
$LDAPHost = Read-Host -Prompt 'Connection Server: '
$SMTPSRV = Read-Host -Prompt 'Email Relay Server: '
$EmailSubject = "VIEW POOL - PROVISION ERROR"
$MyReport = "The following Pools have stopped provisioning due to one or more errors: `n`n" + $list
# Specify the LDAP path to bind to, here the Pools OU (Server Group)
$LDAPPath = "LDAP://$LDAPHost:389/OU=Server Groups,DC=vdi,DC=vmware,DC=int"
$LDAPEntry = New-Object DirectoryServices.DirectoryEntry $LDAPPath

# Create a selector and start searching from the path specified in $LDAPPath
$Selector = New-Object DirectoryServices.DirectorySearcher
$Selector.SearchRoot = $LDAPEntry


# Run the FindAll() method and limit to only return what corresponds to Pools in VMware View
$Pools = $Selector.FindAll() | where {$_.Properties.objectcategory -match "CN=pae-ServerPool"}

# Creates registry keys if they do not already exist
if (!(Test-Path -Path "hklm:software\VMWare, Inc.\stats")) {
	new-item -path "hklm:software\VMWare, Inc.\stats"
	New-ItemProperty "hklm:\software\VMWare, Inc.\stats" -Name "enabled" -Value "" -PropertyType "String"
	New-ItemProperty "hklm:\software\VMWare, Inc.\stats" -Name "disabled" -Value "" -PropertyType "String"
}

# Instantiate variables
$list = ""
$pool_ids = @()
$pool_state = @()
$pool_error = @()
$error_msg = ""
$a = 0
$hash = @{}
$error_hash = @{}
$error_count = 0
$disabled = ""
$enabled = ""


# Loop thru each pool found in the above $Pools
$count = $pools.count
for ( $i = 0 ; $i -lt $count; $i++ ) { $pool_ids += @($i) }
for ( $i = 0 ; $i -lt $count; $i++ ) { $pool_state += @($i) }

if ($count -eq $null)
{
	$Pool_ids = @(1)
	$Pool_state = @(1)
}

foreach ($Pool in $Pools)
{

	$attribute = $Pool.Properties

	# Define what value we are looking for, here we are retrieving pool name
	$value = 'name'
	$status = 'pae-vmprovenabled'
	$msg = 'pae-vmproverror'
	$pool = $attribute.$value
	$state = $attribute.$status
	$error_msg = $attribute.$msg

	if (!$error_msg) {
		$error_msg = "No error to report."
		}

	$pool_state[$a] = $state
	$pool_ids[$a] = $pool

	if ($($pool_state[$a]) -eq 0) {
		$hash.add("$pool", 0)
		$error_hash.add("$pool", "$error_msg")
		$Error_count += 1
		$disabled += $pool + ","
		$disabled = $disabled -Replace " ", ""

	}
	elseif ($($pool_state[$a]) -eq 1) {
		$hash.Add("$pool", 1)
		$enabled += $pool + ","
		$enabled = $enabled -Replace " ", ""

	}

	$a++

}

# Build hashtables for error count and messages, build variables
$Pool_msg = @()
for ( $i = 0 ; $i -lt $error_count; $i++ ) { $pool_error += @($i) }
for ( $i = 0 ; $i -lt $error_count; $i++ ) { $pool_msg += @($i) }
$a = 0
$exc = 0

$ds_test = (Get-ItemProperty "hklm:software\VMWare, Inc.\stats").disabled
$ds_test = $ds_test -split ","
$disable_new = $disabled -split ","

foreach ($id in $pool_ids)
{

	if ($($hash[$id]) -eq 1) {

	}
	elseif ($($hash[$id]) -eq 0) {
		$pool_error[$exc] = $id
		$pool_msg[$exc] = " - " + $error_hash["$id"]
		$exc++
	}

	$a++
}

# count to determine whether email should be sent
$send = 0
$exc = 0

foreach ($fail in $pool_error) {

	if ($ds_test -contains $disable_new[$exc])
	{}
	else {
		$list += $pool_error[$exc] + $pool_msg[$exc] + "`n"
		$send++
	}
	$exc++
}

if ($send -ne "0"){send-Mailmessage -To $EmailTo -From $EmailFrom -Subject $EmailSubject -SmtpServer $SMTPSRV -Body $MyReport}


Set-ItemProperty "hklm:software\VMWare, Inc.\stats" -Name enabled -Value $enabled
Set-ItemProperty "hklm:software\VMWare, Inc.\stats" -Name disabled -Value $disabled




