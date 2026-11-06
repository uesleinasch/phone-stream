# phone-stream

Espelha a tela e o áudio de um celular Android no PC (Linux x86_64), via USB ou Wi-Fi, usando o [scrcpy](https://github.com/Genymobile/scrcpy). Feito para assistir no computador vídeos que estão rodando no celular.

Tem uma interface gráfica (AppImage) e um comando de terminal (`phone-stream`).

Página do projeto: https://uesleinasch.github.io/phone-stream/

## Interface gráfica (AppImage)

```bash
wget https://github.com/uesleinasch/phone-stream/releases/latest/download/phone-stream-x86_64.AppImage
chmod +x phone-stream-x86_64.AppImage
./phone-stream-x86_64.AppImage
```

O AppImage já traz o scrcpy e o adb. Na interface você escolhe o celular (USB ou Wi-Fi), a qualidade, a proporção e o app, inicia/para a transmissão e, enquanto ela roda, alterna tela cheia, apaga/acende a tela do celular e ajusta o volume. Os controles durante a transmissão usam o `xdotool` (`sudo apt install xdotool`) e funcionam em sessões X11.

## Comando de terminal

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
phone-stream                     # USB, 1080p, corte 16:9, em janela
phone-stream -f                  # abre em tela cheia
phone-stream --wifi              # Wi-Fi (1ª vez com o cabo conectado; depois pode tirar)
phone-stream --wifi-reset        # refaz a configuração Wi-Fi pelo cabo
phone-stream -q max              # qualidade: 720, 1080 (padrão) ou max
phone-stream --fit original      # proporção: crop (padrão), original ou virtual
phone-stream --app com.google.android.youtube   # abre o app num display virtual 16:9
phone-stream -- --max-fps=30     # repassa opções ao scrcpy
```

Comportamento padrão: 1080p, corte 16:9, em janela, tela do celular desligada (a imagem continua no PC), áudio só no PC e protetor de tela do PC desativado.

### Qualidade

| `-q` | Resolução (lado maior) | Bitrate | Quando usar |
|---|---|---|---|
| `720` | 1280 px | 4 Mbps | Wi-Fi fraco ou PC lento |
| `1080` | 1920 px | 8 Mbps | padrão; bom para filmes |
| `max` | nativa do celular | 16 Mbps | melhor imagem, de preferência via USB |

### Proporção

Celulares modernos têm tela 20:9, mais comprida que um monitor 16:9, o que gera faixas pretas.

| `--fit` | O que faz |
|---|---|
| `crop` | padrão; recorta o centro da tela do celular em 16:9. Com o celular deitado e o vídeo em tela cheia nele, a imagem ocupa o monitor inteiro |
| `original` | mostra a tela inteira do celular, com faixas pretas |
| `virtual` | cria uma tela virtual 1920×1080 no celular e abre nela o app de `--app`. A tela física fica livre; alguns apps estranham rodar numa tela virtual |

### Atalhos na janela

Use o **Alt esquerdo** (o Alt direito do teclado ABNT2 é AltGr e não funciona).

| Atalho | Ação |
|---|---|
| `Alt+F` | alterna tela cheia |
| `Alt+O` | apaga a tela física do celular |
| `Alt+Shift+O` | acende a tela física do celular |
| `Alt+↑` / `Alt+↓` | volume |
| fechar a janela | encerra |

### Wi-Fi

Na primeira vez, o script usa o cabo para ativar o adb em TCP/IP (porta 5555), descobre o IP do celular e salva em `~/.config/phone-stream/last-ip`. Nas próximas vezes conecta direto. O modo TCP/IP do adb é desfeito quando o celular reinicia; aí basta rodar `phone-stream --wifi` com o cabo de novo. Se o IP mudar, acontece o mesmo.

### Para scripts e integrações

| Opção | Saída |
|---|---|
| `--devices` | um aparelho por linha: `serial`, `usb`/`wifi`, estado, modelo (TSV) |
| `--list-apps` | um app por linha: pacote, nome, `user`/`system` (TSV) |
| `--wifi-connect` | prepara o Wi-Fi e imprime o serial `IP:5555` |
| `-s SERIAL` | usa um aparelho específico |

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

## Desenvolvimento

A interface fica em `gui/` (Flutter, Linux desktop) e só chama o script `phone-stream`. Para gerar o AppImage:

```bash
./packaging/build-appimage.sh   # usa o flutter do PATH ou ~/.local/share/flutter; saída em dist/
```
