#Requires -Version 5.1
<#
.SYNOPSIS
  Build and deploy lexmora-webui on the local Docker daemon.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$ContainerName = 'lexmora-webui'
$ComposeFile = Join-Path $ScriptDir 'docker-compose.yml'
$ImageName = 'lexmora-webui'
$ImageTag = 'latest'
$ContainerPort = 80
$SafePortMin = 30000
$SafePortMax = 32767

function Write-Color([string]$Message, [string]$Color = 'White') {
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    $userProfile = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
    @"
run-on-docker-local.ps1 - deploy $ContainerName on local Docker

USAGE:
  .\run-on-docker-local.ps1 [flags]

FLAGS:
  --ssh-string=<alias>       SSH alias; null -> local daemon (default: null)
  --delete-image=<no|yes>    Remove built images during teardown (default: null -> no)
  --delete-volume=<no|yes>   Remove volumes before recreate (default: null -> no)
  --internal-port=<port>     Host port mapped to the container (default: null -> random 30000-32767)
  --volume-dir=<path>        Bind-mount data directory (default: null -> $userProfile/docker/$ContainerName)
  --volume-name=<name>       Named Docker volume (default: null -> $ContainerName-volume)
  --network-name=<name>      Docker network (default: null -> lexmora-net)
  --help                     Show this help

EXAMPLES:
  .\run-on-docker-local.ps1
  .\run-on-docker-local.ps1 --delete-volume=yes
  .\run-on-docker-local.ps1 --internal-port=30042

NOTES:
  - Use SSH config alias only; do not include "ssh" in --ssh-string.
  - For local deploy, omit --ssh-string (or leave null). Non-null values are ignored with a warning.
  - Null defaults resolve as described in FLAGS.
  - Truthy values for yes/no flags: yes, true, 1, y, on.
  - Default internal port is picked randomly from 30000-32767 if not specified.
  - This stack expects external network (default compose: lexmora-net). Pass --network-name to override.
"@ | Write-Host
}

function Get-FlagValue {
    param([string[]]$ArgList, [string]$Name)
    foreach ($a in $ArgList) {
        if ($a -match "^--$Name=(.*)$") { return $Matches[1] }
        if ($a -eq "--$Name") {
            throw "Flag --$Name requires a value. Use --$Name=<value>."
        }
    }
    return $null
}

function Test-Truthy([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return @('yes', 'true', '1', 'y', 'on') -contains $Value.ToLowerInvariant()
}

function Test-PortFree([int]$Port) {
    try {
        $inUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        return -not $inUse
    }
    catch {
        $netstat = & netstat -ano 2>$null | Select-String -Pattern ":$Port\s"
        return -not $netstat
    }
}

function Get-RandomFreePort {
    $rng = [System.Random]::new()
    for ($i = 0; $i -lt 50; $i++) {
        $candidate = $rng.Next($SafePortMin, $SafePortMax + 1)
        if (Test-PortFree $candidate) { return $candidate }
    }
    throw "Could not find a free port in $SafePortMin-$SafePortMax"
}

function Ensure-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI is not available. Start Docker Desktop / daemon.'
    }
}

function Ensure-Network([string]$Name) {
    $exists = & docker network ls --format '{{.Name}}' | Where-Object { $_ -eq $Name }
    if (-not $exists) {
        Write-Color "==> Creating network $Name" 'Cyan'
        & docker network create $Name | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to create network $Name" }
    }
    else {
        Write-Color "==> Network exists: $Name" 'DarkGray'
    }
}

if ($args -match '^(--help|-h|/\?)$') { Show-Help; exit 0 }

