import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum Connection { usb, wifi }

enum Quality {
  q720('720', '720p'),
  q1080('1080', '1080p'),
  max('max', 'Máx.');

  const Quality(this.arg, this.label);
  final String arg;
  final String label;
}

enum Fit {
  crop('crop', 'Corte 16:9'),
  original('original', 'Original'),
  virtual('virtual', 'Virtual');

  const Fit(this.arg, this.label);
  final String arg;
  final String label;
}

enum Shortcut {
  fullscreen('alt+f'),
  screenOff('alt+o'),
  screenOn('alt+shift+o'),
  volumeDown('alt+Down'),
  volumeUp('alt+Up');

  const Shortcut(this.keys);
  final String keys;
}

class Device {
  const Device({
    required this.serial,
    required this.connection,
    required this.state,
    required this.model,
  });

  final String serial;
  final Connection connection;
  final String state;
  final String model;

  bool get ready => state == 'device';

  String get stateLabel => switch (state) {
        'device' => 'pronto',
        'unauthorized' => 'aceite a depuração no celular',
        'offline' => 'offline',
        'no' => 'sem permissão USB',
        _ => state,
      };
}

class AndroidApp {
  const AndroidApp({required this.package, required this.name, required this.isUser});

  final String package;
  final String name;
  final bool isUser;
}

class StreamOptions {
  const StreamOptions({
    required this.serial,
    required this.quality,
    required this.fit,
    required this.fullscreen,
    this.app,
  });

  final String serial;
  final Quality quality;
  final Fit fit;
  final bool fullscreen;
  final String? app;

  List<String> toArgs() => [
        '--serial', serial,
        '--quality', quality.arg,
        '--fit', fit.arg,
        if (fit == Fit.virtual && app != null) ...['--app', app!],
        if (fullscreen) '--fullscreen',
      ];
}

class CommandException implements Exception {
  CommandException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PhoneStream {
  PhoneStream() : executable = _findExecutable();

  final String executable;
  static final _ansi = RegExp(r'\x1B\[[0-9;]*m');

  static String _findExecutable() {
    final fromEnv = Platform.environment['PHONE_STREAM_BIN'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    final local = '${Platform.environment['HOME']}/.local/bin/phone-stream';
    if (File(local).existsSync()) return local;
    return 'phone-stream';
  }

  static String clean(String text) => text.replaceAll(_ansi, '').trim();

  Future<List<String>> _lines(List<String> args) async {
    final result = await Process.run(executable, args, stdoutEncoding: utf8, stderrEncoding: utf8);
    if (result.exitCode != 0) {
      final error = clean(result.stderr as String);
      throw CommandException(error.isEmpty ? 'phone-stream ${args.join(' ')} falhou' : error);
    }
    return const LineSplitter().convert(result.stdout as String).where((l) => l.trim().isNotEmpty).toList();
  }

  Future<List<Device>> devices() async {
    final lines = await _lines(['--devices']);
    return [
      for (final line in lines)
        if (line.split('\t') case [final serial, final conn, final state, final model])
          Device(
            serial: serial,
            connection: conn == 'usb' ? Connection.usb : Connection.wifi,
            state: state,
            model: model == '-' ? serial : model,
          ),
    ];
  }

  Future<List<AndroidApp>> apps(String serial) async {
    final lines = await _lines(['--serial', serial, '--list-apps']);
    final apps = [
      for (final line in lines)
        if (line.split('\t') case [final package, final name, final type])
          AndroidApp(package: package, name: name, isUser: type == 'user'),
    ];
    apps.sort((a, b) {
      if (a.isUser != b.isUser) return a.isUser ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return apps;
  }

  Future<String> wifiConnect() async {
    final lines = await _lines(['--wifi-connect']);
    if (lines.isEmpty) throw CommandException('Não recebi o endereço do celular');
    return lines.last.trim();
  }

  Future<Process> start(StreamOptions options) => Process.start(
        executable,
        options.toArgs(),
        environment: {'TERM': 'dumb', 'SDL_VIDEODRIVER': 'x11'},
      );

  static Future<bool> hasXdotool() async {
    try {
      final result = await Process.run('xdotool', ['version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  static Future<ProcessResult> _xdotool(List<String> args) async {
    final process = await Process.start('xdotool', args);
    final stdout = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        process.kill();
        throw CommandException('A janela da transmissão não respondeu');
      },
    );
    return ProcessResult(process.pid, code, await stdout, await stderr);
  }

  static Future<void> sendShortcut(int pid, Shortcut shortcut) async {
    final search = await _xdotool(['search', '--onlyvisible', '--pid', '$pid']);
    final windows = const LineSplitter().convert(search.stdout as String).where((l) => l.trim().isNotEmpty);
    if (windows.isEmpty) throw CommandException('Janela da transmissão não encontrada');
    final result = await _xdotool(
      ['windowactivate', '--sync', windows.first.trim(), 'key', '--clearmodifiers', shortcut.keys],
    );
    if (result.exitCode != 0) throw CommandException(clean(result.stderr as String));
  }
}
