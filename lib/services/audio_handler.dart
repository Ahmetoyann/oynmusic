// lib/services/audio_handler.dart
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

/// Müzik çalar işlemlerini ve bildirim yönetimini sağlayan Handler sınıfı.
class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  // SongProvider'ın bu oynatıcıya erişmesi gerekebilir (PlayerPage uyumluluğu için)
  AudioPlayer get audioPlayer => _player;

  // Sonraki ve Önceki şarkı isteklerini Provider'a iletmek için stream'ler
  final BehaviorSubject<void> _skipNextSubject = BehaviorSubject<void>();
  final BehaviorSubject<void> _skipPrevSubject = BehaviorSubject<void>();

  Stream<void> get skipNextStream => _skipNextSubject.stream;
  Stream<void> get skipPrevStream => _skipPrevSubject.stream;

  MyAudioHandler() {
    // Oynatıcı durumunu dinle ve AudioService durumunu güncelle
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  /// just_audio olaylarını audio_service PlaybackState'ine dönüştürür
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop, // Durdur butonunu ekledik
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop, // Sistem eylemlerine de ekledik
      },
      // Kompakt görünümde (küçük bildirim) hangi butonların görüneceği.
      // [0, 1, 2] -> Önceki, Oynat/Duraklat, Sonraki butonlarını gösterir.
      // Stop butonu (3. indeks) sadece genişletilmiş bildirimde görünür.
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  /// Yeni bir şarkı çalmak için çağrılır
  Future<void> playSong(MediaItem item, String uri) async {
    // Bildirimdeki bilgileri güncelle
    mediaItem.add(item);

    // Kaynağı ayarla ve oynat
    try {
      Uri audioUri;
      Map<String, String>? headers;

      if (uri.startsWith('http')) {
        audioUri = Uri.parse(uri);
        // 403 (Forbidden) hatasını çözmek için tarayıcı benzeri bir User-Agent ekliyoruz.
        headers = {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        };
      } else {
        audioUri = Uri.file(uri);
      }
      await _player.setAudioSource(AudioSource.uri(audioUri, headers: headers));
      play();
    } catch (e) {
      print("Oynatma hatası: $e");
      rethrow; // Hatayı SongProvider'a ilet
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> skipToNext() async {
    _skipNextSubject.add(null); // Provider'a sinyal gönder
  }

  @override
  Future<void> skipToPrevious() async {
    _skipPrevSubject.add(null); // Provider'a sinyal gönder
  }
}
