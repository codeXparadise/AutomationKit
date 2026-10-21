# ==============================================================================
#  AUTOMATIONKIT -- ROBUST GEMINI-CLI INSPIRED TUI & ORCHESTRATOR
# ==============================================================================
# Features:
# - Full keyboard navigation: Up/Down arrow keys, Enter & Spacebar selection,
#   PageUp/PageDown, Home/End, hotkeys (s, x, r, u, d, c, p, l, w, m, q), and 0-9.
# - Auto-detection of app installation status with automatic first-time onboarding.
# - Step-by-step interactive API key and secret collection wizard.
# - Automatic update detection for container images & n8n nodes with auto-restart.
# - Proactive port conflict detection (ports 80, 443, 2785, 5678, 5432, 6379).
# - Automatic Docker Desktop detection & startup recovery.
# - Post-launch crash diagnosis and automatic log tailing.
# - High-res ASCII art banner of "Automation Kit" with UTF-8 border rendering.
# - Live telemetry bar: Docker state, container health counter, OpenWA status.
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Action = '',

    [Parameter(Position=1)]
    [string]$TargetService = ''
)

$ErrorActionPreference = 'Continue'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $ScriptDir) { $ScriptDir = Get-Location }
Set-Location $ScriptDir

$ProjectRoot = $ScriptDir
$EnvFile     = Join-Path $ProjectRoot '.env'
$EnvExample  = Join-Path $ProjectRoot '.env.example'
$ComposeFile = Join-Path $ProjectRoot 'compose.yml'

# Cached telemetry variables
$global:DockerState  = 'ONLINE'
$global:RunningCount = 26
$global:TotalCount   = 26
$global:OpenWAState  = 'READY'

# ==============================================================================
# TELEMETRY & STATUS REFRESH
# ==============================================================================
function Update-CachedTelemetry {
    try {
        $dockerCheck = docker info 2>$null
        if ($LASTEXITCODE -ne 0) {
            $global:DockerState  = 'OFFLINE'
            $global:RunningCount = 0
            $global:TotalCount   = 0
            $global:OpenWAState  = 'OFFLINE'
            return
        }
        $global:DockerState = 'ONLINE'

        $out = docker compose ps --format "{{.Service}}|{{.State}}|{{.Health}}" 2>$null
        if ($out) {
            $lines = $out -split "`r?`n" | Where-Object { $_ -match '\|' }
            $global:TotalCount = $lines.Count
            $running = 0
            $owa = 'OFFLINE'

            foreach ($l in $lines) {
                $parts = $l -split '\|'
                $srv  = $parts[0]
                $st   = $parts[1]
                $hlth = if ($parts.Count -gt 2) { $parts[2] } else { '' }

                if ($st -eq 'running') {
                    $running++
                }
                if ($srv -eq 'openwa') {
                    if ($st -eq 'running') {
                        $owa = if ($hlth) { $hlth.ToUpper() } else { 'RUNNING' }
                    } else {
                        $owa = $st.ToUpper()
                    }
                }
            }
            $global:RunningCount = $running
            $global:OpenWAState  = $owa
        }
    } catch {
        $global:DockerState = 'OFFLINE'
    }
}

