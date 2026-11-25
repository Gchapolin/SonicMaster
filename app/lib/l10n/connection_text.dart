import 'lang.dart';

/// Connecting to the pedal: the connection controls, the device picker and
/// the connect / reconnect status messages.
abstract class ConnectionText {
  const ConnectionText();

  static ConnectionText get current =>
      appLang == Lang.pt ? const _Pt() : const _En();

  String get connected;
  String get disconnected;
  String get connect;
  String get disconnect;
  String get webMidiAndroid;
  String get webMidiOther;
  String get webBluetoothAndroid;
  String get webBluetoothLinux;
  String get webBluetoothOther;
  String get iosCannotConnect;
  String get usbInOut;
  String get inputOnly;
  String get outputOnly;
  String scanFailed(Object error);
  String get noUsbDevices;
  String get noBleDevices;
  String get selectDevice;
  String get rescan;
  String get browserPicksBluetooth;
  String get selectBluetoothDevice;
  String get unnamed;

  // The status line (presetLoadStatusProvider).
  String get statusConnected;
  String get statusReconnected;
  String get statusDisconnected;
  String connectFailed(Object error);
  String reconnecting(int attempt);
  String reconnectFailed(Object? error);
  String get connectionLost;
  String get tapConnectToResume;
  String get autoConnectFailed;
}

class _En extends ConnectionText {
  const _En();

  @override
  String get connected => 'Connected';
  @override
  String get disconnected => 'Disconnected';
  @override
  String get connect => 'Connect';
  @override
  String get disconnect => 'Disconnect';
  @override
  String get webMidiAndroid =>
      'Web MIDI is not available in this browser.\n'
      'Use Chrome or Samsung Internet.';
  @override
  String get webMidiOther =>
      'Web MIDI is not available in this browser.\n'
      'Use Chrome, Edge, Opera, or Firefox.';
  @override
  String get webBluetoothAndroid =>
      'Web Bluetooth is not available in this browser.\n'
      'Use Chrome or Samsung Internet.';
  @override
  String get webBluetoothLinux =>
      'Web Bluetooth is not available.\n'
      'Use Chrome, Edge, or Opera. On Linux, enable\n'
      'chrome://flags/#enable-experimental-web-platform-features';
  @override
  String get webBluetoothOther =>
      'Web Bluetooth is not available.\n'
      'Use Chrome, Edge, or Opera.';
  @override
  String get iosCannotConnect =>
      'No iPhone or iPad browser can connect to the pedal:\n'
      'none of them supports Web MIDI or Web Bluetooth.\n'
      'Use Chrome on Android, or a desktop browser.';
  @override
  String get usbInOut => 'USB MIDI · in + out';
  @override
  String get inputOnly => 'input only';
  @override
  String get outputOnly => 'output only';
  @override
  String scanFailed(Object error) => 'Scan failed: $error';
  @override
  String get noUsbDevices => 'No USB MIDI devices found';
  @override
  String get noBleDevices => 'No BLE devices found';
  @override
  String get selectDevice => 'Select a device';
  @override
  String get rescan => 'Rescan';
  @override
  String get browserPicksBluetooth =>
      'Your browser picks the Bluetooth device.\n'
      'Choose your pedal in the chooser that opens.';
  @override
  String get selectBluetoothDevice => 'Select Bluetooth device';
  @override
  String get unnamed => '(unnamed)';
  @override
  String get statusConnected => 'connected';
  @override
  String get statusReconnected => 'reconnected';
  @override
  String get statusDisconnected => 'disconnected';
  @override
  String connectFailed(Object error) => 'connect failed: $error';
  @override
  String reconnecting(int attempt) =>
      'connection lost — reconnecting ($attempt/3)…';
  @override
  String reconnectFailed(Object? error) =>
      'reconnect failed ($error) — tap Connect';
  @override
  String get connectionLost => 'connection lost — tap Connect';
  @override
  String get tapConnectToResume => 'tap Connect to resume';
  @override
  String get autoConnectFailed => 'auto-connect failed — tap Connect';
}

class _Pt extends ConnectionText {
  const _Pt();

  @override
  String get connected => 'Conectada';
  @override
  String get disconnected => 'Desconectada';
  @override
  String get connect => 'Conectar';
  @override
  String get disconnect => 'Desconectar';
  @override
  String get webMidiAndroid =>
      'O Web MIDI não está disponível neste navegador.\n'
      'Use o Chrome ou o Samsung Internet.';
  @override
  String get webMidiOther =>
      'O Web MIDI não está disponível neste navegador.\n'
      'Use o Chrome, Edge, Opera ou Firefox.';
  @override
  String get webBluetoothAndroid =>
      'O Web Bluetooth não está disponível neste navegador.\n'
      'Use o Chrome ou o Samsung Internet.';
  @override
  String get webBluetoothLinux =>
      'O Web Bluetooth não está disponível.\n'
      'Use o Chrome, Edge ou Opera. No Linux, ative\n'
      'chrome://flags/#enable-experimental-web-platform-features';
  @override
  String get webBluetoothOther =>
      'O Web Bluetooth não está disponível.\n'
      'Use o Chrome, Edge ou Opera.';
  @override
  String get iosCannotConnect =>
      'Nenhum navegador de iPhone ou iPad conecta à pedaleira:\n'
      'nenhum deles tem Web MIDI nem Web Bluetooth.\n'
      'Use o Chrome no Android ou um navegador de computador.';
  @override
  String get usbInOut => 'USB MIDI · entrada + saída';
  @override
  String get inputOnly => 'só entrada';
  @override
  String get outputOnly => 'só saída';
  @override
  String scanFailed(Object error) => 'Falha na busca: $error';
  @override
  String get noUsbDevices => 'Nenhum dispositivo USB MIDI encontrado';
  @override
  String get noBleDevices => 'Nenhum dispositivo BLE encontrado';
  @override
  String get selectDevice => 'Selecione um dispositivo';
  @override
  String get rescan => 'Buscar de novo';
  @override
  String get browserPicksBluetooth =>
      'O navegador escolhe o dispositivo Bluetooth.\n'
      'Escolha sua pedaleira na janela que abrir.';
  @override
  String get selectBluetoothDevice => 'Selecionar dispositivo Bluetooth';
  @override
  String get unnamed => '(sem nome)';
  @override
  String get statusConnected => 'conectada';
  @override
  String get statusReconnected => 'reconectada';
  @override
  String get statusDisconnected => 'desconectada';
  @override
  String connectFailed(Object error) => 'falha ao conectar: $error';
  @override
  String reconnecting(int attempt) =>
      'conexão perdida — reconectando ($attempt/3)…';
  @override
  String reconnectFailed(Object? error) =>
      'falha ao reconectar ($error) — toque em Conectar';
  @override
  String get connectionLost => 'conexão perdida — toque em Conectar';
  @override
  String get tapConnectToResume => 'toque em Conectar para retomar';
  @override
  String get autoConnectFailed =>
      'falha na conexão automática — toque em Conectar';
}
