import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_providers.g.dart';

/// Index of the currently selected destination in the app shell.
@riverpod
class CurrentDestination extends _$CurrentDestination {
  @override
  int build() => 0;

  void select(int index) => state = index;
}
