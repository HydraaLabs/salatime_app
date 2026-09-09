import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:zabi/helper/audio_handler.dart';

class _Player implements AudioPlayer {
  final indices = StreamController<int?>.broadcast();
  final events = StreamController<PlaybackEvent>.broadcast();
  int stops = 0;
  int disposals = 0;
  int loads = 0;
  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<int?> get currentIndexStream => indices.stream;
  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loads++;
    return Duration.zero;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reloading playlists keeps one index listener and stop remains reusable',
    () async {
      final player = _Player();
      final handler = AudioPlayerHandler(player: player);
      final items = [
        {'path': 'https://example.com/1.mp3', 'sura_name': 'First'},
        {'path': 'https://example.com/2.mp3', 'sura_name': 'Second'},
      ];
      await handler.loadAudioFromApi(items);
      await handler.loadAudioFromApi(items);
      int events = 0;
      final subscription = handler.mediaItem.listen((_) => events++);
      await Future<void>.delayed(Duration.zero);
      final previous = events;
      player.indices.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.title, 'Second');
      expect(events, previous + 1);
      await handler.stop();
      expect(player.stops, 1);
      expect(player.disposals, 0);
      await handler.loadAudioFromApi(items);
      expect(player.loads, 3);
      await subscription.cancel();
      await player.indices.close();
      await player.events.close();
    },
  );
}
