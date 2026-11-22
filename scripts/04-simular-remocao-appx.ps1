param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [Parameter(Mandatory = $true)][string]$ReportDirectory
)

$ErrorActionPreference = "Stop"
$isoMounted = $false
$imageMounted = $false
$mountDir = Join-Path $env:RUNNER_TEMP "win10-home-dryrun-mount"
$workWim = Join-Path $env:RUNNER_TEMP "win10-home-dryrun.wim"

$approvedCandidates = @(
    "Microsoft.BingWeather",
    "Microsoft.Getstarted",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.People",
    "Microsoft.SkypeApp",
    "Microsoft.Wallet",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.549981C3F5F10"
)

$protectedXbox = @(
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxIdentityProvider"
)

try {
    New-Item -ItemType Directory -Path $ReportDirectory -Force | Out-Null
    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nao encontrada." }

    $expectedSize = 4100302848
    $expectedSha256 = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"
    $file = Get-Item -LiteralPath $IsoPath
    if ($file.Length -ne $expectedSize) { throw "Tamanho inesperado: $($file.Length) bytes." }
    $hash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $expectedSha256) { throw "SHA256 divergente; ISO rejeitada." }
    Write-Host "ISO validada por tamanho e SHA256."

    $disk = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $isoMounted = $true
    $volume = $disk | Get-Volume
    if (-not $volume.DriveLetter) { throw "Unidade da ISO nao identificada." }
    $root = "$($volume.DriveLetter):\\"
    $wim = Join-Path $root "sources\\install.wim"
    $esd = Join-Path $root "sources\\install.esd"
    if (Test-Path -LiteralPath $wim) { $source = $wim }
    elseif (Test-Path -LiteralPath $esd) { $source = $esd }
    else { throw "install.wim/install.esd nao encontrado." }

    $info = & dism.exe /English /Get-WimInfo "/WimFile:$source" "/Index:1" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Nao foi possivel validar o indice 1." }
    $info | Set-Content (Join-Path $ReportDirectory "00-edicao.txt") -Encoding UTF8

    $export = & dism.exe /English /Export-Image "/SourceImageFile:$source" /SourceIndex:1 "/DestinationImageFile:$workWim" /Compress:max /CheckIntegrity 2>&1
    $export | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Falha ao exportar a edicao Home para analise." }

    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
    $mount = & dism.exe /English /Mount-Image "/ImageFile:$workWim" /Index:1 "/MountDir:$mountDir" /ReadOnly 2>&1
    $mount | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "Falha ao montar imagem somente leitura." }
    $imageMounted = $true

    $installed = @(Get-AppxProvisionedPackage -Path $mountDir)
    $presentNames = @($installed | ForEach-Object { $_.DisplayName })
    $rows = foreach ($name in $approvedCandidates) {
        [pscustomobject]@{
            DisplayName = $name
            Found = ($presentNames -contains $name)
            Action = "CANDIDATO - NAO REMOVIDO"
        }
    }
    $rows | Export-Csv (Join-Path $ReportDirectory "01-simulacao-candidatos.csv") -NoTypeInformation -Encoding UTF8
    $rows | Format-Table -AutoSize | Out-String -Width 220 |
        Set-Content (Join-Path $ReportDirectory "01-simulacao-candidatos.txt") -Encoding UTF8

    $xboxRows = foreach ($name in $protectedXbox) {
        [pscustomobject]@{
            DisplayName = $name
            Found = ($presentNames -contains $name)
            Action = "PROTEGIDO - NAO REMOVER"
        }
    }
    $xboxRows | Export-Csv (Join-Path $ReportDirectory "02-componentes-xbox-protegidos.csv") -NoTypeInformation -Encoding UTF8
    $xboxRows | Format-Table -AutoSize | Out-String -Width 220 |
        Set-Content (Join-Path $ReportDirectory "02-componentes-xbox-protegidos.txt") -Encoding UTF8

    $installed | Select-Object DisplayName, PackageName, Version, Architecture |
        Export-Csv (Join-Path $ReportDirectory "03-inventario-completo.csv") -NoTypeInformation -Encoding UTF8

    $missing = @($rows | Where-Object { -not $_.Found })
    $found = @($rows | Where-Object { $_.Found })
    @(
        "SIMULACAO DRY-RUN - Windows 10 Home 22H2 x86 pt-BR"
        "ISO SHA256: $hash"
        "Tamanho: $($file.Length) bytes"
        "Modo: somente leitura; nenhuma remocao ou alteracao executada"
        "Candidatos listados: $($rows.Count)"
        "Candidatos encontrados: $($found.Count)"
        "Candidatos ausentes: $($missing.Count)"
        "Componentes Xbox protegidos: $($xboxRows.Count)"
        "Nenhum componente Xbox foi selecionado para remocao."
        "A lista e uma simulacao; dependencias funcionais ainda exigem testes."
        "Data UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))"
    ) | Set-Content (Join-Path $ReportDirectory "LEIA-ME.txt") -Encoding UTF8

    Write-Host "DRY-RUN concluido. Nenhum componente foi removido." -ForegroundColor Green
}
finally {
    if ($imageMounted) {
        & dism.exe /English /Unmount-Image "/MountDir:$mountDir" /Discard | ForEach-Object { Write-Host $_ }
    }
    if ($isoMounted) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $workWim) { Remove-Item -LiteralPath $workWim -Force -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $mountDir) { Remove-Item -LiteralPath $mountDir -Force -Recurse -ErrorAction SilentlyContinue }
}