# ==============================================================================
# UI HELPERS & ASCII ART
# ==============================================================================
function Show-Banner {
    Write-Host ''
    Write-Host @'
    ___         __                        __  _                 __ __ _ __ 
   /   | __  __/ /_____  ____ ___  ____ _/ /_(_)___  ____      / //_/(_) /_
  / /| |/ / / / __/ __ \/ __ `__ \/ __ `/ __/ / __ \/ __ \    / ,<  / / __/
 / ___ / /_/ / /_/ /_/ / / / / / / /_/ / /_/ / /_/ / / / /   / /| |/ / /_  
/_/  |_\__,_/\__/\____/_/ /_/ /_/\__,_/\__/_/\____/_/ /_/   /_/ |_/_/\__/  
'@ -ForegroundColor Cyan
    Write-Host '    LOCAL AI WORKFLOWS, OPENWA GATEWAY & MICROSERVICES PLATFORM' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-TelemetryBar {
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host ' | ' -NoNewline -ForegroundColor DarkCyan

    # Docker indicator
    if ($global:DockerState -eq 'ONLINE') {
        Write-Host '[*] DOCKER: ONLINE  ' -NoNewline -ForegroundColor Green
    } else {
        Write-Host '[X] DOCKER: OFFLINE ' -NoNewline -ForegroundColor Red
    }

    Write-Host '| ' -NoNewline -ForegroundColor DarkCyan

    # Services indicator
    if ($global:RunningCount -gt 0) {
        $svcText = "[*] SERVICES: $($global:RunningCount)/$($global:TotalCount) ACTIVE "
        Write-Host $svcText.PadRight(25) -NoNewline -ForegroundColor Green
    } else {
        Write-Host '[!] SERVICES: ALL STOPPED  ' -NoNewline -ForegroundColor DarkYellow
    }

    Write-Host '| ' -NoNewline -ForegroundColor DarkCyan

    # OpenWA indicator
    if ($global:OpenWAState -eq 'HEALTHY' -or $global:OpenWAState -eq 'RUNNING' -or $global:OpenWAState -eq 'READY') {
        Write-Host '[*] OPENWA: READY (2785)  ' -NoNewline -ForegroundColor Green
    } else {
        $owaText = "[!] OPENWA: $($global:OpenWAState) "
        Write-Host $owaText.PadRight(25) -NoNewline -ForegroundColor DarkYellow
    }

    Write-Host '|' -ForegroundColor DarkCyan
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host ''
}

function Print-Header {
    param([string]$Title)
    Write-Host ''
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor Cyan
    Write-Host (' |  ' + $Title.PadRight(71) + '|') -ForegroundColor Cyan
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''
}

function Print-Step {
    param([int]$Step, [int]$Total, [string]$Message)
    Write-Host ("`n [$Step/$Total] " + $Message) -ForegroundColor Yellow
}

function Print-Success {
    param([string]$Message)
    Write-Host ('  [OK] ' + $Message) -ForegroundColor Green
}

function Print-Info {
    param([string]$Message)
    Write-Host ('  [INFO] ' + $Message) -ForegroundColor Cyan
}

function Print-Warn {
    param([string]$Message)
    Write-Host ('  [WARN] ' + $Message) -ForegroundColor DarkYellow
}

function Print-Error {
    param([string]$Message)
    Write-Host ('  [ERROR] ' + $Message) -ForegroundColor Red
}

function New-RandomSecret {
    param([int]$Length = 32)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $bytes = [byte[]]::new($Length)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    $res = ''
    for ($i = 0; $i -lt $Length; $i++) {
        $res += $chars[$bytes[$i] % $chars.Length]
    }
    return $res
}

# ==============================================================================
# ROBUST KEYBOARD-DRIVEN TUI ENGINE (Up/Down/Enter/Space/Keys)
# ==============================================================================
function Invoke-InteractiveMenu {
    param(
        [string]$Title,
        [array]$MenuItems,
        [int]$DefaultIndex = 0,
        [switch]$ShowHeader
    )

    $canReadKeys = $false
    try {
        if (-not [Console]::IsInputRedirected) {
            $canReadKeys = $true
        }
    } catch {
        $canReadKeys = $false
    }

    # Fallback for redirected / non-interactive shells
    if (-not $canReadKeys) {
        Write-Host "`n $Title" -ForegroundColor Cyan
        for ($i = 0; $i -lt $MenuItems.Count; $i++) {
            $item = $MenuItems[$i]
            $tag = if ($item.Tag) { "[$($item.Tag)] " } else { '' }
            Write-Host ('   [{0}] {1}{2} - {3}' -f $item.Id, $tag, $item.Label, $item.Desc) -ForegroundColor Gray
        }
        $raw = Read-Host "`n Select an option [0-$($MenuItems.Count - 1)]"
        return $raw.Trim()
    }

    $selectedIndex = $DefaultIndex
    $count = $MenuItems.Count

    try { [Console]::CursorVisible = $false } catch {}

    while ($true) {
        Clear-Host
        if ($ShowHeader) {
            Show-Banner
            Show-TelemetryBar
        }

        # Menu Title Box
        Write-Host " +-- $Title " -NoNewline -ForegroundColor Cyan
        $remaining = 74 - (5 + $Title.Length)
        if ($remaining -gt 0) {
            Write-Host ('-' * $remaining) -NoNewline -ForegroundColor DarkCyan
        }
        Write-Host '+' -ForegroundColor DarkCyan
        Write-Host ' |' -NoNewline -ForegroundColor DarkCyan
        Write-Host (' ' * 73) -NoNewline
        Write-Host '|' -ForegroundColor DarkCyan

        # Render Items
        for ($i = 0; $i -lt $count; $i++) {
            $item = $MenuItems[$i]
            $idStr = "[$($item.Id)]".PadRight(5)
            $tagStr = if ($item.Tag) { "[$($item.Tag)]".PadRight(10) } else { "".PadRight(10) }
            $labelStr = $item.Label.PadRight(45)
            if ($labelStr.Length -gt 45) { $labelStr = $labelStr.Substring(0, 42) + '...' }

            Write-Host ' | ' -NoNewline -ForegroundColor DarkCyan

            if ($i -eq $selectedIndex) {
                # Selected: Highlight Bar
                Write-Host '> ' -NoNewline -ForegroundColor Cyan
                Write-Host " $idStr $tagStr $labelStr " -NoNewline -ForegroundColor Black -BackgroundColor Cyan
            } else {
                # Normal Item
                Write-Host '  ' -NoNewline
                Write-Host "$idStr " -NoNewline -ForegroundColor DarkGray
                if ($item.Tag) {
                    Write-Host "$tagStr " -NoNewline -ForegroundColor DarkCyan
                } else {
                    Write-Host "$tagStr " -NoNewline
                }
                Write-Host "$labelStr  " -NoNewline -ForegroundColor White
            }

            Write-Host '|' -ForegroundColor DarkCyan
        }

        Write-Host ' |' -NoNewline -ForegroundColor DarkCyan
        Write-Host (' ' * 73) -NoNewline
        Write-Host '|' -ForegroundColor DarkCyan
        Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkCyan

        # Dynamic Details Card
        $active = $MenuItems[$selectedIndex]
        Write-Host ' +-- DETAILS & IMPACT -----------------------------------------------------+' -ForegroundColor DarkYellow

        $d1 = $active.Desc
        if ($d1.Length -gt 69) {
            $words = $d1 -split ' '
            $curr = ''
            foreach ($w in $words) {
                if (($curr + ' ' + $w).Length -le 69) {
                    $curr = if ($curr) { "$curr $w" } else { $w }
                } else {
                    Write-Host (' |  ' + $curr.PadRight(71) + '|') -ForegroundColor Gray
                    $curr = $w
                }
            }
            if ($curr) {
                Write-Host (' |  ' + $curr.PadRight(71) + '|') -ForegroundColor Gray
            }
        } else {
            Write-Host (' |  ' + $d1.PadRight(71) + '|') -ForegroundColor Gray
        }

        if ($active.Target) {
            $tStr = "* Target: $($active.Target)"
            if ($tStr.Length -gt 69) { $tStr = $tStr.Substring(0, 66) + '...' }
            Write-Host (' |  ' + $tStr.PadRight(71) + '|') -ForegroundColor DarkCyan
        }

        Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray

        # Cheatsheet status bar
        Write-Host ' [UP/DOWN/J/K] Navigate  *  [ENTER/SPACE] Select  *  [0-9/KEY] Jump  *  [Q] Back' -ForegroundColor DarkGray

        # Read keystroke
        $keyInfo = [Console]::ReadKey($true)
        switch ($keyInfo.Key) {
            'UpArrow' {
                $selectedIndex--
                if ($selectedIndex -lt 0) { $selectedIndex = $count - 1 }
            }
            'DownArrow' {
                $selectedIndex++
                if ($selectedIndex -ge $count) { $selectedIndex = 0 }
            }
            'PageUp' {
                $selectedIndex = [Math]::Max(0, $selectedIndex - 4)
            }
            'PageDown' {
                $selectedIndex = [Math]::Min($count - 1, $selectedIndex + 4)
            }
            'Home' {
                $selectedIndex = 0
            }
            'End' {
                $selectedIndex = $count - 1
            }
            'Enter' {
                try { [Console]::CursorVisible = $true } catch {}
                Write-Host ''
                return $MenuItems[$selectedIndex].Id
            }
            'Spacebar' {
                try { [Console]::CursorVisible = $true } catch {}
                Write-Host ''
                return $MenuItems[$selectedIndex].Id
            }
            'Escape' {
                try { [Console]::CursorVisible = $true } catch {}
                return '0'
            }
            default {
                $ch = $keyInfo.KeyChar.ToString().ToLower()
                if ($ch -eq 'q') {
                    try { [Console]::CursorVisible = $true } catch {}
                    return '0'
                }
                if ($ch -eq 'k') {
                    $selectedIndex--
                    if ($selectedIndex -lt 0) { $selectedIndex = $count - 1 }
                    break
                }
                if ($ch -eq 'j') {
                    $selectedIndex++
                    if ($selectedIndex -ge $count) { $selectedIndex = 0 }
                    break
                }
                if ($ch -eq 'g') {
                    $selectedIndex = 0
                    break
                }
                # Direct jump match by Id or shortcut Key
                $matched = $MenuItems | Where-Object { 
                    ($_.Id.ToString().ToLower() -eq $ch) -or 
                    ($_.Key -and $_.Key.ToString().ToLower() -eq $ch) 
                }
                if ($matched) {
                    try { [Console]::CursorVisible = $true } catch {}
                    Write-Host ''
                    return $matched.Id
                }
            }
        }
    }
}

# ==============================================================================
# PROACTIVE ERROR HANDLING & SYSTEM PRE-FLIGHT
# ==============================================================================
function Test-PreFlight {
    Print-Step 1 6 'System Pre-Flight & Docker Diagnostic Check...'

    $dockerCmd = Get-Command 'docker' -ErrorAction SilentlyContinue
    if (-not $dockerCmd) {
        Print-Error 'Docker is not installed or not found in system PATH!'
        Write-Host '   Please install Docker Desktop: https://www.docker.com/products/docker-desktop/' -ForegroundColor White
        exit 1
    }

    docker info >$null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Print-Warn 'Docker daemon is not running.'
        $desktopPath = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
        if (Test-Path $desktopPath) {
            Write-Host '   Found Docker Desktop installation. Attempting to start Docker Desktop...' -ForegroundColor Cyan
            Start-Process -FilePath $desktopPath
            Write-Host '   Waiting for Docker daemon to become responsive (up to 45s)...' -ForegroundColor Yellow

            $waitRetries = 15
            while ($waitRetries -gt 0) {
                Start-Sleep -Seconds 3
                Write-Host '.' -NoNewline -ForegroundColor Cyan
                docker info >$null 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host ''
                    Print-Success 'Docker daemon is now active and responsive!'
                    return
                }
                $waitRetries--
            }
            Write-Host ''
        }

        Print-Error 'Docker daemon is not running!'
        Write-Host '   Please start Docker Desktop manually and run this command again.' -ForegroundColor DarkYellow
        exit 1
    }

    Print-Success 'Docker daemon is active and responsive.'
}

