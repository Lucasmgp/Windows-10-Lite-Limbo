param(
    [Parameter(Mandatory = $true)][string]$IsoPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$isoMounted = $false
$imageMounted = $false
$mountDir = Join-Path $env:RUNNER_TEMP "win10-home-appx-build-mount"
$workWim = Join-Path $OutputDirectory "install-home-lite.wim"
$reportDir = Join-Path $OutputDirectory "relatorios"

$candidates = @(
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

function Invoke-DismChecked {
    param([string[]]$Arguments, [string]$Description)
    Write-Host $Description
    $output = & dism.exe /English @Arguments 2>&1
    $code = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($code -ne 0) { throw "$Description falhou. Codigo DISM: $code" }
}

try {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) { throw "ISO nao encontrada." }

    $expectedSize = 4100302848
    $expectedSha256 = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"
    $isoFile = Get-Item -LiteralPath $IsoPath
    if ($isoFile.Length -ne $expectedSize) { throw "Tamanho inesperado da ISO: $($isoFile.Length)." }
    $hash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $expectedSha256) { throw "SHA256 divergente. ISO rejeitada." }
    Write-Host "ISO original validada."

    $disk = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $isoMounted = $true
    $volume = $disk | Get-Volume
    if (-not $volume.DriveLetter) { throw "Unidade da ISO nao identificada." }
    $root = "$($volume.DriveLetter):\"
    $sourceWim = Join-Path $root "sources\\install.wim"
    $sourceEsd = Join-Path $root "sources\\install.esd"
    if (Test-Path -LiteralPath $sourceWim) { $sourceImage = $sourceWim }
    elseif (Test-Path -LiteralPath $sourceEsd) { $sourceImage = $sourceEsd }
    else { throw "install.wim/install.esd nao encontrado." }

    $imageInfo = & dism.exe /English /Get-WimInfo "/WimFile:$sourceImage" /Index:1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Nao foi possivel confirmar o indice Home." }
    $imageInfo | Set-Content (Join-Path $reportDir "00-edicao-origem.txt") -Encoding UTF8

    Invoke-DismChecked -Arguments @("/Export-Image", "/SourceImageFile:$sourceImage", "/SourceIndex:1", "/DestinationImageFile:$workWim", "/Compress:max", "/CheckIntegrity") -Description "Exportando indice 1 para uma copia de trabalho"
    New-Item -ItemType Directory -Path $mountDir -Force | Out-Null
    Invoke-DismChecked -Arguments @("/Mount-Image", "/ImageFile:$workWim", "/Index:1", "/MountDir:$mountDir") -Description "Montando copia de trabalho para manutencao"
    $imageMounted = $true

    $before = @(Get-AppxProvisionedPackage -Path $mountDir)
    $beforeNames = @($before | ForEach-Object { $_.DisplayName })
    $missing = @($candidates | Where-Object { $beforeNames -notcontains $_ })
    $missingXbox = @($protectedXbox | Where-Object { $beforeNames -notcontains $_ })
    if ($missing.Count -gt 0) { throw "Candidatos ausentes antes da alteracao: $($missing -join ', ')" }
    if ($missingXbox.Count -gt 0) { throw "Componente Xbox protegido ausente na verificacao inicial: $($missingXbox -join ', ')" }

    $before | Select-Object DisplayName, PackageName, Version, Architecture |
        Export-Csv (Join-Path $reportDir "01-appx-antes.csv") -NoTypeInformation -Encoding UTF8

    $removed = foreach ($name in $candidates) {
        $package = @($before | Where-Object { $_.DisplayName -eq $name })
        if ($package.Count -ne 1) { throw "Esperado exatamente um pacote para $name; encontrados: $($package.Count)." }
        Invoke-DismChecked -Arguments @("/Image:$mountDir", "/Remove-ProvisionedAppxPackage", "/PackageName:$($package[0].PackageName)") -Description "Removendo aplicativo aprovado: $name"
        [pscustomobject]@{ DisplayName = $name; PackageName = $package[0].PackageName; Result = "COMANDO DISM CONCLUIDO" }
    }
    $removed | Export-Csv (Join-Path $reportDir "02-remocoes-executadas.csv") -NoTypeInformation -Encoding UTF8

    $after = @(Get-AppxProvisionedPackage -Path $mountDir)
    $afterNames = @($after | ForEach-Object { $_.DisplayName })
    $stillPresent = @($candidates | Where-Object { $afterNames -contains $_ })
    $xboxAfter = @($protectedXbox | Where-Object { $afterNames -contains $_ })
    $lostXbox = @($protectedXbox | Where-Object { $xboxAfter -notcontains $_ })
    if ($stillPresent.Count -gt 0) { throw "Falha: candidatos ainda provisionados: $($stillPresent -join ', ')" }
    if ($lostXbox.Count -gt 0) { throw "Falha: componente Xbox protegido ausente apos a alteracao: $($lostXbox -join ', ')" }

    $after | Select-Object DisplayName, PackageName, Version, Architecture |
        Export-Csv (Join-Path $reportDir "03-appx-depois.csv") -NoTypeInformation -Encoding UTF8

    Invoke-DismChecked -Arguments @("/Unmount-Image", "/MountDir:$mountDir", "/Commit", "/CheckIntegrity") -Description "Gravando alteracoes na copia WIM"
    $imageMounted = $false

    $finalInfo = & dism.exe /English /Get-WimInfo "/WimFile:$workWim" /Index:1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "WIM final nao passou na verificacao DISM." }
    $finalInfo | Set-Content (Join-Path $reportDir "04-validacao-wim-final.txt") -Encoding UTF8
    $wimHash = (Get-FileHash -LiteralPath $workWim -Algorithm SHA256).Hash.ToLowerInvariant()
    $wimSize = (Get-Item -LiteralPath $workWim).Length

    @(
        "BUILD Windows 10 Home 22H2 x86 pt-BR - remocao Appx aprovada"
        "ISO de origem validada: $hash"
        "Tamanho ISO original: $($isoFile.Length) bytes"
        "Aplicativos removidos: $($removed.Count)"
        "Aplicativos restantes da lista: $($stillPresent.Count)"
        "Componentes Xbox protegidos e presentes: $($xboxAfter.Count) de $($protectedXbox.Count)"
        "WIM final: install-home-lite.wim"
        "Tamanho WIM final: $wimSize bytes"
        "SHA256 WIM final: $wimHash"
        "A ISO original nao foi modificada."
        "Observacao: esta etapa gera a imagem install.wim modificada; a reconstrucao da ISO inicializavel sera uma etapa separada."
        "Data UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))"
    ) | Set-Content (Join-Path $reportDir "LEIA-ME.txt") -Encoding UTF8

    Write-Host "BUILD concluido. WIM modificado e validado." -ForegroundColor Green
}
finally {
    if ($imageMounted) {
        & dism.exe /English /Unmount-Image "/MountDir:$mountDir" /Discard | ForEach-Object { Write-Host $_ }
    }
    if ($isoMounted) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $mountDir) { Remove-Item -LiteralPath $mountDir -Recurse -Force -ErrorAction SilentlyContinue }
}
