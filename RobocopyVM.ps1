function checkHypervisorStatus(){
    Clear-Host
    Start-Sleep -Seconds 2
    Write-Host "Welcome $env:USERNAME`n" -ForegroundColor Green -BackgroundColor Black
    $proc_array = @(Get-Process | where {$_.Name -match "^vmware$" -or $_.Name -match "^vmware-vmx$"} | select Name, Id)
    if ($proc_array.Length -ge 1) {
        Write-Host "VmWare Workstation appears to currently be running.`nPlease close the app prior to running backups" -ForegroundColor Yellow
        Foreach ($proc in $proc_array) {
            Write-Host "Process: [$proc]" -ForegroundColor Yellow -BackgroundColor Black
        }
        return $false
    }
    else {
        return $true # Move onto the job setup step
    }
}


function createCopyJob(){
    $machine_name = Read-Host "Enter the name of the VM (abbreviaton okay)"
    $source_folder = Read-Host -Prompt "Enter the source folder of the VM"
    $dest_folder = Read-Host -Prompt "Now, enter the destination folder for the backup"
    if ((Test-Path $source_folder) -And (Test-Path $dest_folder)){
        $log_folder = Join-Path (Split-Path "$dest_folder") "\Task-Logs"
        $log_file = ("$machine_name-{0}.txt" -f (Get-Date -UFormat %m-%d-%Y))
        Write-Host "`nSuccessfully located specified folders`n`n"
        Write-Host "`t*****Confirmation*****" -ForegroundColor Green -BackgroundColor Black
        Write-Host "`tSource Folder is: $source_folder`n`tDestination Folder is: $dest_folder" -ForegroundColor Cyan -BackgroundColor Black
        Write-Host "`tLog file will be located at: $log_folder\$log_file`n" -ForegroundColor Cyan -BackgroundColor Black
        $confirm = Read-Host "Does this sound good (y\n)? "
        if ( $confirm -eq "y") {
            $copyObj = [PSCustomObject]@{
                Machine = $machine_name
                Source = $source_folder
                Dest = $dest_folder
                LogFolder = $log_folder
                LogFile = $log_file
        }
            return $copyObj
        }
        else {
            Write-Host "Okay, run again to change desired specifications" -ForegroundColor Cyan
            return $false
        }
    }
    else {
        Write-Host "ERROR - One of the specified locations cannot be found." -ForegroundColor Red -BackgroundColor Black
        return $false
    }
}

$proceed = checkHypervisorStatus # Is Vmware running??
if (! $proceed) {
    Write-Host "Please close all running instances of VMware and run the script again." -ForegroundColor Red -BackgroundColor Black
    Exit("99")
}


$copyParams = createCopyJob # Did we successfully complete the job object initialization and confirm with 'y'??

if (! $copyParams) {
    Write-Host "There was an issue validating data to set the Robocopy job. Please run script again." -ForegroundColor Red -BackgroundColor Black
    Exit("99")
}
else {
    Clear-Host
    Write-Host "The parameters for $env:USERNAME's ROBOCOPY job are:`n"
    Write-Host "Virtual Machine:`t" -ForegroundColor Cyan $copyParams.Machine
    Write-Host "Source:`t`t" -ForegroundColor Cyan $copyParams.Source
    Write-Host "Destination:`t" -ForegroundColor Cyan $copyParams.Dest
    Write-Host "Log Folder:`t" -ForegroundColor Cyan $copyParams.LogFolder
    Write-Host "Log File:`t" -ForegroundColor Cyan $copyParams.LogFile
    # Reassign Machine prop here for simplicity with regex..
    $machine_name = $copyParams.Machine
    $old_log = dir $copyParams.LogFolder | findstr.exe /R "$machine_name.*\.txt" | Measure-Object

    if ( $old_log.Count -ge 1 ){
        Write-Host "`nPrevious log found for $machine_name`nWill overwrite this with updated log." -Fore Yellow -BackgroundColor Black
        Get-ChildItem -Path $copyParams.LogFolder | where {$_.Name -like "$machine_name*.txt"} | Remove-Item -Force
    }
    # And reassign obj props to vars here for simplicity with injection into Robocopy args...
    $log_folder = $copyParams.LogFolder
    $log_file = $copyParams.LogFile
    Write-Host "Will now run Robocopy using custom parameters on behalf of $env:USERNAME`nPlease wait..." -ForegroundColor Yellow -BackgroundColor Black
    Robocopy.exe $copyParams.Source $copyParams.Dest /E /ZB /PURGE /R:5 /W:5 /NP /LOG:"$log_folder\$log_file"
}