try {
    $SshString = Get-FlagValue -ArgList $args -Name 'ssh-string'
    $DeleteImage = Get-FlagValue -ArgList $args -Name 'delete-image'
    $DeleteVolume = Get-FlagValue -ArgList $args -Name 'delete-volume'
    $InternalPort = Get-FlagValue -ArgList $args -Name 'internal-port'
    $VolumeDir = Get-FlagValue -ArgList $args -Name 'volume-dir'
    $VolumeName = Get-FlagValue -ArgList $args -Name 'volume-name'
    $NetworkName = Get-FlagValue -ArgList $args -Name 'network-name'

    foreach ($a in $args) {
        if ($a -notmatch '^--(ssh-string|delete-image|delete-volume|internal-port|volume-dir|volume-name|network-name|help)=?' -and $a -notmatch '^(--help|-h|/\?)$') {
            Write-Color "Unknown flag: $a" 'Red'
            Show-Help
            exit 1
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($SshString) -and $SshString -ne 'localhost') {
        Write-Color "WARNING: --ssh-string=$SshString ignored on local script. Use run-on-docker-server.ps1 for remote." 'Yellow'
    }

    $doDeleteImage = Test-Truthy $DeleteImage
    $doDeleteVolume = Test-Truthy $DeleteVolume

    if ([string]::IsNullOrWhiteSpace($InternalPort)) {
        $PublishPort = Get-RandomFreePort
    }
    else {
        if ($InternalPort -notmatch '^\d+$') {
            throw "--internal-port must be a number. Got: $InternalPort"
        }
        $PublishPort = [int]$InternalPort
        if ($PublishPort -lt $SafePortMin -or $PublishPort -gt $SafePortMax) {
            Write-Color "WARNING: port $PublishPort is outside recommended range $SafePortMin-$SafePortMax" 'Yellow'
        }
        if (-not (Test-PortFree $PublishPort)) {
            throw "Port $PublishPort is already in use"
        }
    }

    $userName = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { "/home/$userName" }
    if ([string]::IsNullOrWhiteSpace($VolumeDir)) {
        $VolumeDir = Join-Path $homeDir "docker\$ContainerName"
    }
    if ([string]::IsNullOrWhiteSpace($VolumeName)) {
        $VolumeName = "$ContainerName-volume"
    }
    if ([string]::IsNullOrWhiteSpace($NetworkName)) {
        # Prefer compose/manifest default when present
        $NetworkName = 'lexmora-net'
    }

    if (-not (Test-Path -LiteralPath $ComposeFile)) {
        throw "Compose file not found: $ComposeFile"
    }

    Ensure-Docker

    Write-Color "==> Local deploy: $ContainerName" 'Cyan'
    Write-Color "    port:    $PublishPort -> $ContainerPort" 'DarkGray'
    Write-Color "    network: $NetworkName" 'DarkGray'
    Write-Color "    volume:  $VolumeName (dir: $VolumeDir)" 'DarkGray'
    Write-Color "    delete-image=$doDeleteImage  delete-volume=$doDeleteVolume" 'DarkGray'

    # Teardown existing stack
    Write-Color '==> Stopping existing stack (if any)' 'Cyan'
    $env:WEB_PUBLISH_PORT = "$PublishPort"
    $env:DOCKER_NETWORK = $NetworkName
    $env:WEB_IMAGE_TAG = "${ImageName}:${ImageTag}"
    Push-Location $ScriptDir
    try {
        & docker compose -f $ComposeFile down --remove-orphans 2>$null | Out-Null

        if ($doDeleteImage) {
            Write-Color "==> Removing image ${ImageName}:${ImageTag}" 'Yellow'
            & docker rmi "${ImageName}:${ImageTag}" 2>$null | Out-Null
        }

        if ($doDeleteVolume) {
            Write-Color "==> Removing volume $VolumeName" 'Yellow'
            & docker volume rm $VolumeName 2>$null | Out-Null
            if (Test-Path -LiteralPath $VolumeDir) {
                Write-Color "==> Clearing volume dir $VolumeDir" 'Yellow'
                Remove-Item -LiteralPath $VolumeDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        if (-not (Test-Path -LiteralPath $VolumeDir)) {
            New-Item -ItemType Directory -Path $VolumeDir -Force | Out-Null
        }

        Ensure-Network $NetworkName

        Write-Color '==> Building image' 'Cyan'
        $createImage = Join-Path $ScriptDir 'create-image.ps1'
        if (Test-Path -LiteralPath $createImage) {
            & $createImage --image-name=$ImageName --tag=$ImageTag
            if ($LASTEXITCODE -ne 0) { throw 'create-image.ps1 failed' }
        }
        else {
            & docker compose -f $ComposeFile build
            if ($LASTEXITCODE -ne 0) { throw 'docker compose build failed' }
        }

        Write-Color '==> Starting stack' 'Cyan'
        & docker compose -f $ComposeFile up -d
        if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }
    }
    finally {
        Pop-Location
    }

    Write-Color '' 'White'
    Write-Color '==> Deploy complete' 'Green'
    Write-Color "    URL:     http://localhost:$PublishPort" 'Green'
    Write-Color "    Image:   ${ImageName}:${ImageTag}" 'Green'
    Write-Color "    Network: $NetworkName" 'Green'
    Write-Color "    Volume:  $VolumeName" 'Green'
    Write-Color "    Data:    $VolumeDir" 'Green'
    exit 0
}
catch {
    Write-Color "ERROR: $($_.Exception.Message)" 'Red'
    Show-Help
    exit 1
}
