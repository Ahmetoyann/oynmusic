class SongNameCleaner {
  static String cleanTrackName(String originalName) {
    String cleaned = originalName;
    
    // Remove (Remastered xxxx), (Live), (Official Audio) etc. in parentheses
    cleaned = cleaned.replaceAll(RegExp(r'\((Remastered|Live|Official|Bonus|feat\.|Radio Edit|Stereo|Mono)[^\)]*\)', caseSensitive: false), '');
    
    // Remove [Remastered xxxx], [Live] etc. in brackets
    cleaned = cleaned.replaceAll(RegExp(r'\[(Remastered|Live|Official|Bonus|feat\.|Radio Edit|Stereo|Mono)[^\]]*\]', caseSensitive: false), '');
    
    // Remove - Remastered xxxx, - Live, - Radio Edit etc.
    cleaned = cleaned.replaceAll(RegExp(r'-\s*(Remastered|Live|Radio Edit|Bonus Track|Official Audio).*$', caseSensitive: false), '');
    
    // Cleanup multiple spaces and trim
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return cleaned;
  }

  static String buildQuery(String artistName, String trackName) {
    final cleanedTrack = cleanTrackName(trackName);
    return '$artistName $cleanedTrack'.trim();
  }

  static int msToSeconds(int ms) {
    return (ms / 1000).round();
  }

  /// Checks if the local result duration matches the Spotify duration within a given tolerance
  static bool isDurationMatch(int localDurationSeconds, int spotifyDurationMs, {int toleranceSeconds = 4}) {
    if (spotifyDurationMs == 0 || localDurationSeconds == 0) return true; // Can't compare, assume match or handle gracefully
    
    final spotifyDurationSeconds = msToSeconds(spotifyDurationMs);
    final diff = (localDurationSeconds - spotifyDurationSeconds).abs();
    
    return diff <= toleranceSeconds;
  }
}
