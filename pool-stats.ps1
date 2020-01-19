
############################################################################
# Scriptname:     Pool_Stats.ps1
# Description:     Checks against ADAM for Pool statistics
# By:            Adam Baldwin
#
# Usage: Use this script to count all machines in the View ADAM DB and query pae-dirtyfornewsessions
# attribute for availability, then make a count for each pool of available vs unavailable machines.
#
#
############################################################################

#Import Quest AD module for LDAP queries
Import-Module -Name "C:\Program Files\Quest Software\Management Shell for AD\Quest.ActiveRoles.ArsPowerShellSnapIn.dll"

$EmailFrom = Read-Host -Prompt 'Email From: '
$EmailTo = Read-Host -Prompt 'Email To: '
$LDAPHost = Read-Host -Prompt 'Connection Server: '
$SMTPSRV = Read-Host -Prompt 'Email Relay Server: '
$EmailSubject = "POOL - NO AVAILABLE MACHINES IN ONE OR MORE POOLS"

$MyReport = "There are 0 available desktops in the following pool(s): `n`n" + $list


# Specify the LDAP path to bind to, here the Pools OU (Server Group)
$LDAPPath = "LDAP://$LDAPHost:389/OU=Server Groups,DC=vdi,DC=vmware,DC=int"
$LDAPEntry = New-Object DirectoryServices.DirectoryEntry $LDAPPath

# Create a selector and start searching from the path specified in $LDAPPath
$Selector = New-Object DirectoryServices.DirectorySearcher
$Selector.SearchRoot = $LDAPEntry
$object = "pae-serverpooltype"

# Creates registry keys for 0 available alert, if they do not already exist
if (!(Test-Path -Path "hklm:software\VMWare, Inc.\availability")) {
	new-item -path "hklm:software\VMWare, Inc.\availability"
	New-ItemProperty "hklm:\software\VMWare, Inc.\availability" -Name "available" -Value "" -PropertyType "String"
	New-ItemProperty "hklm:\software\VMWare, Inc.\availability" -Name "noneAvailable" -Value "" -PropertyType "String"
}

# Run the FindAll() method and limit to only return what corresponds to Pools in VMware View
$Pools = $Selector.FindAll() | where {$_.Properties.objectcategory -match "CN=pae-ServerPool" -and `
            $_.Properties.$object -eq "4"}

# Loop thru each pool found in the above $Pools

$a = 0
$pool_ids = @()
$available = 0
$unavailable = 0

$count = $pools.count
for ( $i = 0 ; $i -lt $count; $i++ ) { $pool_ids += @($i) }

if ($count -eq $null)
{
	$Pool_ids = @(1)
}

foreach ($Pool in $Pools)
{

	$attribute = $Pool.Properties

	# Define what value we are looking for, here we are retrieving pool name
	$value = 'name'

	$pool = $attribute.$value

	$pool_ids[$a] = $pool
	$a++

}


$hash = @{}
$hash_clon = @{}
$hash_cust = @{}
$hash_ready = @{}
$hash_image = @{}
$hash_build = @{}
$hash_cloneVol = @{}
$hash_repVol = @{}

foreach ($id in $pool_ids)
{
	$hash.add("$id", 0)
	$hash_clon.add("$id", 0)
	$hash_cust.add("$id", 0)
	$hash_ready.add("$id", 0)
	$hash_image.set_item("$id", "blank")
	$hash_build.set_item("$id", "blank")
	$hash_cloneVol.set_item("$id", "blank")
	$hash_repVol.set_item("$id", "blank")
}

# Specify the LDAP path to bind to, here the VM OU (Servers)
$LDAPPath = 'LDAP://<<CONNECTION SERVER>>:389/OU=Servers,DC=vdi,DC=vmware,DC=int'
$LDAPEntry = New-Object DirectoryServices.DirectoryEntry $LDAPPath

# Create a selector and start searching from the path specified in $LDAPPath
$Selector = New-Object DirectoryServices.DirectorySearcher
$Selector.SearchRoot = $LDAPEntry

# Run the FindAll() method and limit to only return what corresponds to Virtual Desktops in VMware View
$VMs = $Selector.FindAll() | where {$_.Properties.objectcategory -match "CN=pae-VM"}

# Loop thru each desktop found on the above $VMs
foreach ($VM in $VMs) {
	$attribute = $VM.Properties

	# Define what value we are looking for, here we are checking VM availability
	$value = 'pae-dirtyfornewsessions'

	$ProvStatus = $attribute.$value

	if ($ProvStatus -eq "1") {
	$unavailable++
	}
	else {
	$available++
	}

	# Below pulls VM Path name to perform logic
	# The pool ID MUST match the View Folder name (default in View, and without any
	# subdirectories) or miscount will occur

	$attribute = $VM.Properties
	$Value = 'pae-vmpath'
	$path = $attribute.$value

	# Reassign $value to the displayname in order to perform string parsing
	$value = 'pae-displayname'
	$name = "/" + $attribute.$value
	$path = $path -Replace ($name, "")

	# Parser strings for directory paths to the Pool folder
	$extPath = <<These will be found in your vSphere vCenter inventory>>
	$extPath_2 = <<Additional paths where View machines reside in vCenter inventory>>

	$path = $path -Replace ($extPath, "")
	$path = $path -Replace ($extPath_vc6, "")

	# Define what value we are looking for, here we are checking VM state
	$value = 'pae-vmstate'
	$state = $attribute.$value



	# Upon verifying the machine is available, increment a count to the $hash table for the
	# corresponding pool

	if ($ProvStatus -ne "1")
	{
		foreach ($id in $pool_ids)
		{
			if ("$path" -eq "$id")
			{
				if ("$state" -eq "READY"){
					$hash_ready["$id"]++
				}
				if ("$state" -eq "CUSTOMIZING") {
					$hash_cust["$id"]++
				}
				if ("$state" -eq "CLONING") {
					$hash_clon["$id"]++
				}
				$hash["$id"]++
			}
			Else
			{
			}
		}

	}

}

$a = 0

foreach ($Pool in $Pools)
{
	$attribute = $Pool.Properties

	$value = 'pae-svivmparentvm'
	$image = $attribute.$value
	$image_parse5 = "/VC5/vm/Templates/"
	$image_parse6 = "/VC6/vm/Templates/"
	$image_parse1 = "/OMC/vm/Templates/"

	$image = $image -Replace ($image_parse5, "")
	$image = $image -Replace ($image_parse6, "")
	$image = $image -Replace ($image_parse1, "")

	$name = $Pool_ids[$a]

	$hash_image.set_item("$name", "$image")

	$a++
}


$a = 0

foreach ($Pool in $Pools)
{
	$attribute = $Pool.Properties

	$value = 'pae-svivmsnapshot'
	$build = $attribute.$value
	$build = "$build"

	$length = $build.length
	$length = $length - 4
	$build = $build.substring($length, 4)

	$name = $Pool_ids[$a]

	$hash_build.set_item("$name", "$build")

	$a++
}

$a = 0

foreach ($Pool in $Pools)
{
	$attribute = $Pool.Properties

	$value = 'pae-svivmdatastore'
	$value2 = 'pae-vmdatastore'
	$clone = $attribute.$value | Out-String
	$rep = $attribute.$value2 | Out-String

	$name = $Pool_ids[$a]

    $hash_cloneVol.set_item("$name", "$clone")
    $hash_repVol.set_item("$name", "$rep")

	$a++
}

# This method used to export all data sets into a csv table
$exp = @("Pools,Available,Ready,Customizing,Cloning,Image,Build,CloneVol,RepVol")
$hash.keys | sort | %{$exp += (@($_) + $hash.$_ + $hash_ready.$_ + $hash_cust.$_ + $hash_clon.$_ + $hash_image.$_ + `
                                $hash_build.$_ + $hash_cloneVol.$_ + $hash_repVol.$_) -join ","}


