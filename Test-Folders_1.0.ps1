<#

.SYNOPSIS
    This script is used to test a multitude of directories and to send an email alert if limits are exceeded.

.DESCRIPTION
    This script, which should be initiated at a regular interval via Task Scheduler, tests a multitude of 
    directories and sends an email via DirectSend, if certain limits are exceeded. 

.EXAMPLE
    PS> .\Test-Folders_1.0.ps1

.NOTES
    Version:            1.0
    Author:             Michael J. Mattingly
    Creation Date:      07/16/2020
    Purpose/Change:     This script, which began as "FolderMonitor.ps1", has been renamed as
                        "Test-Folders.ps1", for the purpose of meeting Microsoft's suggested naming 
                        convention (e.g. Verb-Noun pair). Due to said change, I have decided to roll back 
                        the version number to 1.0. Quite a bit of documentation and logic was added to this 
                        version. The script now supports testing multiple paths instead of just one, has 
                        the ability to exclude or include file extensions, has dynamic time limits and 
                        email bodies and subjects, and the Send-EmailAlert() function was rewritten to be 
                        as agnostic as possible, so that dynamic variables could be pulled in from another 
                        function.

#>

[CmdletBinding()]
    
    param(

        # Specifies the directories to be tested.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
            $paths = [ordered]@{
                path1 = '\\[server]\InterfaceShare\AGILE\EXPORT\*';
                path2 = '\\[server]\InterfaceShare\LOFTWARE\*';
                path3 = '\\[server]\InterfaceShare\TRUECOMMERCE\850\*';
                path4 = '\\[server]\EDIPD\EDI945\PROCESS\*';
            }
    )
    
function Get-Excluded {

    <#

    .SYNOPSIS
        The Get-Excluded() function returns an array of file extensions to exclude when monitoring a path. 
        The list may be different, depending upon the $path.
    
    #>

    Write-Host "Running Get-Excluded()..."

    if ($path -eq "path2") {

        $excluded = @("*.dir")  # This is a monitoring file that resides in the directory.

    }

    Write-Host "Excluding the following file type(s): $excluded"

}

function Get-Included {

    <#
    
    .SYNOPSIS
        The Get-Included() function returns an array of file extensions to include when monitoring a path.
        The list may be different, depending upon the $path.

    #>

    Write-Host "Running Get-Included()..."

    if ($path -eq "path1" -or $path -eq "path3" -or $path -eq "path4") {

        $included = @("*.txt")

    } else {

        $included = @("*.csv", "*.pas")

    }

    Write-Host "Including the following file type(s): $included"

}

function Get-TimeLimit {

    <#
    
    .SYNOPSIS
        The Get-TimeLimit() function returns a $timeLimit variable, depending upon the $path that's being 
        testing. The scope of this variable is set to "script" in order for the Get-FileAge() function to 
        use it.
    
    #>

    Write-Host "Running Get-TimeLimit()..."

    if ($path -eq "path1") {

        $script:timeLimit = -60

    } else {

        $script:timeLimit = -120

    }

    Write-Host "The time limit is set to $timeLimit minutes."

}

function Get-BodyAndSubject {

    <#
    
    .SYNOPSIS
        The Get-BodyAndSubject() function returns a $body and $subject variable, depending upon the $path 
        that's being tested. The scope of this variable is set to "script" in order for the Send-EmailAlert() 
        function to use it. 

    #> 

    [CmdletBinding()]
    
    param(

        # Specifies the current data and time.
        [Parameter(Mandatory=$false)]
        [string]
        $dateAndTime = (Get-Date -Format "dddd MM/dd/yyyy HH:mm K")

    )

    Write-Host "Running Get-BodyAndSubject()..."

    if ($path -eq "path1") {

        $script:body = "$dateAndTime. JDE failed to consume $pastDueCount tracking file(s) from the shipping system."
        $script:subject = "[Tracking Import Issue - $pastDueCount Stuck File(s)!]"

    }

    elseif ($path -eq "path2") {

        $script:body = "$dateAndTime. LSP Drop folder has $stuckFiles file(s) stuck there. It may be an issue with LPS not picking up files."
        $script:subject = "Loftware Print Server Issue - $stuckFiles Stuck File(s)!"

    }

    elseif ($path -eq "path3") {

        $script:body = "$dateAndTime. JDE failed to consume $stuckFiles 850 file(s) from the EDI system."
        $script:subject = "EDI 850 Import - $stuckFiles Stuck File(s)!"

    }

    else {

        $script:body = "$dateAndTime. JDE failed to consume $pastDueCount 945 file(s) from the EDI system."
        $script:subject = "EDI 945 Import - $pastDueCount Stuck File(s)!"

    }

    Write-Host "The following email body will be used: $body"
    Write-Host "The following email subject will be used: $subject"

}
function Get-FileCount {

    <#
    
    .SYNOPSIS
        The Get-FileCount() function, using a file limit and file count, calculates how many files, if any, 
        are stuck in one or more monitored directories and passes that information to other functions that 
        use it for the purpose of issuing alerts.

    #>

    [CmdletBinding()]
    
    param(

        # Specifies the file limit.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [int32]
        $fileLimit = 3,

        # Specifies the file count.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [int32]
        $fileCount = ( Get-ChildItem -Path $paths.$path -Exclude $excluded -Include $included -File | 
            Measure-Object ).Count,

        # Specifies the number of stuck files.
        [Parameter(Mandatory=$false)]
        [int32]
        $stuckFiles = ($fileCount - $fileLimit),

        # Specifies the message to display if no files are past due.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $message = "There are no stuck files in {0}." -f $paths.$path

    )

    Write-Host "Running Get-FileCount()..."

    if ($stuckFiles -gt 0) {

        $stuckFiles

        Get-BodyAndSubject

        Send-EmailAlert
           
    } else {

        Write-Host "$message" -ForegroundColor Green

    }
    
}

