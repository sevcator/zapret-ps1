# Script title
Clear-Host
Write-Host @"
                            _   
                           | |  
    ______ _ _ __  _ __ ___| |_ 
   |_  / _` | '_ \| '__/ _ \ __|
    / / (_| | |_) | | |  __/ |_ 
   /___\__,_| .__/|_|  \___|\__|
            | |                 
            |_|                 

 ** sevcator.github.io & bol-van **
"@

# Script variables
$zapretDir = "$env:windir\Zapret" # Directory where is software is installed
$system32Dir = "$env:windir\System32" # PATH Directory to use zapret as system command
$tacticsDir = "$zapretDir\tactics" # Directory to create and download tactics
$initialDirectory = Get-Location # For back to directory when script is done

# Check Administrator rights
function Check-Admin {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Check-Admin)) {
    Write-Host "! Run PowerShell as administrator rights!"
    return
}

# Check Windows architecture
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Host "* Windows architecture is not 64-bit!"
    return
}
Write-Host "- Windows architecture is 64-bit"

# Check Windows version and enable Test Mode if needed
$osVersion = [Environment]::OSVersion.Version
Write-Host "- Windows version is $osVersion"
if ($osVersion.Major -lt 10) {
    Write-Host "* Enabling Test Mode for Windows less than 10" -ForegroundColor Yellow
    $testMode = bcdedit /enum | Select-String "testsigning" -Quiet
    
    if (-not $testMode) {
        bcdedit /set loadoptions DISABLE_INTEGRITY_CHECKS | Out-Null
        bcdedit /set TESTSIGNING ON | Out-Null
        Write-Host "* Reboot the system and run this script to countinue the installation" -ForegroundColor Yellow
        exit 1
    }
}

# Terminate and destroy old copies or/and softwares to bypass blocking via DPI 
Write-Host "- Terminating processes"
@("GoodbyeDPI", "winws", "zapret") | ForEach-Object {
    Get-Process -Name $_ -ErrorAction SilentlyContinue | Stop-Process -Force
}
Write-Host "- Destroying services"
@("zapret", "winws1", "goodbyedpi", "windivert", "windivert14") | ForEach-Object {
    $serviceName = $_
    try {
        if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            
            $null = cmd /c "sc.exe stop $serviceName 2>&1"
            Start-Sleep -Seconds 3
            
            $null = cmd /c "sc.exe delete $serviceName 2>&1"
            Start-Sleep -Seconds 1
            
            if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
                $null = cmd /c "sc.exe delete $serviceName 2>&1"
            }
        }
    } catch {

    }
}

# Clean DNS Cache
Write-Host "- Flushing DNS cache"
try {
    ipconfig /flushdns | Out-Null
} catch {
    Write-Host "! Failed to flush DNS cache: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Function to download files
function Download-Files($files, $baseUrl, $destination) {
    foreach ($file in $files) {
        try {
            $url = "$baseUrl/$file"
            $outFile = Join-Path $destination $file
            Invoke-WebRequest -Uri $url -OutFile $outFile -ErrorAction Stop
        } catch {
            Write-Host "* Error to download $file : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
$baseUrl = "https://github.com/sevcator/zapret-ps1/raw/refs/heads/main/files"
$tacticsUrl = "$baseUrl/tactics"

# Create directories
if (-not (Test-Path $zapretDir)) {
    New-Item -Path $zapretDir -ItemType Directory | Out-Null
}
if (-not (Test-Path $tacticsDir)) {
    New-Item -Path $tacticsDir -ItemType Directory | Out-Null
}

# Add exclusion to Defender
$exclusionPath = "$zapretDir\winws.exe"
Write-Host "- Adding Microsoft Defender exclusion"
if (-not (Test-Path $exclusionPath)) {
    New-Item -Path $exclusionPath -ItemType File -ErrorAction SilentlyContinue | Out-Null
}
try {
    Add-MpPreference -ExclusionPath $exclusionPath -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
} catch {
    Write-Host "* Error adding Microsoft Defender exclusion, this may happen if Defender " -ForegroundColor Yellow
}

# Download files
Write-Host "- Downloading files"
$baseFiles = @(
    "WinDivert.dll", "WinDivert64.sys", "cygwin1.dll", "winws.exe",
    "ipset-discord.txt", "list.txt", "list-exclude.txt",
    "tls-google.bin", "quic-google.bin", "zapret.cmd", "zapret-redirect.cmd"
)
$tacticsFiles = @(
    "autohosts-bol-van.txt", "autohosts-flowseal-alt-2.txt",
    "autohosts-flowseal-alt-3.txt", "autohosts-flowseal-alt-4.txt",
    "autohosts-flowseal-alt-5.txt", "autohosts-flowseal-alt-6.txt",
    "autohosts-flowseal-alt.txt", "autohosts-flowseal-mgts-2.txt",
    "autohosts-flowseal-mgts.txt", "autohosts-flowseal.txt",
    "hosts-bol-van.txt", "hosts-flowseal-alt-2.txt",
    "hosts-flowseal-alt-3.txt", "hosts-flowseal-alt-4.txt",
    "hosts-flowseal-alt-5.txt", "hosts-flowseal-alt-6.txt",
    "hosts-flowseal-alt.txt", "hosts-flowseal-mgts-2.txt",
    "hosts-flowseal-mgts.txt", "hosts-flowseal.txt"
)
Download-Files $baseFiles $baseUrl $zapretDir
Download-Files $tacticsFiles $tacticsUrl $tacticsDir

# Make zapret usable as system command
Move-Item "$zapretDir\zapret-redirect.cmd" "$system32Dir\zapret.cmd" -Force | Out-Null

# Pick a default tactic for DPI modification
$ZAPRET_ARGS = Get-Content "$tacticsDir\autohosts-bol-van.txt" -Raw
$ZAPRET_ARGS = $ZAPRET_ARGS.Replace("%zapretDir%", $zapretDir)

# Create service
Write-Host "- Creating service"
try {
    sc.exe create winws1 binPath= "$zapretDir\winws.exe $ZAPRET_ARGS" start= auto DisplayName= "zapret" type= own | Out-Null
    sc.exe description winws1 "Bypass internet censorship via modification DPI by bol-van and sevcator.github.io" | Out-Null
    sc.exe start winws1 | Out-Null
} catch {
    Write-Host ("! Failed to create or start service: {0}" -f $_.Exception.Message) -ForegroundColor Red
}

# Final steps
Write-Host "- Done!"
Set-Location $initialDirectory
