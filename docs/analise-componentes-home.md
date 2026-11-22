# Analise do inventario - Windows 10 Home x86

Data do inventario: 2026-11-22  
Imagem: Windows 10 Home, indice 1, Windows 10 22H2 x86 pt-BR  
Versao da imagem: 10.0.19045.2965  
SHA-256 da ISO: 69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be  
Execucao: https://github.com/Lucasmgp/Windows-10-Lite-Limbo/actions/runs/45026404860

## Resumo

- 35 pacotes instalados listados pelo DISM.
- 97 recursos do Windows: 19 habilitados, 77 desabilitados e 1 desabilitado com carga removida.
- 39 aplicativos Appx provisionados.
- O inventario foi feito em imagem temporaria montada em modo somente leitura.
- Nenhuma remocao ou alteracao foi realizada.

## Recursos habilitados observados

Entre os recursos habilitados estao:
- WCF-Services45 e WCF-TCP-PortSharing45.
- MediaPlayback e WindowsMediaPlayer.
- Impressao em PDF, XPS, recursos de impressao e cliente de impressao pela Internet.
- Windows Defender - definicoes padrao.
- SearchEngine-Client-Package.
- MSRDC-Infrastructure e WorkFolders-Client.
- MicrosoftWindowsPowerShellV2Root e MicrosoftWindowsPowerShellV2.
- NetFx4-AdvSrvs.
- SMB1Protocol, SMB1Protocol-Client e SMB1Protocol-Deprecation.
- Internet-Explorer-Optional-x86.

### Ponto de seguranca: SMB1

SMB1 aparece habilitado. E um protocolo legado e inseguro. Recomendacao inicial: desabilitar/remover SMB1, a menos que exista necessidade comprovada de acessar equipamentos ou compartilhamentos muito antigos. Nao confundir SMB1 com SMB2/SMB3; nao remover os protocolos modernos.

### .NET Framework 3.5

NetFx3 aparece como "Disabled with Payload Removed". Para preservar compatibilidade com programas antigos, sera necessario planejar uma fonte confiavel de instalacao do .NET 3.5 (por exemplo, a midia original correspondente ou fonte oficial apropriada). Nao remover nem alterar .NET 4.x.

## Aplicativos Appx provisionados

### Candidatos para avaliacao de remocao (nao autorizados para remocao ainda)
- Microsoft.BingWeather
- Microsoft.Getstarted
- Microsoft.Microsoft3DViewer
- Microsoft.MicrosoftOfficeHub
- Microsoft.MicrosoftSolitaireCollection
- Microsoft.People
- Microsoft.SkypeApp
- Microsoft.Wallet
- Microsoft.WindowsMaps
- Microsoft.WindowsFeedbackHub
- Microsoft.YourPhone
- Microsoft.ZuneMusic
- Microsoft.ZuneVideo
- Microsoft.549981C3F5F10 (assistente/Cortana em versoes antigas)
- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxSpeechToTextOverlay

Os componentes Xbox TCUI e Xbox Identity Provider exigem avaliacao separada por poderem servir a jogos e autenticacao. Nao remover automaticamente.

## Componentes a preservar nesta fase

- Microsoft.WindowsStore e Microsoft.StorePurchaseApp.
- Microsoft.DesktopAppInstaller.
- Microsoft.VCLibs.140.00.
- Microsoft.MSPaint, Calculadora, Fotos, Camera, ScreenSketch e aplicativos basicos de sistema enquanto nao houver decisao.
- Extensoes de imagem/video (HEIF, VP9, WebP, WebMedia).
- Pacotes de idioma pt-BR e recursos de texto, OCR, fala e escrita.
- Pacotes de servicing stack, atualizacoes cumulativas e .NET.
- Windows Defender, Firewall, Windows Update, DISM, SFC, WMI, PowerShell, rede, armazenamento, audio, video, fontes e componentes de shell.

## Cautelas tecnicas

1. O inventario identifica o que esta presente, mas nao mede o ganho de espaco ou memoria que cada remocao traria.
2. Aplicativos Appx podem compartilhar frameworks e dependencias. A lista de candidatos nao e uma lista de comandos de remocao.
3. Recursos desabilitados nao devem ser removidos automaticamente: alguns podem ser necessarios para compatibilidade futura.
4. O .NET 3.5 esta sem payload local; nao prometer suporte sem preparar a fonte.
5. O Windows 10 22H2 encerrou o suporte geral em 14/10/2025. Para uso conectado, avaliar atualizacoes aplicaveis e protecoes; a imagem-base inventariada e de 2023.
6. Antes de personalizar, criar uma copia de trabalho, aplicar um conjunto pequeno de alteracoes e validar instalacao, inicializacao, rede, audio, video, USB, aplicativos Win32 e recursos do Limbo.

## Proxima etapa proposta

Produzir uma matriz de decisao por componente com tres grupos: preservar, candidato a remocao e manter ate teste. Depois disso, revisar a matriz com o usuario. Nenhuma remocao deve ser automatizada sem aprovacao explicita.
