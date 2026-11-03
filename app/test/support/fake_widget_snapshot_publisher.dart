import 'package:usra/features/medicines/dose_widget.dart';

/// Remembers what the home-screen widget would show.
class FakeWidgetSnapshotPublisher implements WidgetSnapshotPublisher {
  final published = <WidgetSnapshot>[];

  WidgetSnapshot get last => published.last;

  @override
  Future<void> publish(WidgetSnapshot snapshot) async =>
      published.add(snapshot);
}
