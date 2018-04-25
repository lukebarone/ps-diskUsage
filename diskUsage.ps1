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

.PARAMETER SendAsEmail
  (Optional) Send the output via email. By default, if the disk usage is less
  than the threshold, no output is produced. This parameter allows you to send
  the emails only if the threshold has been passed. If set, you must also
  specify -ToEmail <string> -FromEmail <string> -SmtpServer <string>. You can
  also optionally specify the -CC <string>, -Port <int> and -Credential
  parameters, which will be used in place of $null.

.NOTES
  Written by Luke Barone.

.LINK
  https://github.com/lukebarone/ps-diskUsage

#>
[CmdletBinding()]
param(
    [Parameter(Position=0,Mandatory = $False)]                [int]$ThresholdAsPercent = 10,
    [Parameter(Position=1,Mandatory = $False)]                [switch]$DisplayDiskUsage = $False,
    [Parameter(ParameterSetName = 'Email',Mandatory = $False)][switch]$SendAsEmail,
    [Parameter(ParameterSetName = 'Email')]                   [string]$ToEmail,
    [Parameter(ParameterSetName = 'Email')]                   [string]$FromEmail,
    [Parameter(ParameterSetName = 'Email')]                   [string]$SmtpServer,
    [Parameter(ParameterSetName = 'Email',Mandatory = $False)][string]$CC,
    [Parameter(ParameterSetName = 'Email',Mandatory = $False)][PSCredential]$Credential,
    [Parameter(ParameterSetName = 'Email',Mandatory = $False)][int]$SMTPPort
)

$output = ''
$disks = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2"
$results = foreach ($disk in $disks) {
    if ($disk.Size -gt 0) {
        $SizeOfDisk = [math]::round($disk.Size/1GB, 0)
        $FreeSpace = [math]::round($disk.FreeSpace/1GB, 0)
        [int]$FreePercent = ($FreeSpace/$SizeOfDisk) * 100
        If ($FreePercent -lt $ThresholdAsPercent) {
            $output += "Drive $($disk.Name) ($($disk.VolumeName)) has low disk space remaining! $($FreeSpace) GB free of $($SizeOfDisk) GB ($($FreePercent) %)"
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

If ($SendAsEmail -eq $true) {
    # Check that email settings have been set
    If (($FromEmail -eq $null) -Or ($ToEmail -eq $null) -Or ($SmtpServer -eq $null)) {
        Write-Output "Cannot send email - Required parameters not set ($FromEmail, $ToEmail, or $SmtpServer)"
        Exit 1
    } else {
        # Start splatting for Email
        $Email = @{
            To = $ToEmail
            From = $FromEmail
            Subject = "Disk usage on $($env:COMPUTERNAME)"
            SmtpServer = $SmtpServer
        }
        If ($Credential) { $Email.add("Credential", $Credential) }
        If ($CC) { $Email.add("Cc", $CC) }
        If ($SMTPPort) { $Email.add("Port", $Port) }

        If (!$output) {
            Write-Output "Nothing to report. No email sent for $($env:COMPUTERNAME)"
            Exit 0
        } else {
            Send-MailMessage @Email -Body $output
        }
    }
}
If ($DisplayDiskUsage -eq $True) {
    $results | Format-Table
}
