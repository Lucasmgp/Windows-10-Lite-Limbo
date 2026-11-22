# Matriz de decisao - Windows 10 Home x86

Data da analise: 2026-11-22  
Imagem: Windows 10 Home, indice 1, Windows 10 22H2 x86 pt-BR  
Versao: 10.0.19045.2965 (imagem criada em 05/05/2023)  
SHA-256 da ISO: 69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be  
Execucao do inventario: https://github.com/Lucasmgp/Windows-10-Lite-Limbo/actions/runs/45026404860

> Este documento e uma proposta de classificacao, nao uma autorizacao para remover componentes. Nenhuma alteracao foi aplicada a ISO.

## 1. Resumo comprovado pelo inventario

- 35 pacotes DISM listados como instalados.
- 97 recursos do Windows: 19 habilitados, 77 desabilitados e 1 desabilitado com carga removida.
- 39 aplicativos Appx provisionados.
- A imagem foi exportada para uma copia temporaria e montada em modo somente leitura.
- Nenhum pacote, recurso ou aplicativo foi removido.

## 2. Recursos do Windows: matriz

### Preservar habilitados inicialmente

| Recurso observado | Decisao | Motivo |
|---|---|---|
| NetFx4-AdvSrvs | Preservar | Compatibilidade com aplicativos .NET Framework 4.x. |
| Windows-Defender-Default-Definitions | Preservar | Componente de seguranca. |
| SearchEngine-Client-Package | Preservar | Pesquisa do Windows e integracao com shell. |
| MediaPlayback / WindowsMediaPlayer | Preservar inicialmente | Compatibilidade de codecs, APIs e aplicativos multimidia. |
| Printing-Foundation-Features | Preservar | Infraestrutura de impressao. |
| Printing-XPSServices-Features | Preservar inicialmente | Compatibilidade com documentos e drivers que usam XPS. |
| Printing-PrintToPDFServices-Features | Preservar | Impressora PDF virtual. |
| Printing-Foundation-InternetPrinting-Client | Preservar inicialmente | Impressao em rede; baixo beneficio em remover antes dos testes. |
| WCF-Services45 / WCF-TCP-PortSharing45 | Preservar | Dependencias possiveis de aplicativos corporativos/Win32. |
| MSRDC-Infrastructure | Preservar | Componente de sistema; nao remover sem rastrear dependencias. |
| WorkFolders-Client | Manter ate teste | Recurso de sincronizacao empresarial; pode ser desnecessario, mas nao e prioridade. |

### Desabilitar ou remover somente apos decisao e teste

| Recurso observado | Proposta | Cuidado |
|---|---|---|
| SMB1Protocol / SMB1Protocol-Client | Desabilitar SMBv1; avaliar remocao do payload depois | SMBv1 e legado e vulneravel. Testar compartilhamentos antigos. Nao desabilitar SMB2/SMB3. |
| MicrosoftWindowsPowerShellV2Root / MicrosoftWindowsPowerShellV2 | Desabilitar PowerShell 2.0 | Tecnologia legada/preterida. Manter PowerShell 5.1. Testar scripts antigos. |
| Internet-Explorer-Optional-x86 | Manter payload inicialmente; desabilitar IE como recurso legado apos testes | Nao usar IE para navegacao comum. Alguns instaladores antigos podem depender de componentes. |
| WindowsMediaPlayer / MediaPlayback | Reavaliar apenas se houver prova de que nenhum aplicativo precisa | Nao retirar codecs ou APIs multimidia por deducao. |
| Printing-Foundation-InternetPrinting-Client | Reavaliar | Manter se houver impressao em rede. |

### Recursos que estao desabilitados: manter assim, sem apagar payload

Os itens abaixo ja estao desabilitados no inventario. Nao ha ganho comprovado em remover os arquivos de origem, e a remocao reduziria a capacidade de ativar recursos futuramente.

| Grupo / nomes identificados | Decisao |
|---|---|
| NetFx3 | Manter desabilitado por enquanto, mas recuperar/preparar fonte compativel para habilitacao futura. |
| LegacyComponents, DirectPlay | Manter desabilitados; ativar somente para jogos/programas antigos que solicitem. |
| NTVDM | Manter desabilitado; avaliar apenas se houver necessidade de aplicativos DOS/16-bit. |
| TFTP, SimpleTCP, TelnetClient | Manter desabilitados; habilitar apenas para diagnostico/compatibilidade pontual. |
| WCF-HTTP-Activation, WCF-NonHTTP-Activation e WCF-*Activation45 | Manter desabilitados; ativar apenas se aplicativo especifico exigir. |
| IIS-* e WAS-* | Manter desabilitados; servidor web local nao faz parte do objetivo inicial. |
| MSMQ-* | Manter desabilitados; mensageria empresarial nao e requisito definido. |
| Printing-Foundation-LPDPrintService, Printing-Foundation-LPRPortMonitor | Manter desabilitados; ativar apenas para impressoras/servidores LPR antigos. |
| TIFFIFilter, Client-ProjFS, NetFx4Extended-ASPNET45 | Manter desabilitados ate necessidade comprovada. |

**Excecao importante - .NET 3.5:** NetFx3 aparece como `Disabled with Payload Removed`. A compatibilidade com aplicativos .NET 3.5 nao esta garantida na imagem atual. Antes de qualquer personalizacao, preparar uma fonte de recursos sob demanda correspondente a versao/idioma/arquitetura, ou usar a midia original compativel. Nao remover .NET 4.x.

## 3. Aplicativos Appx provisionados: classificacao dos 39

### Candidatos de baixo risco relativo para avaliar remocao

