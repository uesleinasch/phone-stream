# phone-stream

Espelha a tela e o áudio de um celular Android no PC (Linux x86_64), via USB ou Wi-Fi, usando o [scrcpy](https://github.com/Genymobile/scrcpy). Feito para assistir no computador vídeos que estão rodando no celular.

Página do projeto: https://uesleinasch.github.io/phone-stream/

## Instalação

```bash
git clone https://github.com/uesleinasch/phone-stream.git
cd phone-stream
./phone-stream --install
```

Baixa a última release oficial do scrcpy (com checksum verificado) para `~/.local/share/phone-stream/scrcpy` e cria os comandos `phone-stream` e `scrcpy` em `~/.local/bin`. Não precisa de sudo. Rodar de novo atualiza o scrcpy quando houver versão nova.

## No celular (uma vez)

1. **Configurações → Sobre o telefone →** toque 7x em **Número da versão** para liberar as Opções do desenvolvedor.
2. **Opções do desenvolvedor →** ative **Depuração USB**.
3. Conecte o cabo e aceite **Permitir depuração USB** (marque "Sempre permitir").

## Uso

```bash
phone-stream                 # USB, 1080p
phone-stream --wifi          # Wi-Fi (1ª vez com o cabo conectado; depois pode tirar)
phone-stream --wifi-reset    # refaz a configuração Wi-Fi pelo cabo
phone-stream -q max          # qualidade: 720, 1080 (padrão) ou max
phone-stream -- --max-fps=30 # repassa opções ao scrcpy
```

Comportamento padrão: 1080p, tela cheia, tela do celular desligada (a imagem continua no PC), áudio só no PC e protetor de tela do PC desativado.

### Qualidade

| `-q` | Resolução (lado maior) | Bitrate | Quando usar |
|---|---|---|---|
| `720` | 1280 px | 4 Mbps | Wi-Fi fraco ou PC lento |
| `1080` | 1920 px | 8 Mbps | padrão; bom para filmes |
| `max` | nativa do celular | 16 Mbps | melhor imagem, de preferência via USB |

| Atalho | Ação |
|---|---|
| `Alt+F` | alterna tela cheia |
| `Alt+Shift+O` | liga de novo a tela física do celular |
| `Alt+O` | desliga a tela física do celular |
| fechar a janela | encerra |

### Wi-Fi

Na primeira vez, o script usa o cabo para ativar o adb em TCP/IP (porta 5555), descobre o IP do celular e salva em `~/.config/phone-stream/last-ip`. Nas próximas vezes conecta direto. O modo TCP/IP do adb é desfeito quando o celular reinicia; aí basta rodar `phone-stream --wifi` com o cabo de novo. Se o IP mudar, acontece o mesmo.

## Limitações

- **Áudio exige Android 11+.**
- **Apps com DRM** (Netflix, Prime Video, Disney+, Max, Globoplay etc.) bloqueiam a captura de tela via `FLAG_SECURE`: o vídeo aparece **preto**, mesmo com o áudio funcionando. Não há como contornar isso sem root. Para esses apps, use o app ou o site oficial no PC. Funciona com YouTube, players locais (VLC, MX Player), navegador e apps sem DRM.
- Só há build oficial do scrcpy para Linux x86_64.

## Problemas comuns

| Mensagem | Solução |
|---|---|
| Nenhum celular no USB | Cabo de dados (não só de carga), Depuração USB ativa |
| Celular não autorizado | Desbloqueie a tela e aceite o prompt de depuração |
| Sem permissão no USB | `sudo apt install android-sdk-platform-tools-common` e reconecte |
| Trava após `[server] INFO: Device: ...` sem abrir janela | Driver de áudio do SDL travando. O script já usa `SDL_AUDIO_DRIVER=pulseaudio`; se o seu sistema for só PipeWire, teste `SDL_AUDIO_DRIVER=pipewire phone-stream` ou `SDL_AUDIO_DRIVER=alsa phone-stream` |
| Falha ao conectar via Wi-Fi | PC e celular na mesma rede; redes corporativas/de visitantes costumam isolar os clientes |