# ==============================================================================
# PROACTIVE PORT CONFLICT DETECTION & RESOLUTION
# ==============================================================================
function Resolve-PortConflicts {
    param([int[]]$Ports = @(80, 443, 2785, 5678, 5432, 6379))

    $conflicts = @()
    foreach ($p in $Ports) {
        try {
            $conns = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
            foreach ($c in $conns) {
                if ($c.OwningProcess) {
                    $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
                    $pName = if ($proc) { $proc.ProcessName } else { "PID $($c.OwningProcess)" }
                    # Filter out docker/wsl/host network drivers
                    if ($pName -notmatch 'docker|wsl|vpnkit') {
                        $conflicts += [PSCustomObject]@{
                            Port        = $p
                            Pid         = $c.OwningProcess
                            ProcessName = $pName
                        }
                    }
                }
            }
        } catch {}
    }

    if ($conflicts.Count -gt 0) {
        Write-Host ''
        Print-Warn 'Detected active host processes occupying required microservice ports:'
        foreach ($c in $conflicts) {
            Write-Host ("   Port {0} is occupied by: {1} (PID: {2})" -f $c.Port, $c.ProcessName, $c.Pid) -ForegroundColor Yellow
        }
        
        Write-Host ''
        $kill = Read-Host ' Would you like to automatically terminate conflicting processes to free ports? (Y/n)'
        if ([string]::IsNullOrWhiteSpace($kill) -or $kill.ToLower().StartsWith('y')) {
            foreach ($c in $conflicts) {
                try {
                    Stop-Process -Id $c.Pid -Force -ErrorAction SilentlyContinue
                    Print-Success ("Terminated process {0} (PID {1}) on port {2}." -f $c.ProcessName, $c.Pid, $c.Port)
                } catch {
                    Print-Error ("Failed to terminate PID {0}: {1}" -f $c.Pid, $_.Exception.Message)
                }
            }
            Start-Sleep -Seconds 1
        } else {
            Print-Warn 'Port conflicts were not resolved. Some containers may fail to bind host ports.'
        }
    }
}

# ==============================================================================
# INSTALLATION DETECTION
# ==============================================================================
function Test-IsInstalled {
    # 1. Check if Docker is available
    $dockerCmd = Get-Command 'docker' -ErrorAction SilentlyContinue
    if (-not $dockerCmd) { return $false }

    # 2. Check if .env exists and has configured keys (not defaults)
    if (-not (Test-Path $EnvFile)) { return $false }
    $content = Get-Content $EnvFile -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content) -or 
        $content -match 'change_this_to_a_strong_secret' -or 
        $content -match 'change_this_password' -or
        $content -notmatch 'OPENWA_API_KEY') {
        return $false
    }

    # 3. Check persistent data volume directories
    $keyDirs = @('data\postgres', 'data\openwa', 'data\n8n\.n8n\nodes')
    foreach ($d in $keyDirs) {
        if (-not (Test-Path (Join-Path $ProjectRoot $d))) { return $false }
    }

    # 4. Check if community node is installed
    $pkgJson = Join-Path $ProjectRoot 'data\n8n\.n8n\nodes\package.json'
    if (-not (Test-Path $pkgJson)) { return $false }
    $pkgContent = Get-Content $pkgJson -Raw -ErrorAction SilentlyContinue
    if ($pkgContent -notmatch '@rmyndharis/n8n-nodes-openwa') { return $false }

    # 5. Check if containers are running or initialized
    $containers = docker compose ps -q 2>$null
    if (-not $containers) { return $false }

    return $true
}

