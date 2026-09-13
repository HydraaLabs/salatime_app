import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salatime/controller/audio_player_controller.dart';
import 'package:salatime/data/api/api_client.dart';

class _CountingController extends AudioPlayerController {
  _CountingController(ApiClient client, AudioHandler handler)
    : super(apiClient: client, audioHandler: handler);
  int updates = 0;
  @override
  void update([List<Object>? ids, bool condition = true]) {
    updates++;
    super.update(ids, condition);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test(
    'audio listeners update once and are released with the controller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final handler = BaseAudioHandler();
      final controller = Get.put(
        _CountingController(
          ApiClient(
            appBaseUrl: 'https://example.com',
            sharedPreferences: await SharedPreferences.getInstance(),
          ),
          handler,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final previous = controller.updates;
      handler.mediaItem.add(const MediaItem(id: 'first', title: 'First'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentMediaItem.value?.id, 'first');
      expect(controller.updates, previous + 1);
      // A completed state before a playlist exists must not access audioList.last.
      handler.playbackState.add(
        PlaybackState(processingState: AudioProcessingState.completed),
      );
      await Future<void>.delayed(Duration.zero);
      await Get.delete<_CountingController>();
      final closedUpdates = controller.updates;
      handler.mediaItem.add(const MediaItem(id: 'second', title: 'Second'));
      handler.playbackState.add(PlaybackState(playing: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.updates, closedUpdates);
      expect(controller.currentMediaItem.value?.id, 'first');
    },
  );
}
