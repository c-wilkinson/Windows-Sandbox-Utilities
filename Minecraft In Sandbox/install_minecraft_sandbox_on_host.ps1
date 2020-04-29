#Requires -RunAsAdministrator

[cmdletbinding()]
    param(
    
)

function CreateLogonScript
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)][string]$java_installer,
        [Parameter(Mandatory=$true)][string]$minecraft_installer
    )
    Write-Verbose 'Creating init command...'
    $working_dir = "$env:USERPROFILE\minecraft_conf";
    $logon_cmd = "$working_dir\init.cmd"
    $minecraft_cmd = "$working_dir\minecraft.cmd"
    $wdg_install_dir = 'C:\users\wdagutilityaccount\desktop\minecraft_conf'
    Write-Verbose "Saved logon script to $logon_cmd, this will be run upon starting Sandbox."
    New-Item -Force -Path $logon_cmd -ItemType File | Out-Null;
    Set-Content -Path $logon_cmd -Value @"
cd "C:\Program Files"
md minecraft
xcopy $wdg_install_dir\$minecraft_installer "C:\Program Files\minecraft\$minecraft_installer"* /y /r /f
start $wdg_install_dir\$java_installer /s ADDLOCAL="ToolsFeature,SourceFeature,PublicjreFeature"
goto WAITLOOP
:WAITLOOP
if exist "C:\ProgramData\Oracle\Java\" goto INSTALLCOMPLETE
ping -n 6 127.0.0.1 > nul
goto WAITLOOP
:INSTALLCOMPLETE
start $wdg_install_dir\minecraft.cmd
"@;
    Write-Verbose "Saved minecraft server start to $minecraft_cmd, this will be run post java installation."
    New-Item -Force -Path $minecraft_cmd -ItemType File | Out-Null;
    Set-Content -Path $minecraft_cmd -Value @"
cd "C:\Program Files\minecraft"
echo eula=true > eula.txt
md logs
java -Xmx1024M -Xms1024M -jar "C:\Program Files\minecraft\$minecraft_installer" nogui
pause
"@;
    # Create the Sandbox configuration file with the new working dir & LogonCommand.
    $sandbox_conf = "$working_dir\minecraft_sandbox.wsb";
    Write-Verbose "Creating sandbox configuration file to $sandbox_conf";
    New-Item -Force -Path $sandbox_conf -ItemType File | Out-Null;
    Set-Content -Path $sandbox_conf -Value @"
<Configuration>
    <VGpu>Enable</VGpu>
    <MappedFolders>
        <MappedFolder>
            <HostFolder>$working_dir</HostFolder>
            <ReadOnly>true</ReadOnly>
        </MappedFolder>
    </MappedFolders>
    <LogonCommand>
        <Command>$wdg_install_dir\init.cmd</Command>
    </LogonCommand>
</Configuration>
"@;
}