function Get-FileAge {

    <#
    
    .SYNOPSIS
        The Get-FileAge() function determines whether or not files in one or more directories have been there 
        beyond their alloted time limit and if so, passes this information to other functions that use it for 
        the purpose of issuing alerts.

    #>

    [CmdletBinding()]
    
    param(

        # Specifies the number of files that have been in the folder for more than an hour.
        [Parameter(Mandatory=$false)]
        [int32]
        $pastDueCount = (Get-ChildItem -Path $paths.$path -Include $included | Where-Object {
            $_.CreationTime -lt (Get-Date).AddMinutes($timeLimit) -and -not $_.PSIsContainer}).Count,

        # Specifies whether or not the file is past due (true or false).
        [Parameter(Mandatory=$false)]
        [ValidateSet($true, $false)]
        [bool]
        $isPastDue = [bool](Get-ChildItem -Path $paths.$path -Include $included | Where-Object {
            $_.CreationTime -lt (Get-Date).AddMinutes($timeLimit) -and -not $_.PSIsContainer}),

        # Specifies the message to display if no files are past due.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $message = "There are no past due files in {0}." -f $paths.$path

    )

    Write-Host "Running Get-FileAge()..."

    if (($isPastDue -eq $True)) {

        $timeLimit

        Write-Host "$pastDueCount files are past due!" -ForegroundColor Red

        Get-BodyAndSubject

        Send-EmailAlert
           
    } else {

        Write-Host "$message" -ForegroundColor Green

    }

}
function Send-EmailAlert {

    <#
    
    .SYNOPSIS
        The Send-EmailAlert() function defines static email parameters, pulls in the $body and $subject 
        variables from the Get-BodyAndSubject() function, and sends an email alert to the necessary persons. 
        The function currently uses Send-MailMessage, which is deprecated, but remains functional.

    #>

    [CmdletBinding()]
    
    param(
    
        # Specifies the source email address. This can be fake.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        $from = '[user]@[domain].com',  

        # Specifies the destination email address.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        #$to = '[user]@[domain].com',
        
        # Specifies the email priority level. Choose Low, Medium, or High.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Low", "Normal", "High")]
        [string]
        $priority = 'High',
        
        # Specifies the SMTP server. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $smtpServer = '[domain]-com.mail.protection.outlook.com',
        
        # Specifies the outgoing email port. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $port = '25',
        
        # Specifies that Secure Socket Layer (SSL) must be used. Don't change this.
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet($true, $false)]
        [bool]
        $useSSL = $true

    )

    Write-Host "Running Send-EmailAlert()..."

    $emailParams = @{

        from = $from
        to = $to
        subject = $subject          # This comes in from Get-BodyAndSubject().
        body = $body                # This comes in from Get-BodyAndSubject().
        priority = $priority
        smtpServer = $smtpServer
        port = $port
        useSSL = $useSSL

    }

    try {

        $emailParams

        Send-MailMessage @emailParams -ErrorAction Stop
    
    } catch {
        
        Write-Host 'Error! The alert email failed to send.' -ForegroundColor Red

    }

}

foreach ($path in $paths.Keys) {

    Write-Host "Testing the following path..." $paths.$path

    Get-Included

    if ($path -eq "path1" -or $path -eq "path4") {

        Get-TimeLimit

        Get-FileAge

    } else {

        if ($path -eq "path2") {

            Get-Excluded

        }

        Get-FileCount

    }

}