Remover somente depois de validar que o usuario nao deseja o aplicativo e que nao ha dependencia relevante:

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
- Microsoft.549981C3F5F10 (Cortana/assistente legado da imagem)

### Componentes Xbox: avaliar como conjunto, sem remocao automatica

- Microsoft.XboxApp
- Microsoft.XboxGameOverlay
- Microsoft.XboxGamingOverlay
- Microsoft.XboxSpeechToTextOverlay
- Microsoft.Xbox.TCUI
- Microsoft.XboxIdentityProvider

Se o objetivo incluir jogos, controle, Game Bar ou autenticacao Xbox, manter os componentes necessarios. Se nao houver uso de jogos Xbox, testar a remocao de forma isolada e verificar dependencias.

### Preservar por compatibilidade, infraestrutura ou utilidade geral

- Microsoft.DesktopAppInstaller
- Microsoft.StorePurchaseApp
- Microsoft.WindowsStore
- Microsoft.VCLibs.140.00
- Microsoft.HEIFImageExtension
- Microsoft.VP9VideoExtensions
- Microsoft.WebMediaExtensions
- Microsoft.WebpImageExtension
- Microsoft.Windows.Photos
- Microsoft.MSPaint
- Microsoft.WindowsCalculator
- Microsoft.WindowsCamera
- Microsoft.ScreenSketch
- Microsoft.MicrosoftStickyNotes
- Microsoft.WindowsAlarms
- Microsoft.WindowsSoundRecorder
- microsoft.windowscommunicationsapps (Mail/Calendar)

Os aplicativos basicos podem ser removidos individualmente mais tarde se o tamanho final justificar, mas nao sao prioridade. Store, App Installer e VCLibs devem ser preservados para manter instalacao/atualizacao e dependencias de aplicativos.

## 4. Pacotes DISM: preservar

Os 35 pacotes listados estao instalados. Nao usar `Remove-Package` sobre os pacotes abaixo. Em especial, preservar:
- Microsoft-Windows-Client-LanguagePack e recursos de idioma pt-BR (Basic, Handwriting, OCR, Speech e TextToSpeech).
- Microsoft-Windows-Foundation-Package e Microsoft-Windows-FodMetadata-Package.
- Pacotes de DirectX Database e ApplicationModel Sync.
- Pacotes de servicing stack, atualizacao cumulativa e rollup do .NET.
- Pacotes de shell/experiencia do usuario e componentes de sistema.
- Pacotes de compatibilidade e recursos sob demanda enquanto nao houver mapeamento de dependencias.

Os pacotes de Notepad, Paint, WordPad, PowerShell ISE, Quick Assist, Steps Recorder, OpenSSH Client, Windows Media Player e Hello Face podem ser avaliados individualmente depois, mas nao sao prioridade e nao devem ser confundidos com componentes essenciais do sistema.

## 5. Ordem recomendada para a personalizacao

1. Criar uma copia de trabalho da imagem e manter a ISO original intacta.
2. Preparar uma fonte valida para .NET 3.5 e planejar atualizacoes aplicaveis.
3. Fazer uma primeira imagem de teste removendo apenas aplicativos promocionais/nao essenciais selecionados, sem tocar em pacotes de sistema.
4. Testar instalacao, primeiro boot, Explorer, Gerenciador de Tarefas, CMD, PowerShell 5.1, rede, audio, video, USB, impressao e instalacao de programas Win32.
5. Em uma rodada separada, testar desabilitacao de SMB1, PowerShell 2.0 e Internet Explorer.
6. Comparar tamanho da imagem, tempo de boot, RAM em repouso e estabilidade antes/depois.
7. Somente depois aprovar uma lista final de remocoes e automatizar a construcao.

## 6. Seguranca e suporte

O Windows 10 Home/Pro 22H2 encerrou o suporte geral em 14/10/2025. A ISO base deste projeto contem uma imagem de 2023. Mesmo que a ISO seja atualizada com pacotes aplicaveis, nao se deve presumir suporte regular gratuito apos o fim do ciclo. Evitar uso com contas sensiveis ou navegacao desprotegida; considerar opcoes oficiais de atualizacao/ESU quando aplicaveis.

SMBv1 tem vulnerabilidades significativas; a Microsoft recomenda nao utiliza-lo e atualizar dispositivos/servidores antigos em vez de depender do protocolo. PowerShell 2.0 e legado/preterido; scripts devem ser migrados para PowerShell 5.1 ou mais recente.

## 7. Fontes tecnicas

- Inventario gerado pelo proprio projeto: [execucao GitHub Actions](https://github.com/Lucasmgp/Windows-10-Lite-Limbo/actions/runs/45026404860).
- Microsoft Learn - [Detectar, habilitar e desabilitar SMBv1, SMBv2 e SMBv3](https://learn.microsoft.com/en-us/windows-server/storage/file-server/troubleshoot/detect-enable-and-disable-smbv1-v2-v3).
- Microsoft Learn - [Recursos e funcionalidades removidos no Windows cliente](https://learn.microsoft.com/pt-br/windows/whats-new/removed-features).
- Microsoft Learn - [Ciclo de vida do Windows 10 Home e Pro](https://learn.microsoft.com/pt-br/lifecycle/products/windows-10-home-and-pro).
- Microsoft Support - [Fim do suporte do Windows 10 em 14 de outubro de 2025](https://support.microsoft.com/pt-br/windows/o-suporte-ao-windows-10-terminou-em-14-de-outubro-de-2025).

## Proxima etapa

Revisar com o usuario a lista de candidatos de Appx e as tres alteracoes de recursos legados (SMB1, PowerShell 2.0 e Internet Explorer). Nenhuma remocao sera executada sem aprovacao explicita.
