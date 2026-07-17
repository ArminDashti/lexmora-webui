#Requires -Version 5.1
<#
.SYNOPSIS
  Build and deploy lexmora-webui on a remote Docker host over SSH.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$ContainerName = 'lexmora-webui'
$ComposeFileName = 'docker-compose.yml'
$ImageName = 'lexmora-webui'
$ImageTag = 'latest'
$ContainerPort = 80
$SafePortMin = 30000
$SafePortMax = 32767
$RemoteProjectDir = '/cloud-admin/docker/lexmora-webui'

function Write-Color([string]$Message, [string]$Color = 'White') {
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    $userProfile = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
    @"
run-on-docker-server.ps1 - deploy $ContainerName on remote Docker over SSH

USAGE:
  .\run-on-docker-server.ps1 --ssh-string=<alias> [flags]

FLAGS:
  --ssh-string=<alias>       SSH config alias (required; default: null -> error)
  --delete-image=<no|yes>    Remove built images during teardown (default: null -> no)
  --delete-volume=<no|yes>   Remove volumes before recreate (default: null -> no)
  --internal-port=<port>     Host port mapped to the container (default: null -> random 30000-32767)
  --volume-dir=<path>        Bind-mount data directory on remote (default: null -> ~/$userProfile/docker/$ContainerName style under remote home)
  --volume-name=<name>       Named Docker volume (default: null -> $ContainerName-volume)
  --network-name=<name>      Docker network (default: null -> lexmora-net)
  --help                     Show this help

EXAMPLES:
  .\run-on-docker-server.ps1 --ssh-string=myserver
  .\run-on-docker-server.ps1 --ssh-string=myserver --delete-volume=yes
  .\run-on-docker-server.ps1 --ssh-string=myserver --internal-port=30042

NOTES:
  --ssh-string is required and must be an SSH config alias only (do not include "ssh").
  - Null defaults resolve as described in FLAGS.
  - Truthy values for yes/no flags: yes, true, 1, y, on.
  - Default internal port is picked randomly from 30000-32767 if not specified.
  - Project files are copied to $RemoteProjectDir on the remote host for build/deploy.
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

function Test-LocalPortFree([int]$Port) {
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
        if (Test-LocalPortFree $candidate) { return $candidate }
    }
    throw "Could not find a free port in $SafePortMin-$SafePortMax"
}

