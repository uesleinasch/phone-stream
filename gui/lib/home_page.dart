import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phone_stream.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _phone = PhoneStream();
  final _logScroll = ScrollController();
  final _log = <String>[];
  late final AppLifecycleListener _lifecycle;
  Timer? _poller;
  SharedPreferences? _prefs;

  List<Device> _devices = [];
  String? _serial;
  Quality _quality = Quality.q1080;
  Fit _fit = Fit.crop;
  bool _fullscreen = false;
  String? _app;
  List<AndroidApp>? _apps;
  bool _loadingApps = false;
  bool _connectingWifi = false;
  bool _refreshing = false;
  bool _starting = false;
  bool _xdotool = false;
  Process? _process;
  String? _devicesError;

  bool get _running => _process != null;

  Device? get _selected {
    for (final d in _devices) {
      if (d.serial == _serial) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
    _loadPrefs();
    PhoneStream.hasXdotool().then((ok) {
      if (mounted) setState(() => _xdotool = ok);
    });
    _refreshDevices();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _refreshDevices());
  }

  @override
  void dispose() {
    _poller?.cancel();
    _lifecycle.dispose();
    _process?.kill();
    _logScroll.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _onExitRequested() async {
    _process?.kill();
    return AppExitResponse.exit;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _quality = Quality.values.asNameMap()[prefs.getString('quality')] ?? _quality;
      _fit = Fit.values.asNameMap()[prefs.getString('fit')] ?? _fit;
      _fullscreen = prefs.getBool('fullscreen') ?? _fullscreen;
      _app = prefs.getString('app');
    });
  }

  void _save(String key, Object? value) {
    final prefs = _prefs;
    if (prefs == null) return;
    switch (value) {
      case null:
        prefs.remove(key);
      case bool v:
        prefs.setBool(key, v);
      default:
        prefs.setString(key, '$value');
    }
  }

  Future<void> _refreshDevices() async {
    if (_refreshing || _connectingWifi) return;
    _refreshing = true;
    try {
      final devices = await _phone.devices();
      if (!mounted) return;
      setState(() {
        _devicesError = null;
        _devices = devices;
        if (_selected == null) {
          final ready = devices.where((d) => d.ready).toList();
          _serial = ready.isNotEmpty ? ready.first.serial : devices.firstOrNull?.serial;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _devicesError = '$e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _connectWifi() async {
    setState(() => _connectingWifi = true);
    _appendLog('→ Conectando via Wi-Fi...');
    try {
      final serial = await _phone.wifiConnect();
      _appendLog('→ Conectado em $serial. Já pode desconectar o cabo.');
      if (mounted) setState(() => _serial = serial);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _connectingWifi = false);
    }
    while (_refreshing) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await _refreshDevices();
  }

  Future<void> _loadApps() async {
    final serial = _serial;
    if (serial == null) return;
    setState(() => _loadingApps = true);
    try {
      final apps = await _phone.apps(serial);
      if (mounted) setState(() => _apps = apps);
    } catch (e) {
      _showError('$e');
    } finally {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _start() async {
    final device = _selected;
    if (_starting || _running || device == null || !device.ready) return;
    _starting = true;
    final options = StreamOptions(
      serial: device.serial,
      quality: _quality,
      fit: _fit,
      fullscreen: _fullscreen,
      app: _app,
    );
    _appendLog('\$ ${_phone.executable} ${options.toArgs().join(' ')}');
    try {
      final process = await _phone.start(options);
      _starting = false;
      if (!mounted) {
        process.kill();
        return;
      }
      setState(() => _process = process);
      for (final stream in [process.stdout, process.stderr]) {
        stream.transform(utf8.decoder).transform(const LineSplitter()).listen(_appendLog);
      }
      final code = await process.exitCode;
      _appendLog('→ Transmissão encerrada (código $code)');
      if (mounted) setState(() => _process = null);
    } on ProcessException catch (e) {
      _starting = false;
      _showError('Não consegui executar ${_phone.executable}: ${e.message}');
    }
  }

  void _stop() => _process?.kill();

  Future<void> _shortcut(Shortcut shortcut) async {
    final process = _process;
    if (process == null) return;
    try {
      await PhoneStream.sendShortcut(process.pid, shortcut);
    } catch (e) {
      _showError('$e');
    }
  }

  void _appendLog(String line) {
    final text = PhoneStream.clean(line);
    if (text.isEmpty || !mounted) return;
    setState(() {
      _log.add(text);
      if (_log.length > 500) _log.removeRange(0, _log.length - 500);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
    });
  }

  void _showError(String message) {
    _appendLog('✗ $message');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Row(
              children: [
                Icon(Icons.smart_display_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('phone-stream', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                _StatusChip(running: _running),
              ],
            ),
            const SizedBox(height: 20),
            _section(
              context,
              title: 'Celular',
              trailing: IconButton(
                tooltip: 'Atualizar',
                onPressed: _refreshDevices,
                icon: const Icon(Icons.refresh),
              ),
              child: _deviceList(context),
            ),
            _section(context, title: 'Imagem', child: _imageOptions(context)),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: _running
                  ? FilledButton.tonalIcon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Parar transmissão'),
                    )
                  : FilledButton.icon(
                      onPressed: (_selected?.ready ?? false) ? _start : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Iniciar transmissão'),
                    ),
            ),
            const SizedBox(height: 16),
            _section(context, title: 'Durante a transmissão', child: _liveControls(context)),
            _logPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, {required String title, required Widget child, Widget? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (trailing != null) trailing else const SizedBox(height: 40),
                ],
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceList(BuildContext context) {
    final theme = Theme.of(context);
    final hasUsb = _devices.any((d) => d.connection == Connection.usb && d.ready);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_devicesError != null)
          Text(_devicesError!, style: TextStyle(color: theme.colorScheme.error))
        else if (_devices.isEmpty)
          Text(
            'Nenhum celular encontrado. Conecte o cabo USB com a Depuração USB ativa.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        RadioGroup<String>(
          groupValue: _serial,
          onChanged: _running ? (_) {} : (value) => setState(() => _serial = value),
          child: Column(
            children: [
              for (final d in _devices)
                RadioListTile<String>(
                  value: d.serial,
                  enabled: !_running,
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(d.connection == Connection.usb ? Icons.usb : Icons.wifi),
                  title: Text(d.model),
                  subtitle: Text(
                    '${d.connection == Connection.usb ? 'USB' : 'Wi-Fi'} · ${d.stateLabel}',
                    style: d.ready ? null : TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: hasUsb && !_connectingWifi && !_running ? _connectWifi : null,
            icon: _connectingWifi
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: const Text('Conectar via Wi-Fi'),
          ),
        ),
      ],
    );
  }

  Widget _imageOptions(BuildContext context) {
    final theme = Theme.of(context);
    final hint = switch (_fit) {
      Fit.crop => 'Recorta o centro da tela do celular em 16:9: sem faixas pretas num monitor 16:9.',
      Fit.original => 'Tela inteira do celular, com faixas pretas num monitor 16:9.',
      Fit.virtual => 'Cria uma tela 1920×1080 no celular e abre o app escolhido nela.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Qualidade', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<Quality>(
          segments: [for (final q in Quality.values) ButtonSegment(value: q, label: Text(q.label))],
          selected: {_quality},
          onSelectionChanged: _running
              ? null
              : (s) {
                  setState(() => _quality = s.first);
                  _save('quality', _quality.name);
                },
        ),
        const SizedBox(height: 14),
        Text('Proporção', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        SegmentedButton<Fit>(
          segments: [for (final f in Fit.values) ButtonSegment(value: f, label: Text(f.label))],
          selected: {_fit},
          onSelectionChanged: _running
              ? null
              : (s) {
                  setState(() => _fit = s.first);
                  _save('fit', _fit.name);
                },
        ),
        const SizedBox(height: 6),
        Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (_fit == Fit.virtual) ...[
          const SizedBox(height: 12),
          _appPicker(context),
        ],
        const SizedBox(height: 4),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Abrir em tela cheia'),
          value: _fullscreen,
          onChanged: _running
              ? null
              : (v) {
                  setState(() => _fullscreen = v);
                  _save('fullscreen', v);
                },
        ),
      ],
    );
  }

  Widget _appPicker(BuildContext context) {
    final apps = _apps;
    if (apps == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _app == null ? 'Nenhum app escolhido' : 'App: $_app',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: _loadingApps || _selected?.ready != true || _running ? null : _loadApps,
            icon: _loadingApps
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.apps),
            label: Text(_loadingApps ? 'Carregando...' : 'Escolher app'),
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => DropdownMenu<String>(
        width: constraints.maxWidth,
        enabled: !_running,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 320,
        initialSelection: _app,
        label: const Text('App para abrir'),
        leadingIcon: const Icon(Icons.search),
        dropdownMenuEntries: [
          for (final a in apps)
            DropdownMenuEntry(
              value: a.package,
              label: a.name,
              trailingIcon: a.isUser ? null : const Icon(Icons.android, size: 16),
            ),
        ],
        onSelected: (pkg) {
          setState(() => _app = pkg);
          _save('app', pkg);
        },
      ),
    );
  }

  Widget _liveControls(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _running && _xdotool;
    Widget button(IconData icon, String label, Shortcut shortcut) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              tooltip: label,
              onPressed: enabled ? () => _shortcut(shortcut) : null,
              icon: Icon(icon),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 12,
          children: [
            button(Icons.fullscreen, 'Tela cheia', Shortcut.fullscreen),
            button(Icons.phonelink_erase, 'Apagar tela', Shortcut.screenOff),
            button(Icons.phonelink_ring, 'Acender tela', Shortcut.screenOn),
            button(Icons.volume_down, 'Volume −', Shortcut.volumeDown),
            button(Icons.volume_up, 'Volume +', Shortcut.volumeUp),
          ],
        ),
        if (!_xdotool) ...[
          const SizedBox(height: 10),
          Text(
            'Instale o xdotool para usar estes controles: sudo apt install xdotool',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
          ),
        ] else if (!_running) ...[
          const SizedBox(height: 10),
          Text(
            'Na janela da transmissão também valem os atalhos com o Alt esquerdo: Alt+F, Alt+O, Alt+Shift+O.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  Widget _logPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('Log', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        shape: const Border(),
        children: [
          Container(
            height: 220,
            width: double.infinity,
            color: const Color(0xFF16151A),
            padding: const EdgeInsets.all(12),
            child: Scrollbar(
              controller: _logScroll,
              child: SingleChildScrollView(
                controller: _logScroll,
                child: SelectableText(
                  _log.isEmpty ? 'Sem mensagens ainda.' : _log.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFFE9E6DF),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        running ? Icons.circle : Icons.circle_outlined,
        size: 12,
        color: running ? Colors.green : scheme.onSurfaceVariant,
      ),
      label: Text(running ? 'Transmitindo' : 'Parado'),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: scheme.surfaceContainerHigh,
    );
  }
}
