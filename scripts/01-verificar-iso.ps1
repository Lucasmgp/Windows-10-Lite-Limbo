[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [string]$ExpectedSha256 = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Windows 10 Lite para Limbo: verificacao da ISO ===" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    throw "ISO nao encontrada: $IsoPath"
}

$item = Get-Item -LiteralPath $IsoPath
Write-Host ("Arquivo: {0}" -f $item.Name)
Write-Host ("Tamanho: {0:N0} bytes" -f $item.Length)

$hash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("SHA-256: {0}" -f $hash)

if ($ExpectedSha256 -and $hash -ne $ExpectedSha256.ToLowerInvariant()) {
    throw "SHA-256 diferente do valor esperado. Nenhuma modificacao foi realizada."
}

Write-Host "SHA-256 confere com o valor esperado." -ForegroundColor Green
Write-Host "Proxima etapa: inspecionar a estrutura ISO e o install.wim com DISM."
