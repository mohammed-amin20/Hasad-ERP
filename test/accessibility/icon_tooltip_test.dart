import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static guard: every IconButton in the app must expose an Arabic tooltip so
/// that keyboard/screen-reader users get an accessible name and hover users a
/// hint. Touch targets (>= 48x48) are enforced by the themed IconButtonTheme.
void main() {
  final libDir = Directory('lib');
  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('every IconButton carries a tooltip', () {
    final missing = <String>[];
    for (final file in files) {
      final code = file.readAsStringSync();
      final nodes = _iconButtonNodes(code);
      for (final (name, end) in nodes) {
        final slice = code.substring(name, end);
        if (!slice.contains('tooltip:')) {
          missing.add('${file.path}: $slice');
        }
      }
    }
    expect(missing, isEmpty,
        reason: 'IconButton(s) missing tooltip:\n${missing.join('\n')}');
  });
}

/// Returns the start of every `IconButton(` constructor and the index of its
/// matching close paren, skipping string literals and line comments.
List<(int, int)> _iconButtonNodes(String code) {
  final nodes = <(int, int)>[];
  var i = 0;
  while (true) {
    final start = code.indexOf('IconButton(', i);
    if (start == -1) break;
    final end = _matchingParen(code, start + 'IconButton('.length - 1);
    nodes.add((start, end));
    i = end + 1;
  }
  return nodes;
}

int _matchingParen(String code, int openParen) {
  var depth = 0;
  var i = openParen;
  while (i < code.length) {
    final c = code[i];
    if (c == "'" || c == '"') {
      i = _skipString(code, i);
      continue;
    }
    if (c == '//') {
      final nl = code.indexOf('\n', i);
      i = nl == -1 ? code.length : nl + 1;
      continue;
    }
    if (c == '(') depth++;
    if (c == ')') {
      depth--;
      if (depth == 0) return i;
    }
    i++;
  }
  return code.length - 1;
}

int _skipString(String code, int quoteAt) {
  final quote = code[quoteAt];
  var i = quoteAt + 1;
  while (i < code.length) {
    if (code[i] == '\\') {
      i += 2;
      continue;
    }
    if (code[i] == quote) return i + 1;
    i++;
  }
  return i;
}