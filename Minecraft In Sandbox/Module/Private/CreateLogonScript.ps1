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
    $wdg_install_dir = 'C:\users\wdagutilityaccount\desktop\minecraft_conf'
    Write-Verbose "Saved logon script to $logon_cmd, this will be run upon starting Sandbox."
    New-Item -Force -Path $logon_cmd -ItemType File | Out-Null;
    # TODO: INSTALL JAVA HERE!!
    Set-Content -Path $logon_cmd -Value @"
java -Xmx1024M -Xms1024M -jar $wdg_install_dir\$minecraft_installer nogui
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