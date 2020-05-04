<#

.SYNOPSIS
    This script is used to locate files in a $Path that match a particular pattern, $Date, and range of 
    $Hours, and to send an email alert if a file wasn't created every hour during said period.

.DESCRIPTION
    This script, which should be initiated each morning via Task Scheduler, searches a particular
    directory ($Path) for all files that were created on a particular date ($Date), within a particular
    range of hours ($Hours), and that match a particular pattern. It then determines whether or not,
    within the resulting files, one of them was created for every hour on said date, and if not,
    utilizes Direct Send to send an email alert to ($To) the required persons.

.PARAMETERS

.EXAMPLE
    PS> .\FileTimeMonitor.ps1

.INPUTS
    None. You can't pipe objects to FileTimeMonitor.ps1.

.OUTPUTS
    None. FileTimeMonitor.ps1 doesn't generate any output.

.LINK
    None.

.NOTES
    Version:            1.0
    Author:             Michael J. Mattingly
    Creation Date:      05/04/2020
    Purpose/Change:     Initial script development.

#>

function Get-Files {

    [CmdletBinding()]
    
    param(

        # Specifies the directory to be monitored.
        [Parameter(Mandatory=$false)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [String]
        $Path = "<directory>",

        # Specifies the date of files to monitor.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Date = (Get-Date).AddDays(-1).ToString('yyyyMMdd'),
        
        # Specifies the hour range and pattern of files to monitor.
        [Parameter(Mandatory=$false)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        $Hours = (Get-ChildItem -Path $Path -Include "850_$($Date)*.txt" | 
            ForEach-Object {(Get-Date $_.CreationTime).Hour} | Sort-Object | Get-Unique)

    )

    $Count = $null

    for ($Hour = 0; $Hour -lt 24; $Hour++) {

        if ($Hour -in $Hours) {

            Write-Host "There's at least one file for $Hour o'clock for $Date." -ForegroundColor Green

        } else {

            Write-Host "There's no file present for $Hour o'clock for $Date." -ForegroundColor Red
            $Count++
        }

    }

    if ($Count -gt 0) {

        Write-Host "There are $Count files missing. An email alert has been sent."
        
        Send-EmailAlert

    }

}

function Send-EmailAlert {

    [CmdletBinding()]

    param(
    
        # Specifies the source email address. This can be fake.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        $From = '<username>@<domain>',  
        
        # Specifies the destination email address.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        $To = '<username>@<domain>',

        # Specifies the email subject.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Subject = "There are missing files in $Path",
        
        # Specifies the email body.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Body = "$DateAndTime. There are missing files in $Path. Please resolve immediately.",
        
        # Specifies the email priority level. Choose Low, Medium, or High.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Low", "Normal", "High")]
        [string]
        $Priority = 'High',
        
        # Specifies the SMTP server. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SmtpServer = '<domain>-com.mail.protection.outlook.com',
        
        # Specifies the outgoing email port. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Port = '25',
        
        # Specifies that Secure Socket Layer (SSL) must be used. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet($true, $false)]
        [bool]
        $UseSsl = $true

    )

    $emailParams = @{

        From = $From
        To = $To
        Subject = $Subject
        Body = $Body
        Priority = $Priority
        SmtpServer = $SmtpServer
        Port = $Port
        UseSsl = $UseSsl

    }

    try {

        Send-MailMessage @emailParams -ErrorAction Stop
    
    } catch {
        
        Write-Host 'Error!'

    }

}

Get-Files
