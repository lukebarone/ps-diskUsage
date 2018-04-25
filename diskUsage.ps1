<#
.SYNOPSIS
  Checks fixed devices, and their free space

.DESCRIPTION
  Checks disk space that is remaining on fixed volumes. 

.PARAMETER ThresholdAsPercent
  (Optional) The percent of Free Space remaining to check for. If the amount of
  free space is below this variable, it is assumed to be something to alert you
  with. If not set, defaults to 10% before alerting.

.PARAMETER DisplayDiskUsage
  (Optional) Displays a table showing the fixed disks, and their usage. If not
  set, defaults to $false. When set to $false, the script returns no output if
  the system has adequate free space available.

.NOTES
  Written by Luke Barone.

.LINK
  https://github.com/lukebarone/ps-diskUsage

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $False)]
    [int]$ThresholdAsPercent = 10,

    [Parameter(Mandatory = $false)]
    [boolean]$DisplayDiskUsage = $False
)


$disks = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2"
$results = foreach ($disk in $disks) {
    if ($disk.Size -gt 0) {
        $SizeOfDisk = [math]::round($disk.Size/1GB, 0)
        $FreeSpace = [math]::round($disk.FreeSpace/1GB, 0)
        [int]$FreePercent = ($FreeSpace/$SizeOfDisk) * 100
        If ($FreePercent -lt $ThresholdAsPercent) {
            Write-Output "Drive $($disk.Name) ($($disk.VolumeName)) has low disk space remaining! $($FreeSpace) GB free of $($SizeOfDisk) GB ($($FreePercent) %)"
        }
        [PSCustomObject]@{
            Drive = $disk.Name
            Name = $disk.VolumeName
            "Total Disk Size" = "{0:N0} GB" -f $SizeOfDisk 
            "Free Disk Size" = "{0:N0} GB ({1:N0} %)" -f $FreeSpace, ($FreePercent)
            "Below Threshold" = ($FreePercent -lt $ThresholdAsPercent)
        }
    }
}
If ($DisplayDiskUsage -eq $True) {
    $results | Format-Table
}