# This method used to export csv table. Here, we had to Out-File first and
# then Import/Export the csv to correct delimeter issues
Remove-Item c:\Scripts\Pool_Stats.csv
$exp | Out-File c:\Scripts\temp.csv
$imp = Import-Csv c:\Scripts\temp.csv
$imp | Export-Csv -NoTypeInformation c:\Scripts\Pool_Stats.csv
Remove-Item c:\Scripts\temp.csv
(Get-Content C:\Scripts\Pool_Stats.csv) | foreach {$_ -replace '"'} | Set-Content C:\Scripts\Pool_Stats.csv

# Create XML template with single tag in an empty string, append all pool data from previous csv
$xml = "<Pools>"
# Below is a useful method for c7:36 AM 4/16/2013reating xml objects in an already existant xml file,
# this is commented out for future application
$xml += $(import-csv c:\scripts\pool_stats.csv | foreach {'<Pool Pool="{0}" Available="{1}" Ready="{2}" `
            Customizing="{3}" Cloning="{4}" Image="{5}" Build="{6}" CloneVol="{7}" RepVol="{8}"/>' -f `
            $_.Pools, $_.Available, $_.Ready, $_.Customizing, $_.Cloning, $_.Image, $_.Build, $_.CloneVol, $_.RepVol})
$xml += "</Pools>"

$xml | out-file <<FILENAME & LOCATION>>.xml

$wksAvailable = ""
$noneAvailable = ""

# Check if any pools have 0 available and send an alert if so

$send = 0
$list = $null

foreach ($item in $hash_ready.keys)
{
	if ($hash_ready[$item] -eq 0)
	{
		$noneAvailable += $item + ","
		$noneAvailable = $noneAvailable -Replace " ", ""
	}
	else
	{
		$wksAvailable += $item + ","
		$wksAvailable = $wksAvailable -Replace " ", ""
	}
}

# Perform availability logic to prevent repeat alerts

$available_test = (Get-ItemProperty "hklm:software\VMWare, Inc.\availability").noneAvailable
$available_test = $available_test -split ","
$available_test = $available_test -Replace ",", ""
$noneAvailable_new = $noneAvailable -split ","
$noneAvailable_new = $noneAvailable_new -Replace ",", ""

foreach ($unavailable in $noneAvailable_new) {

	if ($available_test -contains $unavailable)
	{}
	else {
		$list += $unavailable + "`n"
		$send++
	}
}

Set-ItemProperty "hklm:software\VMWare, Inc.\availability" -Name available -Value $wksAvailable
Set-ItemProperty "hklm:software\VMWare, Inc.\availability" -Name noneAvailable -Value $noneAvailable

if ($send -ne "0"){send-Mailmessage -To $EmailTo -From $EmailFrom -Subject $EmailSubject -SmtpServer $SMTPSRV -Body $MyReport}

# Below converts the Pool Statistics csv into XML using built-in ConvertTo-XML
# $csv = "c:\Scripts\Pool_Stats.csv"
# $new_xml = "c:\Scripts\pools.xml"
# (Import-Csv -path $csv | ConvertTo-Xml -NoTypeInformation).Save($new_xml)
