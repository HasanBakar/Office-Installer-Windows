If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
  Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
  Exit
}

$Host.UI.RawUI.WindowTitle = "Abu Bakar's Office Windows Installer (Administrator)"
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.PrivateData.ProgressBackgroundColor = "Black"
$Host.PrivateData.ProgressForegroundColor = "White"
function Get-FileFromWeb {
    param ([Parameter(Mandatory)][string]$URL, [Parameter(Mandatory)][string]$File)
    function Show-Progress {
        param ([Parameter(Mandatory)][Single]$TotalValue, [Parameter(Mandatory)][Single]$CurrentValue, [Parameter(Mandatory)][string]$ProgressText, [Parameter()][int]$BarSize = 10, [Parameter()][switch]$Complete)
        $percent = $CurrentValue / $TotalValue
        $percentComplete = $percent * 100
        if ($psISE) { Write-Progress "$ProgressText" -id 0 -percentComplete $percentComplete }
        else { Write-Host -NoNewLine "`r$ProgressText $(''.PadRight($BarSize * $percent, [char]9608).PadRight($BarSize, [char]9617)) $($percentComplete.ToString('##0.00').PadLeft(6)) % " }
    }
    try {
        $request = [System.Net.HttpWebRequest]::Create($URL)
        $response = $request.GetResponse()
        if ($response.StatusCode -eq 401 -or $response.StatusCode -eq 403 -or $response.StatusCode -eq 404) { throw "Remote file either doesn't exist, is unauthorized, or is forbidden for '$URL'." }
        if ($File -match '^\.\\') { $File = Join-Path (Get-Location -PSProvider 'FileSystem') ($File -Split '^\.')[1] }
        if ($File -and !(Split-Path $File)) { $File = Join-Path (Get-Location -PSProvider 'FileSystem') $File }
        if ($File) { $fileDirectory = $([System.IO.Path]::GetDirectoryName($File)); if (!(Test-Path($fileDirectory))) { [System.IO.Directory]::CreateDirectory($fileDirectory) | Out-Null } }
        [long]$fullSize = $response.ContentLength
        [byte[]]$buffer = new-object byte[] 1048576
        [long]$total = [long]$count = 0
        $reader = $response.GetResponseStream()
        $writer = new-object System.IO.FileStream $File, 'Create'
        do {
            $count = $reader.Read($buffer, 0, $buffer.Length)
            $writer.Write($buffer, 0, $count)
            $total += $count
            if ($fullSize -gt 0) { Show-Progress -TotalValue $fullSize -CurrentValue $total -ProgressText " $($File.Name)" }
        } while ($count -gt 0)
    }
    finally {
        $reader.Close()
        $writer.Close()
    }
}

function Install-Office{
                Clear-Host
                Write-Host "Installing: Microsoft Office 2024 LSTC Edition . . ."
                $toolPath = "$env:TEMP\officedeploymenttool_18227-20162.exe"
                $configurationPath = "$env:TEMP\OfficeDeployment\configuration-Office365-x64.xml"
                # download microsoft office
                Get-FileFromWeb -URL "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_18227-20162.exe" -File $toolPath

                # extract office deployment tool
                Start-Process -FilePath $toolPath -ArgumentList "/quiet /extract:$env:TEMP\OfficeDeployment" -Wait

                # create configuration file
                $configureOffice = @"
<Configuration ID="7ccad42d-bf21-44c0-8399-a0d9fba9ba0c">
  <Add OfficeClientEdition="64" Channel="PerpetualVL2024">
    <Product ID="ProPlus2024Volume" PIDKEY="XJ2XN-FW8RK-P4HMP-DKDBV-GCVGB">
      <Language ID="en-gb" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="Outlook" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="FALSE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Property Name="AUTOACTIVATE" Value="1" />
  <Updates Enabled="TRUE" />
  <AppSettings>
    <User Key="software\microsoft\office\16.0\excel\options" Name="defaultformat" Value="51" Type="REG_DWORD" App="excel16" Id="L_SaveExcelfilesas" />
    <User Key="software\microsoft\office\16.0\powerpoint\options" Name="defaultformat" Value="27" Type="REG_DWORD" App="ppt16" Id="L_SavePowerPointfilesas" />
    <User Key="software\microsoft\office\16.0\word\options" Name="defaultformat" Value="" Type="REG_SZ" App="word16" Id="L_SaveWordfilesas" />
  </AppSettings>
</Configuration>
"@
                $configureOffice | Set-Content -Path $configurationPath -Force
                # install microsoft office
                Start-Process -FilePath "$env:TEMP\OfficeDeployment\setup.exe" -ArgumentList "/configure $configurationPath" -Wait
                # activating microsoft office
                Write-Host "Activating Microsoft Office . . ."
                $officePaths = @(
                    "$env:ProgramFiles(x86)\Microsoft Office\Office16",
                    "$env:ProgramFiles\Microsoft Office\Office16"
                )

                foreach ($path in $officePaths) {
                    if (Test-Path $path) {
                        Set-Location -Path $path
                        $licenseFiles = Get-ChildItem -Path "..\root\Licenses16\ProPlus2021VL_KMS*.xrm-ms"
                        foreach ($file in $licenseFiles) {
                            Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /inslic:`"$file`"" -Wait
                        }
                        Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /setprt:1688" -Wait
                        Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /unpkey:6F7TH >nul" -Wait
                        Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /inpkey:FXYTK-NJJ8C-GB6DW-3DYQT-6F7TH" -Wait
                        Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /sethst:107.175.77.7" -Wait
                        Start-Process -FilePath "cscript.exe" -ArgumentList "ospp.vbs /act" -Wait
                    }
                }
}

Install-Office