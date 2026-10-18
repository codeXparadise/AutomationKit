# Self-elevate to Administrator cleanly without throw or red errors
$isAdministrator = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdministrator) {
    Write-Host "Requesting Administrator privileges to update Windows hosts file..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$domains = @(
    'hub.local',
    'portal.local',
    'n8n.local',
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

$newEntries = [System.Collections.Generic.List[string]]::new()
foreach ($domain in $domains) {
    if ($hostsContent -notmatch "(?m)^\s*127\.0\.0\.1\s+$([regex]::Escape($domain))\s*$") {
        $newEntries.Add("127.0.0.1 $domain")
        Write-Host "Adding: 127.0.0.1 $domain" -ForegroundColor Green
    } else {
        Write-Host "Already mapped: $domain" -ForegroundColor Gray
    }
}

if ($newEntries.Count -gt 0) {
    Add-Content -LiteralPath $hostsPath -Value $newEntries
    Write-Host "`nSuccessfully added $($newEntries.Count) local domains to hosts file!" -ForegroundColor Green
} else {
    Write-Host "`nAll domains are already properly mapped in hosts file." -ForegroundColor Green
}

ipconfig /flushdns | Out-Null
Write-Host "DNS cache flushed." -ForegroundColor Cyan
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host " SUCCESS! All .local domains are now active:" -ForegroundColor Green
Write-Host "   n8n:           http://n8n.local" -ForegroundColor White
Write-Host "   Supabase:      http://supabase.local (API: http://api.supabase.local)" -ForegroundColor White
Write-Host "   Redis Insight: http://radis.local or http://redis.local" -ForegroundColor White
Write-Host "   Search:        http://search.local" -ForegroundColor White
Write-Host "   Qdrant:        http://qdrant.local" -ForegroundColor White
Write-Host "   Neo4j:         http://neo.local" -ForegroundColor White
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "`nPress any key to close this window..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