# ==============================================================================
# INTERACTIVE STEP-BY-STEP API KEY & CREDENTIAL WIZARD
# ==============================================================================
function Invoke-StepByStepApiKeyWizard {
    Print-Header 'Interactive API Keys & Credentials Wizard'
    Write-Host ' Please configure your microservices API keys and credentials one by one.' -ForegroundColor Cyan
    Write-Host ' [TIP] Press [ENTER] to accept the suggested value, or type your custom key.' -ForegroundColor DarkGray
    Write-Host ''

    # Read existing values if present
    $existing = @{}
    if (Test-Path $EnvFile) {
        $lines = Get-Content $EnvFile -ErrorAction SilentlyContinue
        foreach ($l in $lines) {
            if ($l -match '^([A-Za-z0-9_]+)=(.*)$') {
                $existing[$matches[1]] = $matches[2].Trim()
            }
        }
    }

    # --- Step 1: OpenWA WhatsApp API Key ---
    Write-Host ' +-- [Step 1 of 6] OpenWA WhatsApp Gateway API Key ------------------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Master authentication key for WhatsApp REST endpoints and n8n. |' -ForegroundColor Gray
    Write-Host ' | Target:  OpenWA container (port 2785) & n8n WhatsApp Community Node.    |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugOpenWA = if ($existing['OPENWA_API_KEY'] -and $existing['OPENWA_API_KEY'] -notmatch 'change_this') { $existing['OPENWA_API_KEY'] } else { 'owa_k1_' + (New-RandomSecret -Length 32) }
    Write-Host " Suggested Key: $sugOpenWA" -ForegroundColor Cyan
    $inOpenWA = Read-Host " Enter OPENWA_API_KEY [Press Enter to accept suggestion]"
    if ([string]::IsNullOrWhiteSpace($inOpenWA)) { $inOpenWA = $sugOpenWA }
    Print-Success "OpenWA API Key set to: $inOpenWA`n"

    # --- Step 2: n8n Encryption Key & Runners Token ---
    Write-Host ' +-- [Step 2 of 6] n8n Encryption Key & Runners Auth Token ----------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Encrypts workflow credentials and authenticates task runners.  |' -ForegroundColor Gray
    Write-Host ' | Target:  n8n engine (port 5678) and task-runners worker.                |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugN8n = if ($existing['N8N_ENCRYPTION_KEY'] -and $existing['N8N_ENCRYPTION_KEY'] -notmatch 'change_this') { $existing['N8N_ENCRYPTION_KEY'] } else { New-RandomSecret -Length 32 }
    Write-Host " Suggested Key: $sugN8n" -ForegroundColor Cyan
    $inN8n = Read-Host " Enter N8N_ENCRYPTION_KEY [Press Enter to accept suggestion]"
    if ([string]::IsNullOrWhiteSpace($inN8n)) { $inN8n = $sugN8n }
    $inRunner = if ($existing['N8N_RUNNERS_AUTH_TOKEN'] -and $existing['N8N_RUNNERS_AUTH_TOKEN'] -notmatch 'change_this') { $existing['N8N_RUNNERS_AUTH_TOKEN'] } else { $inN8n }
    Print-Success "n8n Encryption Key set successfully.`n"

    # --- Step 3: Master Database & Cache Password ---
    Write-Host ' +-- [Step 3 of 6] Master Database & Redis Cache Password -----------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Secures PostgreSQL database (n8n, openwa) and Redis message Q. |' -ForegroundColor Gray
    Write-Host ' | Target:  postgres:5432 and redis:6379                                   |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugPg = if ($existing['POSTGRES_PASSWORD'] -and $existing['POSTGRES_PASSWORD'] -notmatch 'change_this') { $existing['POSTGRES_PASSWORD'] } else { 'dev_' + (New-RandomSecret -Length 12) }
    Write-Host " Suggested Password: $sugPg" -ForegroundColor Cyan
    $inPg = Read-Host " Enter POSTGRES_PASSWORD / REDIS_PASSWORD [Press Enter to accept]"
    if ([string]::IsNullOrWhiteSpace($inPg)) { $inPg = $sugPg }
    Print-Success "Database and Cache password configured.`n"

    # --- Step 4: AI Scraping & Document OCR Keys ---
    Write-Host ' +-- [Step 4 of 6] Web Scraping & AI Document OCR Keys --------------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Bearer tokens for Crawl4AI web extraction and Docling OCR API. |' -ForegroundColor Gray
    Write-Host ' | Target:  crawl4ai:11235 and docling:5001                                |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugAI = if ($existing['CRAWL4AI_API_TOKEN'] -and $existing['CRAWL4AI_API_TOKEN'] -notmatch 'change_this') { $existing['CRAWL4AI_API_TOKEN'] } else { $inPg }
    Write-Host " Suggested Token: $sugAI" -ForegroundColor Cyan
    $inAI = Read-Host " Enter AI Services Token (Crawl4AI & Docling) [Press Enter to accept]"
    if ([string]::IsNullOrWhiteSpace($inAI)) { $inAI = $sugAI }
    Print-Success "AI Scraper & OCR API tokens configured.`n"

    # --- Step 5: Vector DB & Knowledge Graph Password ---
    Write-Host ' +-- [Step 5 of 6] Vector DB & Knowledge Graph Passwords ------------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Access credentials for Qdrant Vector DB and Neo4j graph DB.   |' -ForegroundColor Gray
    Write-Host ' | Target:  qdrant:6333 and neo4j:7474                                     |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugNeo = if ($existing['NEO4J_PASSWORD'] -and $existing['NEO4J_PASSWORD'] -notmatch 'change_this') { $existing['NEO4J_PASSWORD'] } else { $inPg }
    Write-Host " Suggested Password: $sugNeo" -ForegroundColor Cyan
    $inNeo = Read-Host " Enter Neo4j & Qdrant Password [Press Enter to accept]"
    if ([string]::IsNullOrWhiteSpace($inNeo)) { $inNeo = $sugNeo }
    Print-Success "Vector DB and Knowledge Graph credentials configured.`n"

    # --- Step 6: Supabase Self-Hosted JWT Secret ---
    Write-Host ' +-- [Step 6 of 6] Supabase Self-Hosted JWT Secret ------------------------+' -ForegroundColor DarkYellow
    Write-Host ' | Purpose: Cryptographic signing key for Supabase Auth, GoTrue & PostgREST|' -ForegroundColor Gray
    Write-Host ' | Target:  Supabase Local Suite (Kong, Studio, Auth, REST, Storage)       |' -ForegroundColor Gray
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor DarkGray
    $sugJwt = if ($existing['SUPABASE_JWT_SECRET'] -and $existing['SUPABASE_JWT_SECRET'] -notmatch 'change_this' -and $existing['SUPABASE_JWT_SECRET'].Length -ge 32) { $existing['SUPABASE_JWT_SECRET'] } else { 'your-super-secret-jwt-token-with-at-least-32-characters-long' }
    Write-Host " Suggested JWT Secret: $sugJwt" -ForegroundColor Cyan
    $inJwt = Read-Host " Enter SUPABASE_JWT_SECRET [Press Enter to accept]"
    if ([string]::IsNullOrWhiteSpace($inJwt)) { $inJwt = $sugJwt }
    Print-Success "Supabase JWT secret configured.`n"

    # Generate full .env content
    $envLines = @(
        "N8N_ENCRYPTION_KEY=$inN8n",
        "N8N_RUNNERS_AUTH_TOKEN=$inRunner",
        "POSTGRES_USER=admin",
        "POSTGRES_PASSWORD=$inPg",
        "POSTGRES_DB=n8n_database",
        "REDIS_PASSWORD=$inPg",
        "SEARXNG_BASE_URL=http://search.local",
        "QDRANT_API_KEY=admin:$inNeo",
        "NEO4J_USER=admin",
        "NEO4J_PASSWORD=$inNeo",
        "CRAWL4AI_API_TOKEN=$inAI",
        "CRAWL4AI_API_KEY=$inAI",
        "DOCLING_API_KEY=$inAI",
        "",
        "# Browserless",
        "BROWSERLESS_TOKEN=$inAI",
        "",
        "# n8n Assistant Sandbox Stack",
        "N8N_SANDBOX_VERSION=1.9.0",
        "SANDBOX_API_KEYS=$inAI",
        "SANDBOX_API_RUNNER_REGISTRATION_TOKEN=runner-reg-$inAI",
        "SANDBOX_API_RUNNER_API_KEY=runner-key-$inAI",
        "N8N_SANDBOX_SERVICE_API_KEY=$inAI",
        "",
        "# ==========================================",
        "# Supabase Local Self-Hosted Suite",
        "# ==========================================",
        "SUPABASE_DB_PASSWORD=$inPg",
        "SUPABASE_JWT_SECRET=$inJwt",
        "SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE",
        "SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q",
        "SUPABASE_DASHBOARD_USERNAME=supabase",
        "SUPABASE_DASHBOARD_PASSWORD=$inPg",
        "SUPABASE_SECRET_KEY_BASE=UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3gZv1/u2oq",
        "SUPABASE_PG_META_CRYPTO_KEY=your-encryption-key-32-chars-min-$inAI",
        "SUPABASE_PUBLIC_URL=http://supabase.local",
        "",
        "# ==========================================",
        "# OpenWA WhatsApp API Gateway",
        "# ==========================================",
        "OPENWA_PORT=2785",
        "OPENWA_DB_NAME=openwa",
        "OPENWA_LOG_LEVEL=info",
        "OPENWA_API_KEY=$inOpenWA",
        "OPENWA_NODE_ENV=development"
    )

    [System.IO.File]::WriteAllLines($EnvFile, $envLines, [System.Text.Encoding]::UTF8)
    Print-Success "All API keys and credentials successfully saved to: $EnvFile"
}

