import 'dart:typed_data';

import 'package:embedded_commands/crc16.dart';

typedef EmbeddedCommandsTx<T> = Future<T> Function(List<int> data);
typedef EmbeddedCommandsRx = void Function(Command command);

class EmbeddedCommands<T> {
  final EmbeddedCommandsTx<T> tx;
  final EmbeddedCommandsRx rx;
  Command _command = Command();
  int _payloadIndex = 0;
  int _payloadLen = 0;
  int _crc = 0;

  EmbeddedCommands({
    required this.tx,
    required this.rx,
  });

  void feed(int byte) {
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
        if (_command.type == Command.kTypeExtended && _payloadIndex < Command.kExtendedHeaderLen) {
          _command.payload.add(byte);
          _payloadLen |= byte << (8 * _payloadIndex);
        } else if (_payloadIndex < _payloadLen) {
          _command.payload.add(byte);
        } else {
          // crc (2 bytes)
          if (_payloadIndex == _payloadLen) {
            _crc = byte;
          } else {
            _crc |= byte << 8;
            if (_command.crc == _crc) {
              rx(_command);
            }
            _resetCommand();
            return;
          }
        }
        _payloadIndex++;
        break;
    }
  }

  Future<T> writeCommand(Command command) {
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

  Command({
    this.type = Command.kTypeWrite,
    this.group = 0,
    this.id = 0,
    List<int>? payload,
  }) : payload = payload ?? [];

  Command.write({required this.group, required this.id, required this.payload})
      : type = Command.kTypeWrite,
        assert(payload.length <= 0xff);

  Command.read({required this.group, required this.id, required this.payload})
      : type = Command.kTypeRead,
        assert(payload.length <= 0xff);

  Command.extended({required this.group, required this.id, required List<int> payload})
      : type = Command.kTypeExtended,
        payload = [
          ...(ByteData(8)..setUint64(0, payload.length + 8, Endian.little)).buffer.asUint8List().toList(),
          ...payload,
        ];

  int get crc => crc16([type, group, id, ...payload]);

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
    return [...command, crc >> 8, crc & 0xff];
  }
}
