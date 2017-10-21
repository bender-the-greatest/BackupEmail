###########################################################################################
# This script will send the status of the last backup event. I designed it to work        #
# specifically when any backup task is marked as completed (EventId 14). Simply put,      #
# this script is meant to be run by an event triggered by EventId 14 in the               #
# "Microsoft-Windows-Backup" event log. I have not tested this in other scenarios.        #
# Use at your own risk. To enable SSL encryption, uncomment the line following line       #
# further down in the script:                                                             #
#                                                                                         #
# $client.EnableSsl = 1                                                                   #
#                                                                                         #
# NOTE: This script only works with Vista/2008 and newer systems. Get-WinEvent only works #
#       with these newer versions. For earlier versions, the script will have to be       #
#       modified to use Get-EventLog.                                                     #
###########################################################################################
$mailServer = "server.domain.tld"
$mailServerPort = 25

$mailUser = "mailuser"
$mailUserPassword = "mailuserpassword"

$from = "somebox@somedomain.tld"

## Array of strings representing email addresses
$toArr = "recipient@somedomain.tld"

############################################################################################
# For those unfamiliar with PowerShell, the code below this point should not be modified.  #
# The variables above are the ones that house server and authentication information.       #
############################################################################################

$msg = $null
## Yesterday 12:00 AM
$timespan = [DateTime]::Today.AddDays(-1).ToString("G")

## We should only have to look at the first two, but grab the last 100 in case we have more backup events than normal
$log = get-winevent -maxevents 100 -logname "Microsoft-Windows-Backup" | where { $_.timecreated -ge $timespan }

## For each event $rec in $log... 
foreach ($rec in $log)
{
	## EventId 14 is created every time a backup operation completes, but does not indicate success or failure
	## EventId 1 is created every time a backup operation starts
	## EventId 99 is created every time a new backup schedule is created
	## EventId 4 is created every time a backup completed successfully.
	
	## If you wish to receive success emails, remove && !($rec.Id -eq 4) from the following if statement
	if (!($rec.Id -eq 14) -and !($rec.Id -eq 1) -and !($rec.Id -eq 99) -and !($rec.Id -eq 4)) {
	
		## I used [String]::Concat(String[]) because PS was giving me grief when I did the following:
		## $msg = $rec.TimeCreated + "`n" + $rec.Message
		$msg = [String]::Concat(@($rec.TimeCreated, "`n", $rec.Message))
		
		## Break out of the loop since we are only interested in the status of the last completed backup.
		break
	}
}

## Don't send an email if we don't have a body contentz
if ($msg -eq $null) { 
    echo "No backups caught by script filter (are you filtering out a successful backup?)" > email-not-sent.txt
    exit 
}

$message = New-Object Net.Mail.MailMessage
$client = New-Object Net.Mail.SmtpClient($mailServer, $mailServerPort)

## To enable SSL Encryption, uncomment the following line
#$client.EnableSsl = 1

## For each string in $toArr...
foreach ($rec in $toArr){ $message.To.Add($rec) }

## Subject becomes "MACHINENAME Backup"
$message.Subject = [Environment]::MachineName.ToUpper() + " Backup"
$message.From = $from
$message.Body = $msg

## Uncomment the following line if you need mail authentication
#$client.Credentials = New-Object Net.NetworkCredential($mailUser, $mailUserPassword)
$client.Send($message)
