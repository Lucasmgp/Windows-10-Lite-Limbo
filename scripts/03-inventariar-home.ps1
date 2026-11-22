param(
    [Parameter(Mandatory = $true)]
    [string]$IsoPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportDirectory
)

$ErrorActionPreference = "Stop"
$isoMounted = $false
$imageMounted = $false
$mountDir = Join-Path $env:RUNNER_TEMP "win10-home-mount"
$workWim = Join-Path $env:RUNNER_TEMP "win10-home-index1.wim"

function Invoke-DismReport {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [string]$OutputPath
    )

    Write-Host "Executando inventario: $Name"
    $result = & dism.exe @Arguments 2>&1
    $code = $LASTEXITCODE
    $result | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    if ($code -ne 0) {
        throw "DISM falhou em '$Name'. Codigo: $code. Consulte $OutputPath"
    }
}

try {
    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null

    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
        throw "Arquivo ISO nao encontrado."
    }

    $expectedSize = 4100302848
    $expectedSha256 = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"
    $isoFile = Get-Item -LiteralPath $IsoPath

    if ($isoFile.Length -ne $expectedSize) {
        throw "Tamanho inesperado da ISO: $($isoFile.Length) bytes."
    }

    $hash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $expectedSha256) {
        throw "SHA256 divergente. A ISO foi rejeitada."
    }

    Write-Host "ISO validada por tamanho e SHA256." -ForegroundColor Green

    $diskImage = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $isoMounted = $true
    $volume = $diskImage | Get-Volume
    if (-not $volume.DriveLetter) {
        throw "Nao foi possivel identificar a unidade da ISO."
    }

    $isoRoot = "$($volume.DriveLetter):\"
    $sourceWim = Join-Path $isoRoot "sources\install.wim"
    $sourceEsd = Join-Path $isoRoot "sources\install.esd"

    if (Test-Path -LiteralPath $sourceWim) {
        $sourceImage = $sourceWim
    }
    elseif (Test-Path -LiteralPath $sourceEsd) {
        $sourceImage = $sourceEsd
    }
    else {
        throw "Nao foi encontrado install.wim nem install.esd."
    }

    $info = & dism.exe /English /Get-WimInfo "/WimFile:$sourceImage" "/Index:1" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel confirmar o indice 1 da imagem."
    }
    $info | Set-Content -LiteralPath (Join-Path $ReportDirectory "00-edicao-home.txt") -Encoding UTF8

    Write-Host "Exportando somente o indice 1 (Windows 10 Home) para area temporaria."
    $export = & dism.exe /English /Export-Image "/SourceImageFile:$sourceImage" /SourceIndex:1 "/DestinationImageFile:$workWim" /Compress:max /CheckIntegrity 2>&1
    $exportCode = $LASTEXITCODE
    $export | ForEach-Object { Write-Host $_ }
    if ($exportCode -ne 0) {
        throw "Falha ao exportar o indice 1. Codigo DISM: $exportCode"
    }

    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
    $mount = & dism.exe /English /Mount-Image "/ImageFile:$workWim" /Index:1 "/MountDir:$mountDir" /ReadOnly 2>&1
    $mountCode = $LASTEXITCODE
    $mount | ForEach-Object { Write-Host $_ }
    if ($mountCode -ne 0) {
        throw "Falha ao montar a imagem Home. Codigo DISM: $mountCode"
    }
    $imageMounted = $true

    Invoke-DismReport -Name "Pacotes" -Arguments @("/English", "/Image:$mountDir", "/Get-Packages", "/Format:Table") -OutputPath (Join-Path $ReportDirectory "01-pacotes.txt")
    Invoke-DismReport -Name "Recursos do Windows" -Arguments @("/English", "/Image:$mountDir", "/Get-Features", "/Format:Table") -OutputPath (Join-Path $ReportDirectory "02-recursos.txt")
    Invoke-DismReport -Name "Capacidades opcionais" -Arguments @("/English", "/Image:$mountDir", "/Get-Capabilities", "/Format:Table") -OutputPath (Join-Path $ReportDirectory "03-capacidades.txt")

    $appxCsv = Join-Path $ReportDirectory "04-aplicativos-provisionados.csv"
    try {
        $appx = Get-AppxProvisionedPackage -Path $mountDir
        $appx | Select-Object DisplayName, PackageName, Version, Architecture, ResourceId, Regions |
            Export-Csv -LiteralPath $appxCsv -NoTypeInformation -Encoding UTF8
        $appx | Format-Table DisplayName, Version, Architecture -AutoSize |
            Out-String -Width 240 |
            Set-Content -LiteralPath (Join-Path $ReportDirectory "04-aplicativos-provisionados.txt") -Encoding UTF8
    }
    catch {
        "A consulta de Appx provisionados falhou neste runner: $($_.Exception.Message)" |
            Set-Content -LiteralPath (Join-Path $ReportDirectory "04-aplicativos-provisionados.txt") -Encoding UTF8
        "DisplayName,PackageName,Version,Architecture,ResourceId,Regions" |
            Set-Content -LiteralPath $appxCsv -Encoding UTF8
        Write-Warning "Nao foi possivel consultar Appx provisionados; os demais inventarios continuam."
    }

    @(
        "Inventario detalhado - Windows 10 Home 22H2 x86 pt-BR"
        "ISO SHA256: $hash"
        "ISO tamanho: $($isoFile.Length) bytes"
        "Indice analisado: 1"
        "Edicao: Windows 10 Home"
        "Modo: somente leitura"
        "Data UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))"
        ""
        "Arquivos:"
        "00-edicao-home.txt - identificacao da imagem"
        "01-pacotes.txt - pacotes e estados"
        "02-recursos.txt - recursos e estados"
        "03-capacidades.txt - capacidades opcionais"
        "04-aplicativos-provisionados.csv/.txt - aplicativos Appx provisionados"
        ""
        "Nenhum pacote, recurso ou aplicativo foi removido ou alterado."
    ) | Set-Content -LiteralPath (Join-Path $ReportDirectory "LEIA-ME.txt") -Encoding UTF8

    Write-Host "Inventario detalhado concluido." -ForegroundColor Green
}
finally {
    if ($imageMounted) {
        & dism.exe /English /Unmount-Image "/MountDir:$mountDir" /Discard | ForEach-Object { Write-Host $_ }
    }
    if ($isoMounted) {
        Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $workWim) {
        Remove-Item -LiteralPath $workWim -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $mountDir) {
        Remove-Item -LiteralPath $mountDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}
