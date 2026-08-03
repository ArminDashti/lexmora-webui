#Requires -Version 5.1
<#
.SYNOPSIS
  Deploy stack to the local host over Docker daemon using sibling YAML only.

.DESCRIPTION
  Local deploy script for .armin/docker-scripts/run-on-docker-local.yaml
  - No CLI arguments
  - Copies nothing; builds image locally and runs `docker compose up -d`

.CONFIG
  Sibling file: run-on-docker-local.yaml

  stack_name
  image_tag
  compose_file        Compose path relative to .armin/docker-scripts
  dockerfile          Dockerfile path relative to .armin/docker-scripts
  docker_network      External Docker network name
  internal_port       Optional (kept for compatibility; unused by this repo's compose)
  delete_volume       yes/true/1/y/on → remove volumes before up
  delete_image        yes/true/1/y/on → remove image during teardown

  This script sets env vars expected by your `docker-compose.yml`:
    - IMAGE_TAG
    - PUBLISH_PORT (from publish_port)
    - INTERNAL_PORT (when set)
    - DOCKER_NETWORK
    - API_HOST (from api_host)
    - API_PORT (from api_port)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DeployDir = $PSScriptRoot
$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $DeployDir '../..'))
$ConfigPath = Join-Path $DeployDir 'run-on-docker-local.yaml'

function Write-Step([string]$Message) {
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "OK  $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "ERR $Message" -ForegroundColor Red
}

function Show-Help {
    Write-Host @"
run-on-docker-local.ps1 — local Docker deploy (YAML-only)

USAGE:
  .\.armin\docker-scripts\run-on-docker-local.ps1

CONFIG:
  Sibling file: run-on-docker-local.yaml

  stack_name
  image_tag
  compose_file
  dockerfile
  docker_network
  api_host            API container hostname on docker_network
  api_port            API listen port inside the network
  publish_port        Host bind port (PUBLISH_PORT)
  internal_port       Container listen port (INTERNAL_PORT)
  delete_volume
  delete_image

NOTES:
  - No CLI -- flags. Edit run-on-docker-local.yaml instead.
  - Sets IMAGE_TAG, PUBLISH_PORT, INTERNAL_PORT, DOCKER_NETWORK, API_HOST, API_PORT for compose.
  - Uses --force-recreate so network / env changes always apply.
"@ -ForegroundColor Cyan
}

