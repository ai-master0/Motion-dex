// Motion Dex - minimal harness so the input subsystem can be built and tried.
//
// It shows a 16:9 placeholder "display", forwards mouse/keyboard through
// DexInputInterrupter, and either:
//   * connects to a real control socket if you enter host:port and tap Connect, or
//   * logs packets as hex (debug sink) when not connected.
//
// Replace the placeholder child with your real video surface in the full app.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'input/control_channel.dart';
import 'input/dex_input_interrupter.dart';
import 'input/scrcpy_protocol.dart';

void main() => runApp(const MotionDexApp());

class MotionDexApp extends StatelessWidget {
  const MotionDexApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Motion Dex',
        theme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const _Home(),
      );
}

class _LogSink implements ControlSink {
  _LogSink(this.onPacket);
  final void Function(String) onPacket;

  @override
  void send(Uint8List packet) => onPacket(
      packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join());

  @override
  Future<void> close() async {}
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _addr = TextEditingController(text: '127.0.0.1:27183');
  final List<String> _log = <String>[];
  late ControlSink _sink = _LogSink(_append);
  ScrcpyWireProfile _profile = ScrcpyWireProfile.modern;
  String _status = 'Debug sink (not connected)';

  void _append(String hex) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, hex);
      if (_log.length > 12) _log.removeLast();
    });
  }

  Future<void> _connect() async {
    final parts = _addr.text.split(':');
    final host = parts.first.trim();
    final port = int.tryParse(parts.length > 1 ? parts[1].trim() : '');
    if (port == null) {
      setState(() => _status = 'Use host:port');
      return;
    }
    try {
      final ch = await IsolateControlChannel.connect(host: host, port: port);
      await _sink.close();
      setState(() {
        _sink = ch;
        _status = 'Connected to $host:$port';
      });
    } catch (e) {
      setState(() => _status = 'Connect failed: $e');
    }
  }

  @override
  void dispose() {
    _sink.close();
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Motion Dex')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DexInputInterrupter(
                    sink: _sink,
                    remoteDisplaySize: const Size(1920, 1080),
                    encoder: ScrcpyControlEncoder(profile: _profile),
                    child: Container(
                      color: Colors.blueGrey.shade900,
                      alignment: Alignment.center,
                      child: const Text('Remote display placeholder\n'
                          'Move the mouse / type here'),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _addr,
                    decoration:
                        const InputDecoration(labelText: 'Control socket'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    FilledButton(
                        onPressed: _connect, child: const Text('Connect')),
                    const SizedBox(width: 12),
                    DropdownButton<ScrcpyWireProfile>(
                      value: _profile,
                      items: [
                        for (final p in ScrcpyWireProfile.values)
                          DropdownMenuItem(value: p, child: Text(p.name)),
                      ],
                      onChanged: (p) => setState(() => _profile = p ?? _profile),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(_status),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final l in _log)
                          Text(l,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
