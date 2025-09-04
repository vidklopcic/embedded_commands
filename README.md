# Embedded Commands

A Flutter plugin for interfacing with embedded devices using a structured command protocol. This plugin is designed to facilitate communication with embedded systems, typically over Bluetooth Low Energy (BLE) connections.

## Features

- **Command Protocol**: Structured binary protocol for reliable device communication
- **CRC16 Validation**: Built-in CRC16 checksum validation for data integrity
- **Multiple Command Types**: Support for read, write, and extended commands
- **Stream-based Communication**: Reactive programming with command streams
- **Timeout Handling**: Automatic timeout detection and command reset
- **Flexible Payload Support**: Support for both text and binary payloads

## Command Types

The plugin supports three types of commands:

- **Read Commands** (`?`): Request data from embedded device
- **Write Commands** (`!`): Send data to embedded device  
- **Extended Commands** (`#`): Support for larger payloads (up to 3KB)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  embedded_commands: ^0.0.1
```

## Usage

### Basic Setup

```dart
import 'package:embedded_commands/embedded_commands.dart';

// Define your transmission function
Future<void> transmitFunction(List<int> data) async {
  // Implement your actual transmission logic (e.g., BLE write)
  // This could be writing to a BLE characteristic
}

// Create the embedded commands instance
final embeddedCommands = EmbeddedCommands(tx: transmitFunction);

// Listen to incoming commands
embeddedCommands.rx.listen((command) {
  print('Received command: Group ${command.group}, ID ${command.id}');
  print('Payload: ${command.text}');
});
```

### Creating Commands

```dart
// Write command with text payload
final writeCmd = Command.write(
  group: 1, 
  id: 10, 
  payload: 'Hello Device'.codeUnits
);

// Read command
final readCmd = Command.read(group: 1, id: 20);

// Extended command for larger payloads
final extendedCmd = Command.extended(
  group: 2, 
  id: 30,
  payload: largeDataList
);
```

### Sending Commands

```dart
// Send a command to the device
await embeddedCommands.send(writeCmd);
```

### Handling Responses

```dart
// Listen for specific command responses
embeddedCommands.getHandler(Command(group: 1, id: 10)).listen((response) {
  print('Response received: ${response.text}');
});
```

### Processing Incoming Data

When receiving data from your embedded device (e.g., from BLE notifications), feed each byte to the command parser:

```dart
// Feed incoming bytes one at a time
void onDataReceived(List<int> data) {
  for (int byte in data) {
    embeddedCommands.feed(byte);
  }
}
```

## Protocol Format

The binary protocol format is:

```
[Type][Group][ID][Length][Payload...][CRC16_LOW][CRC16_HIGH]
```

- **Type**: Command type (1 byte) - `?` (63), `!` (33), or `#` (35)
- **Group**: Command group identifier (1 byte)
- **ID**: Command identifier within group (1 byte)
- **Length**: Payload length (1 byte for regular, 8 bytes for extended)
- **Payload**: Command data (variable length)
- **CRC16**: 16-bit CRC checksum for data integrity (2 bytes, little-endian)

## Error Handling

- Commands automatically timeout after 1 second of inactivity
- Invalid command types are rejected
- Payloads exceeding 3KB are rejected for safety
- CRC validation ensures data integrity

## Example Integration with BLE

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLECommandInterface {
  late BluetoothCharacteristic _txCharacteristic;
  late BluetoothCharacteristic _rxCharacteristic;
  late EmbeddedCommands _commands;

  void initialize() {
    _commands = EmbeddedCommands(tx: _transmit);
    
    // Subscribe to RX characteristic for incoming data
    _rxCharacteristic.setNotifyValue(true);
    _rxCharacteristic.value.listen((data) {
      for (int byte in data) {
        _commands.feed(byte);
      }
    });
  }

  Future<void> _transmit(List<int> data) async {
    await _txCharacteristic.write(data);
  }
}
```

## Contributing

Contributions are welcome! Please read the contributing guidelines and submit pull requests for any improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.