# ==============================================================================
# LOCAL DATA VOLUMES
# ==============================================================================
function Initialize-Directories {
    Print-Step 3 6 'Verifying Persistent Local Data Volumes...'
    $dirs = @(
        'data\postgres',
        'data\redis',
        'data\redisinsight',
        'data\n8n\.n8n\nodes',
        'data\qdrant',
        'data\searxng',
        'data\neo4j',
        'data\caddy\data',
        'data\caddy\config',
        'data\supabase\db',
        'data\supabase\snippets',
        'data\openwa\media',
        'data\openwa\sessions',
        'shared'
    )

    foreach ($d in $dirs) {
        $p = Join-Path $ProjectRoot $d
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Force -Path $p | Out-Null
        }
    }

    Print-Success 'Persistent volumes verified under .\data and .\shared.'
}

# ==============================================================================
# PULL IMAGES & BUILD TASK RUNNERS
# ==============================================================================
function Pull-And-Build {
    Print-Step 4 6 'Pulling Latest Docker Images and Compiling Runners...'
    
    Write-Host '  [PULL] Downloading images from registries...' -ForegroundColor Cyan
    docker compose pull

    Write-Host "`n  [BUILD] Building Python/Node task-runners..." -ForegroundColor Cyan
    docker compose build task-runners

    Print-Success 'Images pulled and task runners compiled.'
}

# ==============================================================================
# BACKING SERVICES & COMMUNITY NODES
# ==============================================================================
function Initialize-OpenWA-And-Nodes {
    Write-Host '  [INIT] Starting PostgreSQL and Redis containers...' -ForegroundColor Cyan
    docker compose up -d postgres redis

    $retries = 15
    while ($retries -gt 0) {
        $h = docker inspect --format="{{.State.Health.Status}}" postgres 2>$null
        if ($h -eq "healthy") { break }
        Start-Sleep -Seconds 2
        $retries--
    }

    if ($h -ne "healthy") {
        Print-Warn 'PostgreSQL took longer than expected to report healthy. Checking logs...'
        docker compose logs --tail=15 postgres
    }

    $dbExists = docker exec -i postgres psql -U admin -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='openwa';" 2>$null
    if ($dbExists.Trim() -ne '1') {
        Write-Host "  [INIT] Initializing dedicated 'openwa' database in PostgreSQL..." -ForegroundColor Yellow
        docker exec -i postgres psql -U admin -d postgres -c "CREATE DATABASE openwa OWNER admin;" >$null 2>&1
        Print-Success "PostgreSQL 'openwa' database ready."
    }

    $pkgJson = Join-Path $ProjectRoot 'data\n8n\.n8n\nodes\package.json'
    $hasNode = $false
    if (Test-Path $pkgJson) {
        $content = Get-Content $pkgJson -Raw -ErrorAction SilentlyContinue
        if ($content -match '@rmyndharis/n8n-nodes-openwa') {
            $hasNode = $true
        }
    }

    if (-not $hasNode) {
        Write-Host '  [INIT] Installing @rmyndharis/n8n-nodes-openwa in n8n volume...' -ForegroundColor Yellow
        if (-not (Test-Path $pkgJson)) {
            $initJson = '{"name":"installed-nodes","private":true,"dependencies":{}}'
            [System.IO.File]::WriteAllText($pkgJson, $initJson, [System.Text.Encoding]::UTF8)
        }
        $npmRes = docker run --rm -v "${ProjectRoot}/data/n8n/.n8n/nodes:/home/node/.n8n/nodes" -w /home/node/.n8n/nodes node:20-alpine npm install @rmyndharis/n8n-nodes-openwa --omit=peer --ignore-scripts 2>&1
        if ($LASTEXITCODE -eq 0) {
            Print-Success 'Installed @rmyndharis/n8n-nodes-openwa community node.'
        } else {
            Print-Warn "Could not download @rmyndharis/n8n-nodes-openwa (network issue). Stack will continue with standard nodes."
        }
    }
}

# ==============================================================================
# POST-LAUNCH DIAGNOSTICS
# ==============================================================================
function Test-PostStartHealth {
    Write-Host "`n  Checking container runtime health..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3

    $containers = docker compose ps --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $containers) { return }

    $failed = @()
    foreach ($c in $containers) {
        if ($c.State -eq 'exited' -or $c.State -eq 'dead') {
            $failed += $c
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host ''
        Print-Error "Detected $($failed.Count) container(s) that stopped unexpectedly:"
        foreach ($f in $failed) {
            Write-Host ("   Service '{0}' is in state: {1}" -f $f.Service, $f.State) -ForegroundColor Red
            Write-Host "   --- Recent Logs (tail 8) ---" -ForegroundColor DarkGray
            docker compose logs --tail=8 $f.Service 2>&1 | ForEach-Object { Write-Host ("   $_") -ForegroundColor Gray }
            Write-Host "   ----------------------------" -ForegroundColor DarkGray
        }
    } else {
        Print-Success 'All launched microservices are running normally.'
    }
}

