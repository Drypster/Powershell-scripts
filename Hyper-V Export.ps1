### Resets variables
$CurrentState = $null
$Count = $null
$BackupCount = $null

###Get todays date and replace / with - to use in directory name.
$Date = Get-Date -UFormat "%d/%m/%Y"
$Date = $date -replace "/", "-"

###Set location to where the backups will be located. Below this is the logging location set.
#General settings. Set backuplocation, logging location and the amount of backups you want to keep.
$Location = "C:\Backup\VM\"
$LogLocation = "$($Location)$($Date)\Logs\"
$BackupsToKeep = 4

cd $Location

### Start transcription log. Will automatically create the required directories if they do not already exist
Start-Transcript -Path "$($LogLocation)Backup Log $($Date).log"

write-host "Backup location is: $($Location)$($Date)\" `n 


$VM = get-vm
foreach ($i in $VM)
{

    ### Resets variables
    $CurrentState = $null
    $Count = $null
    $BackupCount = $null

    write-host "Working with VM: $($i.Name)"

    ### Gets the start time of the backup process
    $StartStopTime = Get-Date -UFormat "%R:%S"
    write-host "Started at $($StartStopTime)"
    
    ###Checks if the VM is currently running
    if ($i.State -eq 'Running')
    {
        ### Takes note of the VM's runng state so it can boot it up after the backup process has ended
        $CurrentState = $i.State

        write-host "VM $($i.Name) is running." `n "Sending shut down command"
        stop-vm $i.Name

        ###Waits for the VM to shut down or continue on if it does not shut down within 5 minutes
        Do
        {
            Sleep 5
            $Status = (Get-VM $i.Name).State
            $Count = $Count+1

            if ($Status -eq 'Off')
            {
                write-host "VM $($i.Name) Shut down successfully"
            }
        }
        Until ($Status -eq "Off" -Or $Count -eq 60)
        
        ### If the VM did not shut down successfully, it is noted in the transcript log as well as a seperate failed log
        if ($i.State -ne 'Off')
        {
            write-host "VM $($i.Name) did not shut down in 5 min."
            write-Output "$($i.Name) Failed shutdown and a manual export is needed. Current VM state is: $($i.State)" | Out-file -FilePath "$($LogLocation)Failed backup $($Date).log" -Append
            Write-host "The VM name has been logged in the 'Failed backup $($Date).log' and a manual export is needed" `n
        }
    }
    
    ### Exports the VM if the VM is in it's off state
    if ($i.State -eq 'Off')
    {
        write-host "Exporting VM $($i.Name)" `n
        Export-VM -Name $i.Name -Path "$($Location)$($Date)"    
    }

    ### If the VM is in a diffrent state than running or off it gets noted in the transcript log as well as the seperate failed log
    if ($i.State -ne 'Off' -And $i.State -ne 'Running')
    {
        write-Output "$($i.Name) is currently not in a 'Running' Or 'Off' state and an export was not created. Current VM state is: $($i.State)" | Out-file -FilePath "$($LogLocation)Failed backup $($Date).log" -Append
        write-host "VM $($i.Name) State is currently not 'Running' or 'Off' This has been logged in the 'Failed backup $($Date).log' Current VM state is: $($i.State)"
    }

    ### If the VM was running when the backup process started, a start command is sent to bott it back up 
    if ($CurrentState -eq 'Running')
    {
        Write-Host "Sending start command to VM $($i.Name)"
        Start-VM "$($i.Name)"
    }

    ### Gets the end time of the backup process
    $StartStopTime = Get-Date -UFormat "%R:%S"
    write-host "Ended at $($StartStopTime)"

} 

#Get current backups and count them
$Backups = Get-ChildItem $Location | Sort CreationTime
$BackupCount = $Backups.Count

#Keeps track of how many backups were deleted
$BackupsDeleted = 0

#If there are more backups than specified in $BackupsToKeep delete the old ones
write-host "Checking if there are more than $($BackupsToKeep) backups..."
if ($BackupCount -gt $BackupsToKeep)
{

    #Do this until you only have the backups specified in $BackupsToKeep
    do {
        
        #Select the backup to delete and then delete it
        $DeleteBackup = $Backups | Select -First 1
        Remove-Item -Recurse -Force "$($Location)$($DeleteBackup)"
        $BackupsDeleted = $BackupsDeleted+1
        Write-Host "Deleted backup: $($DeleteBackup)"

        #Get current backups and count them
        $Backups = Get-ChildItem $Location | Sort CreationTime
        $BackupCount = $Backups.Count

    }
    while ($BackupCount -gt $BackupsToKeep)
}

Write-Host "Backup cleanup completed.  A total of $($BackupsDeleted) Backup(s) were deleted"

Stop-Transcript