function Invoke-Remote {
    param([string]$Alias, [string]$RemoteCommand)
    & ssh $Alias $RemoteCommand
    if ($LASTEXITCODE -ne 0) {
        throw "Remote command failed on $Alias (exit $LASTEXITCODE): $RemoteCommand"
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

    if ([string]::IsNullOrWhiteSpace($SshString)) {
        Write-Color 'ERROR: --ssh-string is required for server deploy.' 'Red'
        Show-Help
        exit 1
    }
    if ($SshString -match '^\s*ssh\s+' -or $SshString -eq 'ssh') {
        Write-Color 'ERROR: --ssh-string must be an SSH config alias only (do not include "ssh").' 'Red'
        Show-Help
        exit 1
    }
    if ($SshString -eq 'localhost') {
        Write-Color 'ERROR: Use run-on-docker-local.ps1 for local deploy.' 'Red'
        Show-Help
        exit 1
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
    }

    $userName = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
    if ([string]::IsNullOrWhiteSpace($VolumeDir)) {
        $VolumeDir = "~/docker/$ContainerName"
    }
    if ([string]::IsNullOrWhiteSpace($VolumeName)) {
        $VolumeName = "$ContainerName-vol"
    }
    if ([string]::IsNullOrWhiteSpace($NetworkName)) {
        $NetworkName = 't3-net'
    }

    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        throw 'SSH client is not available.'
    }
    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
        throw 'SCP client is not available.'
    }

    $composeLocal = Join-Path $ScriptDir $ComposeFileName
    $dockerfileLocal = Join-Path $ScriptDir 'Dockerfile'
    if (-not (Test-Path -LiteralPath $composeLocal)) { throw "Missing $ComposeFileName" }
    if (-not (Test-Path -LiteralPath $dockerfileLocal)) { throw 'Missing Dockerfile' }

    Write-Color "==> Remote deploy: $ContainerName via SSH alias '$SshString'" 'Cyan'
    Write-Color "    port:    $PublishPort -> $ContainerPort" 'DarkGray'
    Write-Color "    network: $NetworkName" 'DarkGray'
    Write-Color "    volume:  $VolumeName (dir: $VolumeDir)" 'DarkGray'
    Write-Color "    delete-image=$doDeleteImage  delete-volume=$doDeleteVolume" 'DarkGray'

    Write-Color '==> Checking remote Docker' 'Cyan'
    Invoke-Remote -Alias $SshString -RemoteCommand 'docker version --format "{{.Server.Version}}" >/dev/null'

    Write-Color "==> Preparing remote dir $RemoteProjectDir" 'Cyan'
    Invoke-Remote -Alias $SshString -RemoteCommand "mkdir -p '$RemoteProjectDir' && mkdir -p $VolumeDir"

    Write-Color '==> Copying project files' 'Cyan'
    $itemsToCopy = @(
        'Dockerfile'
        'docker-compose.yml'
        'nginx.conf.template'
        'package.json'
        'package-lock.json'
        'index.html'
        'vite.config.ts'
        'tsconfig.json'
        'tsconfig.app.json'
        'tsconfig.node.json'
        'src'
        'public'
        '.docker'
    )
    foreach ($item in $itemsToCopy) {
        $src = Join-Path $ScriptDir $item
        if (Test-Path -LiteralPath $src) {
            & scp -r $src "${SshString}:${RemoteProjectDir}/"
            if ($LASTEXITCODE -ne 0) { throw "scp failed for $item" }
        }
    }

    $deleteImageCmd = if ($doDeleteImage) {
        "docker rmi ${ImageName}:${ImageTag} 2>/dev/null || true"
    } else { 'true' }
    $deleteVolumeCmd = if ($doDeleteVolume) {
        "docker volume rm $VolumeName 2>/dev/null || true"
    } else { 'true' }

    $remoteScript = @"
set -e
cd '$RemoteProjectDir'
export WEB_PUBLISH_PORT=''
export DOCKER_NETWORK='$NetworkName'
export WEB_IMAGE_TAG='${ImageName}:${ImageTag}'
docker compose -p lexmora-webui -f $ComposeFileName down --remove-orphans 2>/dev/null || true
$deleteImageCmd
$deleteVolumeCmd
docker network inspect '$NetworkName' >/dev/null 2>&1 || docker network create '$NetworkName'
docker build -t ${ImageName}:${ImageTag} -f Dockerfile .
docker compose -p lexmora-webui -f $ComposeFileName up -d
echo REMOTE_OK https://lexmora.xaigrok.ir
"@

    $remoteScript = $remoteScript -replace "`r`n", "`n"
    Write-Color '==> Building and starting on remote' 'Cyan'
    $remoteScript | & ssh $SshString 'bash -s'
    if ($LASTEXITCODE -ne 0) {
        throw "Remote deploy failed (exit $LASTEXITCODE)"
    }

    Write-Color '' 'White'
    Write-Color '==> Deploy complete' 'Green'
    Write-Color "    Host:    $SshString" 'Green'
    Write-Color "    URL:     http://<remote-host>:$PublishPort" 'Green'
    Write-Color "    Image:   ${ImageName}:${ImageTag}" 'Green'
    Write-Color "    Network: $NetworkName" 'Green'
    Write-Color "    Volume:  $VolumeName" 'Green'
    Write-Color "    Data:    $VolumeDir" 'Green'
    Write-Color "    Remote:  $RemoteProjectDir" 'Green'
    exit 0
}
catch {
    Write-Color "ERROR: $($_.Exception.Message)" 'Red'
    Show-Help
    exit 1
}
