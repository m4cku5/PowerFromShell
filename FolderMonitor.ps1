function Send-EmailAlert {

    [CmdletBinding()]

    param(

        [Parameter(Mandatory=$false)]
        [Int32]
        $StuckFiles = ($FileCount - $FileLimit),

        [Parameter(Mandatory=$false)]
        [string]
        $DateAndTime = (Get-Date -Format "dddd MM/dd/yyyy HH:mm K"),
    
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        $From = '<username>@<domain>.com',  
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Net.Mail.MailAddress]
        $To = '<username>@<domain>.com', 
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Subject = "ERROR: $StuckFiles FILES STUCK",
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Body = "$DateAndTime. There are $StuckFiles files that are stuck. Please review and resolve immediately.",
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Low", "Normal", "High")]
        [string]
        $Priority = 'High',
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SmtpServer = '<domain>-com.mail.protection.outlook.com',
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Port = '25',
        
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

function Get-FileCount {

    [CmdletBinding()]
    
    param(

        [Parameter(Mandatory=$false)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]
        $Path = "<folder-to-monitor>",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Int32]
        $FileLimit = 3,

        $FileCount = ( Get-ChildItem $Path | Measure-Object ).Count

    )

    if ($FileCount -gt $FileLimit) {

        Send-EmailAlert

    }
    
}

Get-FileCount