function GetJava
{
    [cmdletbinding()]
    param(
    )
    if ([Environment]::Is64BitOperatingSystem)
    {
        $installer=(Invoke-WebRequest -UseBasicParsing https://www.java.com/en/download/manual.jsp).Content |     ForEach-Object{[regex]::matches($_, '(?:<a title="Download Java software for Windows \(64-bit\)" href=")(.*)(?:">)').Groups[1].Value};
    }
    else
    {
        $installer=(Invoke-WebRequest -UseBasicParsing https://www.java.com/en/download/manual.jsp).Content | ForEach-Object{[regex]::matches($_, '(?:<a title="Download Java software for Windows Online" href=")(.*)(?:">)').Groups[1].Value};
    }
    
    # Check if the installer is present, download otherwise.
    $installer_size =(Invoke-WebRequest $installer -Method Head -UseBasicParsing).Headers.'Content-Length';
    $working_dir = "$env:USERPROFILE\minecraft_conf";
    $install_fname = "jre.exe";
    $install_fullname = "$working_dir\$install_fname";
    if (!(test-path "$install_fullname") -or (Get-ChildItem "$install_fullname").Length -ne $installer_size ) 
    {
        Remove-Item "$install_fullname" -Force -ErrorAction SilentlyContinue;
        Write-Verbose "Downloading latest Java executable: $install_fullname";
        Write-Verbose "Saving to $install_fullname...";
        New-Item -ItemType Directory -Force -Path $working_dir | Out-Null;
        Invoke-WebRequest -Uri $installer -OutFile "$install_fullname";
    }
    
    return $install_fname;
}

function GetMineCraft
{
    [cmdletbinding()]
    param(
    )
    Write-Verbose 'Checking for latest version of minecraft...';
    $jsonVersions = Invoke-WebRequest -Uri https://launchermeta.mojang.com/mc/game/version_manifest.json | ConvertFrom-Json;
    $minecraftLatestVersion = $jsonVersions.latest.release;
    Write-Verbose "Detected latest minecraft release is $minecraftLatestVersion";
    $minecraftVersions = $jsonVersions.versions;
    $jsonUrlLatestVersion = $minecraftVersions | Where-Object id -eq $minecraftLatestVersion;
    $jsonUrlLatestVersion = $jsonUrlLatestVersion.url;
    Write-Verbose "Detected latest minecraft release URL $jsonUrlLatestVersion";
    Write-Verbose 'Download manifest';
    $jsonLatestVersion = Invoke-WebRequest -Uri $jsonUrlLatestVersion | ConvertFrom-Json;
    Write-Verbose 'Get the server download url';
    $installer = $jsonLatestVersion.downloads.server.url;
    $installer_size =(Invoke-WebRequest $installer -Method Head -UseBasicParsing).Headers.'Content-Length';
    # Check if the installer is present, download otherwise.
    $working_dir = "$env:USERPROFILE\minecraft_conf";
    $install_fname = "minecraft_server." + $minecraftLatestVersion + ".jar";
    $install_fullname = "$working_dir\$install_fname";
    if (!(test-path "$install_fullname") -or (Get-ChildItem "$install_fullname").Length -ne $installer_size ) 
    {
        Remove-Item "$install_fullname" -Force -ErrorAction SilentlyContinue;
        Write-Verbose "Downloading latest minecraft executable: $install_fullname";
        Write-Verbose "Saving to $install_fullname...";
        New-Item -ItemType Directory -Force -Path $working_dir | Out-Null;
        Invoke-WebRequest -Uri $installer -OutFile "$install_fullname";
    }
    
    return $install_fname;
}

function VerifyBios
{
<#
    .SYNOPSIS
        Check BIOS
    .DESCRIPTION
        This function is used to ensure that virtualization is enbaled in BIOS.
    .EXAMPLE
        C:\> VerifyBios;
#>   
    [cmdletbinding()]
    [OutputType([bool])]
    param ()
    # Ensure that virtualization is enbaled in BIOS.
    Write-Output 'Verifying that virtualization is enabled in BIOS...'
    if ((Get-CimInstance Win32_ComputerSystem).VirtualizationFirmwareEnabled -eq $false) {
        Write-Output 'ERROR: Please Enable Virtualization capabilities in your BIOS settings...'
        return $false
    }

    # Ensure that virtualization is enbaled in Windows 10.
    Write-Output 'Verifying that virtualization is enabled in Windows 10...'
    if ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent -eq $false) {
        Write-Output 'ERROR: Please Enable Hyper-V in your Control Panel->Programs and Features->Turn Windows features on or off'
        return $false
    }
    
    return $true;
}

function VerifySandbox
{
<#
    .SYNOPSIS
        Check Windows Feature is enabled
    .DESCRIPTION
        This function is used to ensure that Windows Sandbox has been enabled
    .EXAMPLE
        C:\> VerifySandbox;
#>   
    [cmdletbinding()]
    [OutputType([bool])]
    param ()
    Write-Verbose 'Checking to see if Windows Sandbox is installed...';
    try
    {
        If ((Get-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -Online).State -ne 'Enabled') 
        {
            Write-Verbose 'Windows Sandbox is not installed, attempting to install it (may require reboot)...';
            if ((Enable-WindowsOptionalFeature -FeatureName 'Containers-DisposableClientVM' -All -Online -NoRestart).RestartNeeded) 
            {
                Write-Verbose 'Please reboot to finish installing Windows Sandbox, then re-run this script...'
                return $false;
            }
        
            return $true;
        }
        else 
        {
            Write-Verbose 'Windows Sandbox already installed.';
            return $true;
        }
    }
    catch
    {
        Write-Error 'ERROR: Please Enable Virtualization capabilities in your BIOS settings ,then re-run this script...';
        return $false;
    }
}
    try
    {
        Write-Verbose 'Start process';
        $ProgressPreference = 'SilentlyContinue'; #Progress bar makes things way slower
        Write-Output 'Verify host system...';
        $bios = VerifyBios;
        if (-not $bios -or $bios -eq $false)        {
            throw 'ERROR: Please Enable Virtualization capabilities in your BIOS settings...';
        }
    
        $sandbox = VerifySandbox;
        if (-not $sandbox -or $sandbox -eq $false)        {
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

