#Requires -RunAsAdministrator
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