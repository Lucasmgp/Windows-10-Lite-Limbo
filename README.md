# Windows 10 Lite para Limbo

Projeto para personalizar uma ISO oficial do Windows 10 22H2 x86 (32 bits), em português do Brasil, priorizando baixo consumo de RAM e CPU sem sacrificar compatibilidade geral.

## Estado atual

- [x] Repositório criado.
- [x] ISO oficial baixada no dispositivo do usuário.
- [x] SHA-256 local conferido com o valor de referência da mídia brasileira x86.
- [x] Preparar e validar o ambiente Windows do GitHub Actions.
- [x] Identificar as edições da imagem; Windows 10 Home (índice 1) selecionado.
- [ ] Concluir inventário detalhado de pacotes, recursos, capacidades e aplicativos da edição Home.
- [ ] Definir e testar remoções conservadoras.
- [ ] Gerar e validar a ISO personalizada.
- [ ] Testar instalação e desempenho no Limbo.

## ISO-base esperada

Nome: `Win10_22H2_BrazilianPortuguese_x32v1.iso`  
Arquitetura: x86 (32 bits)  
Idioma esperado: pt-BR  
SHA-256 esperado:

`69e4b7ed9e5d7cea72c075e63a493c867275608b8f9e9d1fe7d711459b32d1be`

A ISO não deve ser adicionada ao Git. O workflow a baixa diretamente da Microsoft usando o segredo `WINDOWS_ISO_URL`; o endereço temporário pode expirar e precisar ser renovado.

## Princípios

1. Usar somente mídia original e verificável.
2. Não remover componentes compartilhados ou dependências sem teste.
3. Preservar Windows Update, Defender, Firewall, DISM, SFC, WMI, PowerShell, .NET, Windows Installer, rede, áudio, vídeo e suporte a aplicativos.
4. Fazer primeiro inventário e cópia de trabalho; nunca modificar a única ISO original.
5. Comparar Home e Pro, caso ambas estejam presentes, antes de escolher a edição.
6. Validar cada alteração em uma VM antes de ampliar as remoções.

## Limitação importante

O GitHub Actions não recebe automaticamente arquivos armazenados no celular. Não enviar a ISO como arquivo comum do repositório. Também não presumir que o armazenamento de artefatos do Actions comporte uma ISO de aproximadamente 4,1 GB. O método de transferência será decidido separadamente.

## Estrutura planejada

- `.github/workflows/preflight.yml`: validação inicial do runner.
- `scripts/01-verificar-iso.ps1`: validação da ISO no runner.
- `config/componentes-preservados.txt`: lista de componentes que não devem ser removidos.


## Inventário detalhado da edição Home

O workflow manual `.github/workflows/inventario-home.yml` baixa e valida novamente a ISO, exporta o índice 1 para uma imagem temporária e monta essa cópia em modo somente leitura. O script `scripts/03-inventariar-home.ps1` gera relatórios de pacotes, recursos, capacidades opcionais e aplicativos Appx provisionados. Somente os relatórios são publicados como artefato por 7 dias; a ISO e a imagem WIM temporária não são publicadas. Nenhuma remoção ou alteração é executada.