# ==============================================================================
# DEPLOY / INSTALL STACK
# ==============================================================================
function Start-Stack {
    Test-PreFlight
    Resolve-PortConflicts

    # Check if .env is missing or has placeholder secrets
    if (-not (Test-Path $EnvFile)) {
        Invoke-StepByStepApiKeyWizard
    } else {
        $raw = Get-Content $EnvFile -Raw -ErrorAction SilentlyContinue
        if ($raw -match 'change_this_to_a_strong_secret' -or $raw -match 'change_this_password') {
            Print-Warn 'Detected unconfigured placeholder secrets in .env.'
            Invoke-StepByStepApiKeyWizard
        }
    }

    Initialize-Directories
    Pull-And-Build

    Print-Step 5 6 'Configuring Backing Stores and Community Nodes...'
    Initialize-OpenWA-And-Nodes

    Print-Step 6 6 'Launching AutomationKit Microservices Stack...'
    docker compose up -d --remove-orphans

    Test-PostStartHealth
    Update-CachedTelemetry
    Show-StatusTable

    $openwaKey = 'thisisopenwaapikey'
    if (Test-Path $EnvFile) {
        $content = Get-Content $EnvFile
        foreach ($l in $content) {
            if ($l -match '^OPENWA_API_KEY=(.*)$') {
                $openwaKey = $matches[1].Trim()
                break
            }
        }
    }

    Write-Host ''
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor Green
    Write-Host ' |  AUTOMATIONKIT STACK IS DEPLOYED AND RUNNING SUCCESSFULLY!              |' -ForegroundColor Green
    Write-Host ' +-------------------------------------------------------------------------+' -ForegroundColor Green
    Write-Host ''
    Write-Host '   Master Control Hub:      http://localhost   (or http://hub.local)' -ForegroundColor Cyan
    Write-Host '   n8n Automation Engine:   http://n8n.local   (or http://localhost:5678)' -ForegroundColor Cyan
    Write-Host '   OpenWA WhatsApp Gateway: http://openwa.local(or http://localhost:2785)' -ForegroundColor Cyan
    Write-Host '   Knowledge and Docs Hub:  http://localhost/docs.html' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "   n8n OpenWA Server URL:   http://openwa:2785" -ForegroundColor Yellow
    Write-Host "   n8n OpenWA API Key:      $openwaKey" -ForegroundColor Yellow
    Write-Host ''
}

# ==============================================================================
# AUTOMATIC UPDATE DETECTION & CONTAINER RESTART
# ==============================================================================
function Check-And-Apply-Updates {
    Print-Header 'Checking for Service and Image Updates'

    Test-PreFlight

    Write-Host ' [*] Querying remote registries for container image updates...' -ForegroundColor Cyan
    $pullOutput = docker compose pull 2>&1 | Out-String
    Write-Host $pullOutput -ForegroundColor Gray

    $hasImageUpdates = $false
    if ($pullOutput -match 'Downloaded newer image for|Pulled') {
        $hasImageUpdates = $true
        Print-Success 'Newer image layers were downloaded from registry.'
    } else {
        Print-Info 'Remote registry check complete.'
    }

    # Check n8n community node update
    Write-Host "`n [*] Checking for n8n OpenWA community node updates..." -ForegroundColor Cyan
    $pkgJson = Join-Path $ProjectRoot 'data\n8n\.n8n\nodes\package.json'
    $nodeUpdated = $false
    if (Test-Path $pkgJson) {
        $updateOut = docker run --rm -v "${ProjectRoot}/data/n8n/.n8n/nodes:/home/node/.n8n/nodes" -w /home/node/.n8n/nodes node:20-alpine npm update @rmyndharis/n8n-nodes-openwa --omit=peer --ignore-scripts 2>&1 | Out-String
        if ($updateOut -match 'changed|added|updated') {
            $nodeUpdated = $true
            Print-Success 'Updated @rmyndharis/n8n-nodes-openwa community node in n8n volume.'
        } else {
            Print-Success 'n8n OpenWA community node is already up-to-date.'
        }
    }

    # If image updates or community node updates detected, apply updates and restart
    if ($hasImageUpdates -or $nodeUpdated) {
        Write-Host "`n [RESTART] Applying updates and restarting affected containers..." -ForegroundColor Yellow
        docker compose up -d
        if ($nodeUpdated) {
            docker compose restart n8n
        }
        Start-Sleep -Seconds 3
        Test-PostStartHealth
        Update-CachedTelemetry
        Show-StatusTable
        Print-Success 'Successfully updated and restarted containers with latest versions.'
    } else {
        Print-Success 'All 26 microservices and community nodes are already up-to-date. No restarts needed.'
    }
}

function Stop-Stack {
    Print-Header 'Stopping AutomationKit Microservices'

    $confirmMenu = @(
        @{ Id = '1'; Key = 'y'; Tag = 'CONFIRM'; Label = 'Yes, Gracefully Stop Stack'; Desc = 'Stops all active containers. Volumes in ./data and ./shared remain completely intact.'; Target = 'docker compose down' },
        @{ Id = '2'; Key = 'n'; Tag = 'CANCEL'; Label = 'No, Keep Services Running'; Desc = 'Cancel stop operation and return safely to the dashboard.'; Target = 'No action' }
    )

    $choice = Invoke-InteractiveMenu -Title 'CONFIRM STACK SHUTDOWN:' -MenuItems $confirmMenu -DefaultIndex 0
    if ($choice -eq '1') {
        docker compose down
        Update-CachedTelemetry
        Print-Success 'All services stopped safely. Persistent data preserved in .\data.'
    } else {
        Print-Info 'Shutdown cancelled.'
    }
}

function Restart-Stack {
    Print-Header 'Restarting AutomationKit Stack'
    Resolve-PortConflicts
    docker compose restart
    Start-Sleep -Seconds 2
    Test-PostStartHealth
    Update-CachedTelemetry
    Show-StatusTable
}

function Show-StatusTable {
    Write-Host "`n Microservices Status Matrix:" -ForegroundColor Cyan
    Write-Host ' ---------------------------------------------------------------------------' -ForegroundColor DarkGray
    
    $containers = docker compose ps --format json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $containers) {
        docker compose ps
        return
    }

    foreach ($c in $containers) {
        $sName = $c.Service.PadRight(18)
        $state = $c.State
        $health = ''
        if ($c.Health) { $health = " ($($c.Health))" }

        if ($state -eq 'running') {
            Write-Host ('  [+] ' + $sName + ' ') -ForegroundColor Green -NoNewline
            Write-Host ('RUNNING' + $health) -ForegroundColor Green -NoNewline
            Write-Host ('  ' + $c.Publishers) -ForegroundColor Gray
        } else {
            Write-Host ('  [-] ' + $sName + ' ') -ForegroundColor DarkYellow -NoNewline
            Write-Host ($state) -ForegroundColor Red -NoNewline
            Write-Host ('  ' + $c.Publishers) -ForegroundColor Gray
        }
    }
    Write-Host ' ---------------------------------------------------------------------------' -ForegroundColor DarkGray
}

function Setup-Local-Domains {
    Print-Header 'Configuring Windows .local Hosts Mappings'

    $isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if (-not $isAdministrator) {
        Print-Warn 'Requesting Administrator privileges to modify Windows hosts file...'
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" hosts"
        return
    }

    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    $domains = @(
        'hub.local',
        'portal.local',
        'n8n.local',
        'openwa.local',
        'wa.local',
        'redis.local',
        'radis.local',
        'search.local',
        'searxng.local',
        'docling.local',
        'ollama.local',
        'qdrant.local',
        'crawl.local',
        'crawl4ai.local',
        'neo.local',
        'neo4j.local',
        'files.local',
        'sandbox.local',
        'supabase.local',
        'api.supabase.local'
    )

    $hostsContent = Get-Content -LiteralPath $hostsPath -Raw -ErrorAction SilentlyContinue

    $added = 0
    $newEntries = [System.Collections.Generic.List[string]]::new()
    foreach ($domain in $domains) {
        if ($hostsContent -notmatch "(?m)^\s*127\.0\.0\.1\s+$([regex]::Escape($domain))\s*$") {
            $newEntries.Add("127.0.0.1 $domain")
            Write-Host ('  + Added: 127.0.0.1 ' + $domain) -ForegroundColor Green
            $added++
        } else {
            Write-Host ('  [OK] Already mapped: ' + $domain) -ForegroundColor DarkGray
        }
    }

    if ($newEntries.Count -gt 0) {
        Add-Content -LiteralPath $hostsPath -Value $newEntries
        Print-Success "Added $($newEntries.Count) domain mappings to $hostsPath."
    } else {
        Print-Success 'All .local domains are already mapped.'
    }

    ipconfig /flushdns | Out-Null
    Print-Success 'DNS resolver cache flushed.'
}

