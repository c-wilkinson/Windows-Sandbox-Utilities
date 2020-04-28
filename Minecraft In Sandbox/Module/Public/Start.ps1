#Requires -RunAsAdministrator
function Start
{
<#
    .SYNOPSIS
        Entry point for the process
    .DESCRIPTION
        This function is used to create and start a Minecraft server instance.
#>    
    [cmdletbinding()]
    param(
    )
    try
    {
        Write-Verbose 'Start process';
        $ProgressPreference = 'SilentlyContinue'; #Progress bar makes things way slower
        Write-Output 'Verify host system...';
        $bios = VerifyBios;
        if (-not $bios -or $bios -eq $false)
        {
            throw 'ERROR: Please Enable Virtualization capabilities in your BIOS settings...';
        }
    
        $sandbox = VerifySandbox;
        if (-not $sandbox -or $sandbox -eq $false)
        {
            throw 'Please reboot to finish installing Windows Sandbox, then re-run this script...';
        }
        
        Write-Output 'Download minecraft server...';
        $minecraft_installer_fullname = GetMineCraft;
        Write-Verbose "Downloaded $minecraft_installer_fullname";
        Write-Output 'Download JRE...';
        $java_installer_fullname = GetJava;
        Write-Verbose "Downloaded $java_installer_fullname";
        Write-Output 'Create logon script...';
        CreateLogonScript -java_installer $java_installer_fullname -minecraft_installer $minecraft_installer_fullname;
        Write-Output 'Start sandbox...';
        $config = "$env:USERPROFILE\minecraft_conf\minecraft_sandbox.wsb";
        Write-Verbose "Start-Process 'C:\WINDOWS\system32\WindowsSandbox.exe' -ArgumentList '$config';";
        $proc = Start-Process 'C:\WINDOWS\system32\WindowsSandbox.exe' -ArgumentList $config;
        do 
        {
            start-sleep -Milliseconds 500;
        }
        until ($proc.HasExited);
    }
    catch
    {
        $ErrorMessage = $_.Exception.Message;
        Write-Error $ErrorMessage;
    }
}