function Test-Truthy([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim().ToLowerInvariant() -in @('yes', 'true', '1', 'y', 'on')
}

function Test-Placeholder([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
    return $Value -match '<[^>]+>'
}

function Read-FlatYaml([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing config: $Path"
    }

    $map = @{}
    foreach ($raw in Get-Content -LiteralPath $Path) {
        $line = $raw.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        if ($line -match '^\s*-') { continue }
        if ($line -notmatch '^(?<key>[^:#]+):\s*(?<val>.*)$') { continue }
        $key = $Matches['key'].Trim()
        $val = $Matches['val'].Trim()
        if (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'"))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        $map[$key] = $val
    }
    return $map
}

function Require-Key($Map, [string]$Key) {
    if (-not $Map.ContainsKey($Key) -or [string]::IsNullOrWhiteSpace([string]$Map[$Key])) {
        throw "YAML missing required key: $Key"
    }
    return [string]$Map[$Key]
}

function Resolve-DeployPath([string]$RelativePath) {
    $candidate = Join-Path $DeployDir $RelativePath
    $fullPath = [System.IO.Path]::GetFullPath($candidate)
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Path not found: $fullPath"
    }
    return $fullPath
}

function Ensure-Docker {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker CLI is not available. Start Docker Desktop / daemon.' }
}

function Ensure-Network([string]$NetworkName) {
    # docker writes "network not found" to stderr; suppress it so we can fallback to create.
    $oldEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'SilentlyContinue'
        & docker network inspect $NetworkName *> $null
    }
    finally {
        $ErrorActionPreference = $oldEap
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Step "Creating network $NetworkName"
        & docker network create $NetworkName *> $null
        if ($LASTEXITCODE -ne 0) { throw "Failed to create network $NetworkName" }
    }
}

if ($args.Count -gt 0) {
    Write-Fail 'This script accepts no CLI arguments. Edit run-on-docker-local.yaml instead.'
    Show-Help
    exit 1
}

try {
    $cfg = Read-FlatYaml $ConfigPath

    $stackName = Require-Key $cfg 'stack_name'
    $imageTag = Require-Key $cfg 'image_tag'
    $composeFileRel = Require-Key $cfg 'compose_file'
    $dockerfileRel = Require-Key $cfg 'dockerfile'
    $network = Require-Key $cfg 'docker_network'

    $apiHost = if ($cfg.ContainsKey('api_host')) { [string]$cfg['api_host'] } else { 'lexmora-api' }
    $apiPort = if ($cfg.ContainsKey('api_port')) { [string]$cfg['api_port'] } else { '8080' }
    $publishPort = if ($cfg.ContainsKey('publish_port')) { [string]$cfg['publish_port'] } else { '' }
    $internalPort = if ($cfg.ContainsKey('internal_port')) { [string]$cfg['internal_port'] } else { '' }
    $deleteVolume = Test-Truthy ($(if ($cfg.ContainsKey('delete_volume')) { [string]$cfg['delete_volume'] } else { 'no' }))
    $deleteImage = Test-Truthy ($(if ($cfg.ContainsKey('delete_image')) { [string]$cfg['delete_image'] } else { 'no' }))

    if (Test-Placeholder $composeFileRel) { throw 'compose_file is still a placeholder.' }
    if (Test-Placeholder $dockerfileRel) { throw 'dockerfile is still a placeholder.' }
    if (Test-Placeholder $stackName) { throw 'stack_name is still a placeholder.' }
    if (Test-Placeholder $imageTag) { throw 'image_tag is still a placeholder.' }
    if (Test-Placeholder $network) { throw 'docker_network is still a placeholder.' }
    if ([string]::IsNullOrWhiteSpace($apiHost) -or (Test-Placeholder $apiHost)) { throw 'api_host is missing or still a placeholder.' }
    if ([string]::IsNullOrWhiteSpace($apiPort) -or (Test-Placeholder $apiPort)) { throw 'api_port is missing or still a placeholder.' }
    if ([string]::IsNullOrWhiteSpace($publishPort) -or (Test-Placeholder $publishPort)) { throw 'publish_port is missing or still a placeholder.' }

    $composePath = Resolve-DeployPath $composeFileRel
    $dockerfile = Resolve-DeployPath $dockerfileRel

    Write-Step "Stack=$stackName image=$imageTag network=$network api=$apiHost`:$apiPort publish_port=$publishPort internal_port='$internalPort' delete_volume=$deleteVolume delete_image=$deleteImage"

    Ensure-Docker
    Ensure-Network $network

    $publishComposePath = Join-Path $RepoRoot 'docker-compose.publish.yml'
    if (-not (Test-Path -LiteralPath $publishComposePath)) {
        throw "Missing publish overlay: $publishComposePath"
    }

    if ($deleteVolume -or $deleteImage) {
        Write-Step 'Stopping existing stack'
        if ($deleteVolume) {
            docker compose -p $stackName -f $composePath -f $publishComposePath --project-directory $RepoRoot down -v
        }
        else {
            docker compose -p $stackName -f $composePath -f $publishComposePath --project-directory $RepoRoot down
        }
    }

    if ($deleteImage) {
        Write-Step "Removing local image $imageTag"
        $oldEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'SilentlyContinue'
            docker image rm -f $imageTag *> $null
        }
        finally {
            $ErrorActionPreference = $oldEap
        }
    }

    Write-Step "Building image $imageTag"
    docker build -f $dockerfile -t $imageTag $RepoRoot
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }

    Write-Step 'Starting stack'
    $oldImageTag = $env:IMAGE_TAG
    $oldPublishPort = $env:PUBLISH_PORT
    $oldInternalPort = $env:INTERNAL_PORT
    $oldDockerNetwork = $env:DOCKER_NETWORK
    $oldApiHost = $env:API_HOST
    $oldApiPort = $env:API_PORT
    $env:IMAGE_TAG = $imageTag
    $env:PUBLISH_PORT = $publishPort
    $env:DOCKER_NETWORK = $network
    $env:API_HOST = $apiHost
    $env:API_PORT = $apiPort
    if (-not [string]::IsNullOrWhiteSpace($internalPort)) { $env:INTERNAL_PORT = $internalPort }
    try {
        # Force recreate so network / API_HOST changes replace a stale container
        # (plain `up -d` can leave an old network attachment like lexmora-net).
        docker compose -p $stackName -f $composePath -f $publishComposePath --project-directory $RepoRoot up -d --force-recreate --remove-orphans
        if ($LASTEXITCODE -ne 0) { throw 'docker compose up failed' }
    }
    finally {
        if ($null -ne $oldImageTag) { $env:IMAGE_TAG = $oldImageTag } else { Remove-Item Env:IMAGE_TAG -ErrorAction SilentlyContinue }
        if ($null -ne $oldPublishPort) { $env:PUBLISH_PORT = $oldPublishPort } else { Remove-Item Env:PUBLISH_PORT -ErrorAction SilentlyContinue }
        if ($null -ne $oldInternalPort) { $env:INTERNAL_PORT = $oldInternalPort } else { Remove-Item Env:INTERNAL_PORT -ErrorAction SilentlyContinue }
        if ($null -ne $oldDockerNetwork) { $env:DOCKER_NETWORK = $oldDockerNetwork } else { Remove-Item Env:DOCKER_NETWORK -ErrorAction SilentlyContinue }
        if ($null -ne $oldApiHost) { $env:API_HOST = $oldApiHost } else { Remove-Item Env:API_HOST -ErrorAction SilentlyContinue }
        if ($null -ne $oldApiPort) { $env:API_PORT = $oldApiPort } else { Remove-Item Env:API_PORT -ErrorAction SilentlyContinue }
    }

    Write-Ok 'Deploy complete'
    Write-Host "URL: http://localhost:$publishPort" -ForegroundColor Green
}
catch {
    Write-Fail $_.Exception.Message
    Show-Help
    exit 1
}