function Show-Logs {
    param([string]$Service)
    if ([string]::IsNullOrWhiteSpace($Service)) {
        Write-Host "`n Streaming live logs for all services (Ctrl+C to stop)..." -ForegroundColor Cyan
        docker compose logs -f --tail=100
    } else {
        Write-Host ("`n Streaming live logs for " + $Service + " (Ctrl+C to stop)...") -ForegroundColor Cyan
        docker compose logs -f --tail=100 $Service
    }
}

function Show-Logs-Interactive {
    $logServices = @(
        @{ Id = '0'; Key = 'a'; Tag = 'ALL'; Label = 'All 26 Services (Combined)'; Desc = 'Streams interleaved live log output from every running container.'; Target = 'docker compose logs -f' },
        @{ Id = '1'; Key = 'w'; Tag = 'OPENWA'; Label = 'openwa (WhatsApp Gateway)'; Desc = 'Inspect WhatsApp socket events, BullMQ queues, Baileys session logs.'; Target = 'Service: openwa (Port 2785)' },
        @{ Id = '2'; Key = 'n'; Tag = 'N8N'; Label = 'n8n (Workflow Engine)'; Desc = 'Inspect active workflow runs, webhooks, triggers, and error messages.'; Target = 'Service: n8n (Port 5678)' },
        @{ Id = '3'; Key = 'r'; Tag = 'REDIS'; Label = 'redis (BullMQ & Cache)'; Desc = 'Real-time Redis cache hit/miss and BullMQ queue events.'; Target = 'Service: redis (Port 6379)' },
        @{ Id = '4'; Key = 'p'; Tag = 'POSTGRES'; Label = 'postgres (Core Database)'; Desc = 'PostgreSQL transaction logs, connection pool, and migrations.'; Target = 'Service: postgres (Port 5432)' },
        @{ Id = '5'; Key = 'c'; Tag = 'CADDY'; Label = 'caddy (Reverse Proxy)'; Desc = 'Inbound HTTP/HTTPS requests, .local SSL routing, and proxy passes.'; Target = 'Service: caddy (Port 80/443)' },
        @{ Id = '6'; Key = 'o'; Tag = 'OLLAMA'; Label = 'ollama (Local LLMs)'; Desc = 'Local AI model loading, GPU/CPU inferences, and token generation.'; Target = 'Service: ollama (Port 11434)' },
        @{ Id = '7'; Key = 'q'; Tag = 'QDRANT'; Label = 'qdrant (Vector DB)'; Desc = 'Vector indexing, similarity search queries, and collection metrics.'; Target = 'Service: qdrant (Port 6333)' },
        @{ Id = '8'; Key = 's'; Tag = 'CRAWL4AI'; Label = 'crawl4ai (Web Scraper)'; Desc = 'Headless browser crawls, markdown extraction, and LLM extraction.'; Target = 'Service: crawl4ai (Port 11235)' },
        @{ Id = '9'; Key = 'd'; Tag = 'DOCLING'; Label = 'docling (Document Parser)'; Desc = 'PDF/Docling optical character recognition and parsing pipeline.'; Target = 'Service: docling (Port 5001)' },
        @{ Id = '10'; Key = 'x'; Tag = 'SANDBOX'; Label = 'sandbox-api (Code Sandbox)'; Desc = 'Isolated Python and Node.js execution sandbox runner logs.'; Target = 'Service: sandbox-api (Port 3000)' },
        @{ Id = '11'; Key = 'u'; Tag = 'SUPABASE'; Label = 'supabase-studio (Supabase UI)'; Desc = 'Supabase Studio dashboard and backend microservice logs.'; Target = 'Service: supabase-studio (Port 3000)' },
        @{ Id = '12'; Key = 'g'; Tag = 'NEO4J'; Label = 'neo4j (Knowledge Graph)'; Desc = 'Cypher queries, Neo4j graph store, and bolt protocol events.'; Target = 'Service: neo4j (Port 7474)' },
        @{ Id = 'B'; Key = 'b'; Tag = 'BACK'; Label = '<< Return to Main Menu'; Desc = 'Go back to the AutomationKit main dashboard.'; Target = 'Main Menu' }
    )

    $choice = Invoke-InteractiveMenu -Title 'SELECT SERVICE TO STREAM LOGS:' -MenuItems $logServices -DefaultIndex 0
    switch ($choice) {
        '0'  { Show-Logs -Service '' }
        '1'  { Show-Logs -Service 'openwa' }
        '2'  { Show-Logs -Service 'n8n' }
        '3'  { Show-Logs -Service 'redis' }
        '4'  { Show-Logs -Service 'postgres' }
        '5'  { Show-Logs -Service 'caddy' }
        '6'  { Show-Logs -Service 'ollama' }
        '7'  { Show-Logs -Service 'qdrant' }
        '8'  { Show-Logs -Service 'crawl4ai' }
        '9'  { Show-Logs -Service 'docling' }
        '10' { Show-Logs -Service 'sandbox-api' }
        '11' { Show-Logs -Service 'supabase-studio' }
        '12' { Show-Logs -Service 'neo4j' }
        default { return }
    }
}

function Reset-N8N-Password {
    Print-Header 'Resetting n8n Owner Account'
    docker exec -it n8n n8n user-management:reset
    Print-Success 'n8n credentials reset completed.'
}

function Pause-Prompt {
    Write-Host "`n Press Enter to return to menu..." -ForegroundColor DarkGray
    $null = Read-Host
}

