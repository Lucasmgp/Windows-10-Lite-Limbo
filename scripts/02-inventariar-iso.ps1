param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"
$mounted = $false

try {
    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
        throw "Arquivo ISO nao encontrado."
    }

    $expectedSize = 4100302848
    $expectedSha256 = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"

    $file = Get-Item -LiteralPath $IsoPath
    if ($file.Length -ne $expectedSize) {
        throw "Tamanho inesperado: $($file.Length) bytes."
    }

    $hash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $expectedSha256) {
        throw "SHA256 divergente. A ISO sera rejeitada."
    }

    Write-Host "Tamanho e SHA256 confirmados." -ForegroundColor Green

    $diskImage = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $mounted = $true
    $volume = $diskImage | Get-Volume
    if (-not $volume.DriveLetter) {
        throw "Nao foi possivel identificar a letra da unidade ISO."
    }

    $root = "$($volume.DriveLetter):\"
    $wimPath = Join-Path $root "sources\install.wim"
    $esdPath = Join-Path $root "sources\install.esd"

    if (Test-Path -LiteralPath $wimPath) {
        $imageFile = $wimPath
    }
    elseif (Test-Path -LiteralPath $esdPath) {
        $imageFile = $esdPath
    }
    else {
        throw "Nao foi encontrado install.wim nem install.esd em sources."
    }

    Write-Host "Arquivo de imagem localizado: $([IO.Path]::GetFileName($imageFile))"
    $dismOutput = & dism.exe /English /Get-WimInfo "/WimFile:$imageFile" 2>&1
    $dismExit = $LASTEXITCODE
    $dismOutput | ForEach-Object { Write-Host $_ }
    if ($dismExit -ne 0) {
        throw "DISM falhou ao ler as informacoes da imagem. Codigo: $dismExit"
    }

    @(
        "Inventario da ISO Windows 10 22H2 x86 pt-BR"
        "Tamanho: $($file.Length) bytes"
        "SHA256: $hash"
        "Imagem: $imageFile"
        ""
        ($dismOutput | ForEach-Object { "$_" })
    ) | Set-Content -LiteralPath $ReportPath -Encoding UTF8

    Write-Host "Inventario concluido. A ISO original nao foi modificada." -ForegroundColor Green
}
finally {
    if ($mounted) {
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    }
}
