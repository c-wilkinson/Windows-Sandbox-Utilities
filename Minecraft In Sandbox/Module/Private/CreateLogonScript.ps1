#Requires -RunAsAdministrator
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