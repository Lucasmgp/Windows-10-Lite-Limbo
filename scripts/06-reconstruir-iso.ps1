param(
    [Parameter(Mandatory=$true)][string]$IsoPath,
    [Parameter(Mandatory=$true)][string]$ModifiedWimPath,
    [Parameter(Mandatory=$true)][string]$OutputIsoPath,
    [Parameter(Mandatory=$true)][string]$OscdimgPath,
    [Parameter(Mandatory=$true)][string]$WorkDirectory
)
$ErrorActionPreference = "Stop"
$mounted = $false
$stage = Join-Path $WorkDirectory "iso-stage"
try {
    $expectedSize = 4100302848
    $expectedHash = "69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be"
    if ((Get-Item -LiteralPath $IsoPath).Length -ne $expectedSize) { throw "Tamanho da ISO original nao confere." }
    $actualHash = (Get-FileHash -LiteralPath $IsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) { throw "SHA256 da ISO original nao confere." }
    if (-not (Test-Path -LiteralPath $ModifiedWimPath -PathType Leaf)) { throw "WIM modificado nao encontrado." }
    if (-not (Test-Path -LiteralPath $OscdimgPath -PathType Leaf)) { throw "oscdimg.exe nao encontrado." }

    $wimInfo = & dism.exe /English /Get-WimInfo "/WimFile:$ModifiedWimPath" /Index:1 2>&1
    if ($LASTEXITCODE -ne 0 -or ($wimInfo -join "`n") -notmatch "Windows 10 Home") { throw "WIM modificado nao passou na verificacao de edicao." }

    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $disk = Mount-DiskImage -ImagePath $IsoPath -PassThru
    $mounted = $true
    $volume = $disk | Get-Volume
    if (-not $volume.DriveLetter) { throw "Unidade da ISO original nao identificada." }
    $sourceRoot = "$($volume.DriveLetter):\"
    $bootBios = Join-Path $sourceRoot "boot\etfsboot.com"
    $bootEfi = Join-Path $sourceRoot "efi\microsoft\boot\efisys.bin"
    if (-not (Test-Path -LiteralPath $bootBios)) { throw "Boot BIOS etfsboot.com ausente na ISO original." }
    if (-not (Test-Path -LiteralPath $bootEfi)) { throw "Boot UEFI efisys.bin ausente na ISO original." }

    $copy = Start-Process -FilePath "robocopy.exe" -ArgumentList @($sourceRoot,$stage,"/E","/COPY:DAT","/DCOPY:DAT","/R:1","/W:1","/NFL","/NDL","/NJH","/NJS") -Wait -PassThru -NoNewWindow
    if ($copy.ExitCode -ge 8) { throw "Falha ao copiar arquivos da ISO. Robocopy: $($copy.ExitCode)" }

    $stagedWim = Join-Path $stage "sources\install.wim"
    $stagedEsd = Join-Path $stage "sources\install.esd"
    if (Test-Path -LiteralPath $stagedWim) { (Get-Item -LiteralPath $stagedWim).Attributes = "Normal"; Remove-Item -LiteralPath $stagedWim -Force }
    if (Test-Path -LiteralPath $stagedEsd) { (Get-Item -LiteralPath $stagedEsd).Attributes = "Normal"; Remove-Item -LiteralPath $stagedEsd -Force }
    Copy-Item -LiteralPath $ModifiedWimPath -Destination $stagedWim
    if (-not (Test-Path -LiteralPath $stagedWim)) { throw "install.wim nao foi copiado para a estrutura ISO." }

    Dismount-DiskImage -ImagePath $IsoPath
    $mounted = $false
    Remove-Item -LiteralPath $IsoPath -Force
    Remove-Item -LiteralPath $ModifiedWimPath -Force

    $bootBios = Join-Path $stage "boot\etfsboot.com"
    $bootEfi = Join-Path $stage "efi\microsoft\boot\efisys.bin"
    $bootArg = "-bootdata:2#p0,e,b$bootBios#pEF,e,b$bootEfi"
    $args = @("-m","-o","-u2","-udfver102",$bootArg,$stage,$OutputIsoPath)
    $proc = Start-Process -FilePath $OscdimgPath -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw "oscdimg falhou com codigo $($proc.ExitCode)." }
    if (-not (Test-Path -LiteralPath $OutputIsoPath)) { throw "ISO final nao foi criada." }

    $finalSize = (Get-Item -LiteralPath $OutputIsoPath).Length
    $finalHash = (Get-FileHash -LiteralPath $OutputIsoPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checkMount = Mount-DiskImage -ImagePath $OutputIsoPath -PassThru
    try {
        $checkVolume = $checkMount | Get-Volume
        if (-not $checkVolume.DriveLetter) { throw "ISO final nao montou." }
        $checkRoot = "$($checkVolume.DriveLetter):\"
        if (-not (Test-Path -LiteralPath (Join-Path $checkRoot "sources\install.wim"))) { throw "install.wim ausente na ISO final." }
        if (-not (Test-Path -LiteralPath (Join-Path $checkRoot "boot\etfsboot.com"))) { throw "Boot BIOS ausente na ISO final." }
        if (-not (Test-Path -LiteralPath (Join-Path $checkRoot "efi\microsoft\boot\efisys.bin"))) { throw "Boot UEFI ausente na ISO final." }
        $finalWim = Join-Path $checkRoot "sources\install.wim"
        $verify = & dism.exe /English /Get-WimInfo "/WimFile:$finalWim" /Index:1 2>&1
        if ($LASTEXITCODE -ne 0) { throw "DISM nao conseguiu ler install.wim dentro da ISO final." }
        $verify | Set-Content (Join-Path $WorkDirectory "validacao-wim-iso-final.txt") -Encoding UTF8
    }
    finally { Dismount-DiskImage -ImagePath $OutputIsoPath -ErrorAction SilentlyContinue }

    @(
        "ISO Windows 10 Home Lite 22H2 x86 pt-BR"
        "ISO original validada SHA256: $actualHash"
        "ISO final tamanho: $finalSize bytes"
        "ISO final SHA256: $finalHash"
        "Boot BIOS: presente"
        "Boot UEFI: presente"
        "install.wim: presente e legivel pelo DISM"
        "A imagem install.wim modificada foi incorporada a estrutura original."
        "A inicializacao em uma VM ainda precisa de teste pratico."
    ) | Set-Content (Join-Path $WorkDirectory "LEIA-ME-ISO-FINAL.txt") -Encoding UTF8
    Write-Host "ISO final reconstruida e validada estruturalmente." -ForegroundColor Green
}
finally {
    if ($mounted) { Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue }
}
