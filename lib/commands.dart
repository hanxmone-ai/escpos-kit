/// Low-level ESC/POS commands as byte lists, for building your own layouts.
///
/// ```dart
/// import 'package:escpos_kit/commands.dart' as esc;
///
/// final bytes = [...esc.initialize(), ...esc.bold(true), ...'Hi'.codeUnits, ...esc.lineFeed()];
/// ```
library;

export 'src/commands.dart';