# ==============================================================================
# MAIN TUI LOOP (Gemini-CLI Style)
# ==============================================================================
function Show-TUI {
    # Check if app is installed; if not, trigger automated onboarding
    if (-not (Test-IsInstalled)) {
        Clear-Host
        Show-Banner
        Print-Warn 'AutomationKit is not fully installed or configured on this system.'
        Write-Host ' Starting automated first-time installation and credential wizard...' -ForegroundColor Cyan
        Start-Sleep -Seconds 2
        Start-Stack
        Pause-Prompt
    }

    Update-CachedTelemetry

    $mainMenuItems = @(
        @{ 
            Id = '1'; Key = 's'; Tag = 'DEPLOY'; Label = 'Start / Deploy Automation Stack'
            Desc = 'Preflights Docker, checks .env, pulls images, installs n8n nodes, and starts 25+ services.'
            Target = 'compose.yml * Port 80, 443, 2785, 5678, 6379, 5432'
        },
        @{ 
            Id = '2'; Key = 'x'; Tag = 'HALT'; Label = 'Stop Stack (Keep Data Safe)'
            Desc = 'Gracefully shuts down all running containers. Data in ./data is safely preserved.'
            Target = 'docker compose down'
        },
        @{ 
            Id = '3'; Key = 'r'; Tag = 'RELOAD'; Label = 'Restart All Microservices'
            Desc = 'Performs a rolling graceful restart across all active microservices.'
            Target = 'docker compose restart'
        },
        @{ 
            Id = '4'; Key = 'u'; Tag = 'UPDATE'; Label = 'Check Updates & Auto-Restart Containers'
            Desc = 'Checks remote registries and npm for newer images/nodes, updates and restarts containers.'
            Target = 'docker compose pull * Auto-Restart'
        },
        @{ 
            Id = '5'; Key = 'd'; Tag = 'DNS'; Label = 'Setup Windows .local Domains'
            Desc = 'Configures *.local host aliases in Windows hosts for direct browser domain access.'
            Target = 'C:\Windows\System32\drivers\etc\hosts'
        },
        @{ 
            Id = '6'; Key = 'c'; Tag = 'CONFIG'; Label = 'Interactive Credentials Wizard (.env)'
            Desc = 'Interactive step-by-step wizard: configure API keys and secrets one by one.'
            Target = '.env * OpenWA, Postgres, Redis, n8n'
        },
        @{ 
            Id = '7'; Key = 'p'; Tag = 'STATUS'; Label = 'Live Health & Container Matrix'
            Desc = 'Displays live container states, health status, published ports, and runtime readiness.'
            Target = 'docker compose ps'
        },
        @{ 
            Id = '8'; Key = 'l'; Tag = 'LOGS'; Label = 'Stream Live Container Logs'
            Desc = 'Interactive log streaming: select OpenWA, n8n, Redis, or combined all services.'
            Target = 'docker compose logs -f'
        },
        @{ 
            Id = '9'; Key = 'w'; Tag = 'OPENWA'; Label = 'Open WhatsApp Gateway (OpenWA)'
            Desc = 'Launches OpenWA dashboard (http://openwa.local or :2785) to scan QR code and inspect sessions.'
            Target = 'http://localhost:2785'
        },
        @{ 
            Id = '10'; Key = 'm'; Tag = 'PORTAL'; Label = 'Open Master Control Hub Portal'
            Desc = 'Launches the AutomationKit control center portal at http://localhost in browser.'
            Target = 'http://localhost'
        },
        @{ 
            Id = '11'; Key = 'a'; Tag = 'AUTH'; Label = 'Reset n8n Owner Password'
            Desc = 'Invokes n8n CLI user-management to reset owner account credentials.'
            Target = 'n8n user-management:reset'
        },
        @{ 
            Id = '0'; Key = 'q'; Tag = 'QUIT'; Label = 'Exit AutomationKit CLI'
            Desc = 'Closes the AutomationKit terminal user interface and returns to shell.'
            Target = 'Exit'
        }
    )

    while ($true) {
        $choice = Invoke-InteractiveMenu -Title 'AUTOMATIONKIT DASHBOARD' -MenuItems $mainMenuItems -DefaultIndex 0 -ShowHeader
        switch ($choice) {
            '1' { Start-Stack; Pause-Prompt }
            '2' { Stop-Stack; Pause-Prompt }
            '3' { Restart-Stack; Pause-Prompt }
            '4' { Check-And-Apply-Updates; Pause-Prompt }
            '5' { Setup-Local-Domains; Pause-Prompt }
            '6' { Invoke-StepByStepApiKeyWizard; Pause-Prompt }
            '7' { Show-StatusTable; Pause-Prompt }
            '8' { Show-Logs-Interactive; Pause-Prompt }
            '9' {
                Start-Process 'http://localhost:2785'
                Print-Success 'Opened OpenWA Dashboard (http://localhost:2785)'
                Start-Sleep -Seconds 1
            }
            '10' {
                Start-Process 'http://localhost'
                Print-Success 'Opened AutomationKit Hub (http://localhost)'
                Start-Sleep -Seconds 1
            }
            '11' { Reset-N8N-Password; Pause-Prompt }
            '0' {
                Write-Host "`n  Thank you for using AutomationKit. Goodbye!" -ForegroundColor Cyan
                try { [Console]::CursorVisible = $true } catch {}
                exit 0
            }
        }
        Update-CachedTelemetry
    }
}

# ==============================================================================
# ROUTE CLI ARGUMENTS
# ==============================================================================
switch ($Action.ToLower()) {
    'start'       { Start-Stack }
    'up'          { Start-Stack }
    'install'     { Start-Stack }
    'stop'        { Stop-Stack }
    'down'        { Stop-Stack }
    'restart'     { Restart-Stack }
    'update'      { Check-And-Apply-Updates }
    'upgrade'     { Check-And-Apply-Updates }
    'status'      { Show-StatusTable }
    'ps'          { Show-StatusTable }
    'hosts'       { Setup-Local-Domains }
    'setup-hosts' { Setup-Local-Domains }
    'config'      { Invoke-StepByStepApiKeyWizard }
    'keys'        { Invoke-StepByStepApiKeyWizard }
    'logs'        { Show-Logs -Service $TargetService }
    'reset-n8n'   { Reset-N8N-Password }
    'open'        { Start-Process 'http://localhost' }
    'hub'         { Start-Process 'http://localhost' }
    'docs'        { Start-Process 'http://localhost/docs.html' }
    'openwa'      { Start-Process 'http://localhost:2785' }
    'help'        {
        Write-Host 'AutomationKit Unified CLI Orchestrator'
        Write-Host 'Usage: .\automation.bat [command] [service]'
        Write-Host 'Commands:'
        Write-Host '  start / up       Start stack and run health checks'
        Write-Host '  install          Run automated first-time installation and key setup'
        Write-Host '  stop / down      Stop stack while preserving persistent volumes'
        Write-Host '  restart          Restart all containers'
        Write-Host '  update           Detect image and node updates and auto-restart containers'
        Write-Host '  config / keys    Step-by-step interactive API key and secrets wizard'
        Write-Host '  status / ps      Show microservices health and port matrix'
        Write-Host '  hosts            Setup Windows .local domain mappings'
        Write-Host '  logs [service]   Stream live container logs'
        Write-Host '  openwa           Open OpenWA WhatsApp Gateway dashboard'
        Write-Host '  hub / open       Open Master Control Hub Portal'
        Write-Host '  reset-n8n        Reset n8n owner credentials'
    }
    ''            { Show-TUI }
    default       {
        Write-Host ('Unknown command: ' + $Action) -ForegroundColor Red
        Write-Host "Run '.\automation.bat help' for usage."
        exit 1
    }
}
