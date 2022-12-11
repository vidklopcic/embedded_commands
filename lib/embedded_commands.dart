import 'dart:async';
import 'dart:typed_data';

import 'package:embedded_commands/crc16.dart';

typedef EmbeddedCommandsTx<T> = Future<T> Function(List<int> data);
typedef EmbeddedCommandsRx = void Function(Command command);

class EmbeddedCommands<T> {
  static const Duration kTimeout = Duration(seconds: 1);
  final EmbeddedCommandsTx<T> tx;
  DateTime _lastByte = DateTime.now();
  Command _command = Command();
  int _payloadIndex = 0;
  int _payloadLen = 0;
  int _crc = 0;
  final StreamController<Command> _rx = StreamController.broadcast();

  Stream<Command> get rx => _rx.stream;

  EmbeddedCommands({required this.tx});

  void feed(int byte) {
    if (DateTime.now().difference(_lastByte) > kTimeout) {
      _resetCommand();
    }
    _lastByte = DateTime.now();
    switch (_payloadIndex) {
      case 0:
        if (!Command.kTypes.contains(byte)) {
          return _resetCommand();
        }
        _command.type = byte;
        break;
      case 1:
        _command.group = byte;
        break;
      case 2:
        _command.id = byte;
        break;
      case 3:
        _payloadLen = byte;
        break;
      default:
        final index = _payloadIndex - 4;
        if (_command.type == Command.kTypeExtended && index < Command.kExtendedHeaderLen) {
          _command.payload.add(byte);
          _payloadLen |= byte << (8 * index);
        } else if (index < _payloadLen) {
          _command.payload.add(byte);
        } else {
          // crc (2 bytes)
          if (index == _payloadLen) {
            _crc = byte;
          } else {
            _crc |= byte << 8;
            if (_command.crc(_payloadLen) == _crc) {
              _rx.add(_command);
            }
            _resetCommand();
            return;
          }
        }
        break;
    }
    _payloadIndex++;
  }

  Stream<Command> getHandler(Command command) {
    return rx.where((i) => i.group == command.group && i.id == command.id);
  }

  Future<T> send(Command command) {
    return tx(command.bytes);
  }

  void _resetCommand() {
    _payloadIndex = 0;
    _payloadLen = 0;
    _crc = 0;
    _command = Command();
  }
}

class ExtendedCommandHeader {
  final Command command;

  ExtendedCommandHeader(this.command);
}

class Command {
  static const int kHeaderLen = 4;
  static const int kExtendedHeaderLen = 8;

  static const int kTypeRead = 63; // ?
  static const int kTypeWrite = 33; // !
  static const int kTypeExtended = 35; // #
  static const Set<int> kTypes = {
    kTypeRead,
    kTypeWrite,
    kTypeExtended,
  };

  int type;
  int group;
  int id;
  List<int> payload;
  String get text => String.fromCharCodes(payload);

  Command({
    this.type = Command.kTypeWrite,
    this.group = 0,
    this.id = 0,
    List<int>? payload,
  }) : payload = payload ?? [];

  Command.write({required this.group, required this.id, List<int>? payload})
      : type = Command.kTypeWrite,
        payload = payload ?? [],
        assert((payload?.length ?? 0) <= 0xff);

  Command.read({required this.group, required this.id, List<int>? payload})
      : type = Command.kTypeRead,
        payload = payload ?? [],
        assert((payload?.length ?? 0) <= 0xff);

  Command.extended({required this.group, required this.id, List<int>? payload})
      : type = Command.kTypeExtended,
        payload = [
          ...(ByteData(8)..setUint64(0, (payload ?? []).length + 8, Endian.little)).buffer.asUint8List().toList(),
          ...(payload ?? []),
        ];

  void setExtendedPayload(List<int> payload) {
    type = kTypeExtended;
    payload = [
      ...(ByteData(8)..setUint64(0, payload.length + 8, Endian.little)).buffer.asUint8List().toList(),
      ...payload,
    ];
  }

  int crc(int payloadLen) => crc16([type, group, id, payloadLen, ...payload]);

  List<int> get bytes {
    assert(kTypes.contains(type));
    assert(group <= 0xff);
    assert(id <= 0xff);
    assert(type == kTypeExtended || payload.length <= 0xff);
    assert(type != kTypeExtended || payload.length >= kTypeExtended);
    List<int> command = [
      type,
      group,
      id,
      type == kTypeExtended ? 0 : payload.length,
      ...payload,
    ];
    int crc = crc16(command);
    return [...command, crc & 0xff, crc >> 8];
  }
}
