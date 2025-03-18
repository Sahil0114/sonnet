import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:sonnet/random_circles.dart';
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:sonnet/services/ai_music_service.dart';

class PromptScreen extends StatefulWidget {
  final VoidCallback showHomeScreen;
  const PromptScreen({super.key, required this.showHomeScreen});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  // Genre list
  final List<String> genres = [
    'Jazz',
    'Rock',
    'Amapiano',
    'R&B',
    'Latin',
    'Hip-Hop',
    'Hip-Life',
    'Reggae',
    'Gospel',
    'Afrobeat',
    'Blues',
    'Country',
    'Punk',
    'Pop',
  ];

  // Selected genres list
  final Set<String> _selectedGenres = {};

  // Selected mood
  String? _selectedMood;

  // Selected mood image
  String? _selectedMoodImage;

  // Playlist
  List<Map<String, String>> _playlist = [];

  // Loading state
  bool _isLoading = false;

  // Add Spotify auth variables
  // TODO: Replace with your Spotify Client ID from https://developer.spotify.com/dashboard
  static const String clientId = '300c08e30f6945478918da97e961f124';
  // TODO: Replace with your Spotify Client Secret from https://developer.spotify.com/dashboard
  static const String clientSecret = 'c6728b41b0c84f0c8c7f6fb83f8292f7';
  static const String redirectUri = 'sonnet://callback';
  String? _spotifyAccessToken;

  // Add a ScrollController for the playlist
  final ScrollController _scrollController = ScrollController();

  // Add these new fields for audio playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _currentlyPlayingIndex;
  bool _isPlaying = false;
  bool _isSearching = false;
  double _playbackProgress = 0.0;
  String? _currentSongUrl;
  String? _currentSongTitle;
  String? _currentSongArtist;
  bool _isPreviewMode =
      true; // Track if we're in preview mode or full song mode
  bool _previewEnded = false; // Track if the preview has ended

  // Add these variables to the state class - place near the other audio-related fields
  bool _isLoadingFullSong = false;
  bool _isPlayingFullSong = false;

  @override
  void initState() {
    super.initState();

    // Set up audio player listeners
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _playbackProgress = 0.0;
          if (_isPreviewMode) {
            _previewEnded = true; // Mark preview as ended
          }
        });
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (_audioPlayer.duration != null) {
        setState(() {
          _playbackProgress =
              position.inMilliseconds / _audioPlayer.duration!.inMilliseconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Function for selected genre(s)
  void _onGenreTap(String genre) {
    setState(() {
      if (_selectedGenres.contains(genre)) {
        _selectedGenres.remove(genre);
      } else {
        _selectedGenres.add(genre);
      }
    });
  }

  // Function to submit mood and genres and fetch playlist
  Future<void> _submitSelections() async {
    if (_selectedMood == null || _selectedGenres.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mood and at least one genre'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final recommendations = await AIMusicService.generateMusicRecommendations(
        mood: _selectedMood!,
        genres: _selectedGenres.toList(),
      );

      setState(() {
        _playlist = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch playlist')),
      );
    }
  }

  Future<void> _authenticateSpotify() async {
    try {
      // Show a dialog explaining the manual authentication process
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1DB954),
            title: Text(
              'Spotify Authentication',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You will be redirected to Spotify to authorize this app. After authorizing, you\'ll need to manually enter the authorization code.',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                const SizedBox(height: 20),
                _buildSpotifyButton(
                  'Open Spotify Authorization',
                  Icons.open_in_new,
                  () async {
                    // Step 1: Open the authorization URL in browser
                    final authUrl =
                        Uri.https('accounts.spotify.com', '/authorize', {
                      'client_id': clientId,
                      'response_type': 'code',
                      'redirect_uri': redirectUri,
                      'scope': 'playlist-modify-public playlist-modify-private',
                    });

                    if (await canLaunchUrl(authUrl)) {
                      await launchUrl(authUrl,
                          mode: LaunchMode.externalApplication);
                      Navigator.pop(context);

                      // Show dialog to enter the code
                      _showCodeInputDialog();
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Spotify authentication error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to authenticate with Spotify')),
      );
    }
  }

  void _showCodeInputDialog() {
    String authCode = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Enter Authorization Code',
            style: GoogleFonts.inter(
              color: const Color(0xFF1DB954),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'After authorizing, you\'ll be redirected to a page that might not load. Copy the "code" parameter from the URL and paste it below:',
                style: GoogleFonts.inter(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) {
                  authCode = value;
                },
                decoration: InputDecoration(
                  hintText: 'Paste code here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (authCode.isNotEmpty) {
                  _exchangeCodeForToken(authCode);
                }
              },
              child: Text(
                'Submit',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1DB954),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exchangeCodeForToken(String code) async {
    try {
      // Step 2: Exchange code for access token
      final tokenResponse = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw 'Failed to get access token: ${tokenResponse.body}';
      }

      final tokenData = jsonDecode(tokenResponse.body);
      _spotifyAccessToken = tokenData['access_token'];

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully connected to Spotify')),
      );
    } catch (e) {
      print('Token exchange error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get access token: $e')),
      );
    }
  }

  Future<void> _createSpotifyPlaylist() async {
    try {
      if (_spotifyAccessToken == null) {
        await _authenticateSpotify();
        if (_spotifyAccessToken == null) return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creating playlist...')),
      );

      // Get user ID
      final userResponse = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $_spotifyAccessToken'},
      );

      if (userResponse.statusCode == 401) {
        // Token expired, try to authenticate again
        await _authenticateSpotify();
        if (_spotifyAccessToken == null) throw 'Authentication failed';

        // Retry with new token
        return _createSpotifyPlaylist();
      }

      if (userResponse.statusCode != 200) {
        throw 'Failed to get user info: ${userResponse.body}';
      }

      final userId = jsonDecode(userResponse.body)['id'];

      // Create playlist
      final playlistName =
          'Sonnet: ${_selectedMood} ${_selectedGenres.join(", ")}';
      final playlistResponse = await http.post(
        Uri.parse('https://api.spotify.com/v1/users/$userId/playlists'),
        headers: {
          'Authorization': 'Bearer $_spotifyAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': playlistName,
          'description':
              'Generated by Sonnet - Mood: $_selectedMood, Genres: ${_selectedGenres.join(", ")}',
          'public': false,
        }),
      );

      if (playlistResponse.statusCode != 201) {
        throw 'Failed to create playlist: ${playlistResponse.body}';
      }

      final playlistData = jsonDecode(playlistResponse.body);
      final playlistId = playlistData['id'];
      final playlistUrl = playlistData['external_urls']['spotify'];

      // Search and add tracks
      List<String> trackUris = [];
      List<String> notFoundSongs = [];

      for (var song in _playlist) {
        final query = Uri.encodeComponent('${song['artist']} ${song['title']}');
        final searchResponse = await http.get(
          Uri.parse(
              'https://api.spotify.com/v1/search?q=$query&type=track&limit=1'),
          headers: {'Authorization': 'Bearer $_spotifyAccessToken'},
        );

        if (searchResponse.statusCode == 200) {
          final items = jsonDecode(searchResponse.body)['tracks']['items'];
          if (items.isNotEmpty) {
            trackUris.add(items[0]['uri']);
          } else {
            notFoundSongs.add('${song['title']} by ${song['artist']}');
          }
        } else {
          print('Search error: ${searchResponse.body}');
          notFoundSongs.add('${song['title']} by ${song['artist']}');
        }
      }

      if (trackUris.isEmpty) {
        throw 'Could not find any of the songs on Spotify';
      }

      // Add tracks to playlist
      final addTracksResponse = await http.post(
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/tracks'),
        headers: {
          'Authorization': 'Bearer $_spotifyAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'uris': trackUris}),
      );

      if (addTracksResponse.statusCode != 201) {
        throw 'Failed to add tracks: ${addTracksResponse.body}';
      }

      // Success message
      ScaffoldMessenger.of(context).clearSnackBars();

      // Show success dialog with link to open playlist
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1DB954),
            title: Text(
              'Playlist Created!',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your playlist "$playlistName" has been created with ${trackUris.length} songs.',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                if (notFoundSongs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Some songs could not be found:',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: notFoundSongs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Text(
                            '• ${notFoundSongs[index]}',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildSpotifyButton(
                  'Open Playlist in Spotify',
                  Icons.open_in_new,
                  () async {
                    Navigator.pop(context);
                    final spotifyUri = Uri.parse(playlistUrl);
                    if (await canLaunchUrl(spotifyUri)) {
                      await launchUrl(spotifyUri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create playlist: $e')),
      );
      print('Playlist creation error: $e');
    }
  }

  Future<void> _openSpotify() async {
    try {
      // Take first song as the main search query for better results
      final firstSong = _playlist.first;
      final mainQuery =
          Uri.encodeComponent('${firstSong['artist']} ${firstSong['title']}');
      final url =
          Uri.parse('https://open.spotify.com/search/$mainQuery/tracks');

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1DB954),
            title: Text(
              'Open in Spotify',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose how to open:',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                const SizedBox(height: 20),
                // Create playlist button
                _buildSpotifyButton(
                  'Create Spotify Playlist',
                  Icons.playlist_add,
                  () async {
                    Navigator.pop(context);
                    await _createSpotifyPlaylist();
                  },
                ),
                const SizedBox(height: 12),
                // Search all songs button
                _buildSpotifyButton(
                  'Search All Songs',
                  Icons.search,
                  () async {
                    Navigator.pop(context);
                    final searchQuery = Uri.encodeComponent(_playlist
                        .map((song) => '${song['artist']} ${song['title']}')
                        .join(' OR '));
                    final searchUrl = Uri.parse(
                        'https://open.spotify.com/search/$searchQuery');
                    if (await canLaunchUrl(searchUrl)) {
                      await launchUrl(searchUrl,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Search first song button
                _buildSpotifyButton(
                  'Search First Song',
                  Icons.music_note,
                  () async {
                    Navigator.pop(context);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Spotify')),
      );
    }
  }

  Widget _buildSpotifyButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1DB954)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF1DB954),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAudiomack() async {
    final playlistQuery = _playlist
        .map((song) => '${song['artist']} - ${song['title']}')
        .join(', ');
    final url = Uri.parse('https://audiomack.com/search/$playlistQuery');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Function to show the first column
  void _showFirstColumn() {
    setState(() {
      _playlist = [];
      _selectedGenres.clear();
    });
  }

  // Replace the _playSearchSong function with this new implementation
  Future<void> _playSpotifyPreview(int index) async {
    final song = _playlist[index];
    final songTitle = song['title'] ?? '';
    final songArtist = song['artist'] ?? '';

    setState(() {
      _isSearching = true;
      _currentlyPlayingIndex = index;
      _currentSongTitle = songTitle;
      _currentSongArtist = songArtist;
      _isPreviewMode = true;
      _previewEnded = false;
    });

    try {
      // Search for the song on Spotify
      final query = Uri.encodeComponent('track:$songTitle artist:$songArtist');
      final searchUrl =
          'https://api.spotify.com/v1/search?q=$query&type=track&limit=1';

      // Get a token for the API call
      // Note: This is a client credentials flow that doesn't require user auth
      final tokenResponse = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        },
        body: {
          'grant_type': 'client_credentials',
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw 'Failed to get access token for Spotify API';
      }

      final tokenData = jsonDecode(tokenResponse.body);
      final apiToken = tokenData['access_token'];

      // Now use the token to search for the track
      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'Authorization': 'Bearer $apiToken'},
      );

      if (response.statusCode != 200) {
        throw 'Failed to search Spotify: ${response.body}';
      }

      final data = jsonDecode(response.body);

      if (data['tracks']['items'].isEmpty) {
        throw 'No results found on Spotify';
      }

      final trackData = data['tracks']['items'][0];
      final previewUrl = trackData['preview_url'];

      if (previewUrl == null) {
        throw 'No preview available for this track';
      }

      _currentSongUrl = previewUrl;

      // Play the preview
      await _audioPlayer.setUrl(previewUrl);
      await _audioPlayer.play();

      setState(() {
        _isPlaying = true;
        _isSearching = false;
      });
    } catch (e) {
      print('Error playing Spotify preview: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play preview: $e')),
      );
      setState(() {
        _isSearching = false;
        _isPreviewMode = true;
        _previewEnded = false;
      });
    }
  }

  // Helper to build song list item
  Widget _buildSongListItem(int index, Map<String, String> song) {
    final isPlaying = _currentlyPlayingIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 12),
      decoration: BoxDecoration(
        color: isPlaying
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: isPlaying && _isSearching
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : isPlaying
                    ? IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                        tooltip:
                            _isPreviewMode ? '30-sec preview' : 'Full song',
                      )
                    : Text(
                        '${index + 1}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
          ),
        ),
        title: Text(
          song['title'] ?? '',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          song['artist'] ?? '',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        trailing: isPlaying
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show preview badge if in preview mode
                  if (_isPreviewMode)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Preview',
                        style: GoogleFonts.inter(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.white70,
                    ),
                    onPressed: _stopPlayback,
                  ),
                ],
              )
            : IconButton(
                icon: const Icon(
                  Icons.play_arrow,
                  color: Colors.white70,
                ),
                onPressed: () => _playSpotifyPreview(index),
                tooltip: 'Play 30-sec preview',
              ),
        onTap: () {
          if (isPlaying) {
            _togglePlayPause();
          } else {
            _playSpotifyPreview(index);
          }
        },
      ),
    );
  }

  // Now let's add the YouTube full song playback functionality

  // Add this method to check and play the full song via YouTube
  Future<void> _tryPlayFullSongFromYoutube() async {
    if (_currentlyPlayingIndex == null) return;

    final song = _playlist[_currentlyPlayingIndex!];
    final songTitle = song['title'] ?? '';
    final songArtist = song['artist'] ?? '';

    setState(() {
      _isLoadingFullSong = true;
    });

    try {
      // Try to find the song on YouTube using public API
      final query = Uri.encodeComponent('$songArtist $songTitle audio');

      // Check if we have a YouTube API key
      if (dotenv.env['YOUTUBE_API_KEY'] == null ||
          dotenv.env['YOUTUBE_API_KEY'] == 'YOUR_API_KEY_HERE') {
        throw 'YouTube API key not configured';
      }

      final searchUrl =
          'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=$query&type=video&key=${dotenv.env['YOUTUBE_API_KEY']}';

      final response = await http.get(Uri.parse(searchUrl));

      if (response.statusCode != 200) {
        throw 'Failed to search YouTube: ${response.body}';
      }

      final data = jsonDecode(response.body);
      if (data['items'] == null || data['items'].isEmpty) {
        throw 'No results found on YouTube';
      }

      // In a real app, you would need to check if the song is free/available
      // For this implementation, we'll simulate a check by looking at the title
      final videoTitle = data['items'][0]['snippet']['title'] as String;
      final videoId = data['items'][0]['id']['videoId'];

      // Simulate a check for "legal to play" based on some keywords
      // This is NOT a reliable method for actual copyright checking - just a demo
      final containsCopyrightTerms =
          videoTitle.toLowerCase().contains('official audio') ||
              videoTitle.toLowerCase().contains('official music video') ||
              videoTitle.toLowerCase().contains('provided to youtube');

      if (containsCopyrightTerms) {
        // Show legal notice dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                'Copyright Notice',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copyright,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This song cannot be played in full due to copyright restrictions.',
                    style: GoogleFonts.inter(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can continue listening to the preview or open this song in Spotify.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Back to Preview',
                    style: GoogleFonts.inter(),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    final query = Uri.encodeComponent('$songArtist $songTitle');
                    launchUrl(
                      Uri.parse('https://open.spotify.com/search/$query'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(
                    'Open in Spotify',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1DB954),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        setState(() {
          _isLoadingFullSong = false;
        });
        return;
      }

      // If it's legally playable, play the full song
      final audioUrl = 'https://www.youtube.com/watch?v=$videoId';

      // Stop the current preview
      await _audioPlayer.stop();

      // Start playing the full song
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      setState(() {
        _isLoadingFullSong = false;
        _isPlaying = true;
        _isPlayingFullSong = true;
        _isPreviewMode = false;
        _previewEnded = false;
        _currentSongUrl = audioUrl;
      });
    } catch (e) {
      print('Error playing full song: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play full song: $e'),
            action: SnackBarAction(
              label: 'Try Spotify',
              onPressed: () {
                if (_currentlyPlayingIndex != null) {
                  final song = _playlist[_currentlyPlayingIndex!];
                  final query =
                      Uri.encodeComponent('${song['artist']} ${song['title']}');
                  launchUrl(
                    Uri.parse('https://open.spotify.com/search/$query'),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          ),
        );
      }

      setState(() {
        _isLoadingFullSong = false;
      });
    }
  }

  // Update the _buildPlayerBar method to include full song options
  Widget _buildPlayerBar() {
    if (_currentlyPlayingIndex == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Album art or placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.music_note,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentSongTitle ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _currentSongArtist ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Preview/Full song indicator
              _isPlayingFullSong
                  ? Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Full Song',
                        style: GoogleFonts.inter(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : _isPreviewMode
                      ? Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Preview (30s)',
                            style: GoogleFonts.inter(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
              // Play/pause button
              _isSearching || _isLoadingFullSong
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlayPause,
                    ),
              // Stop button
              IconButton(
                icon: const Icon(
                  Icons.stop,
                  color: Colors.white70,
                ),
                onPressed: _stopPlayback,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          LinearProgressIndicator(
            value: _playbackProgress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
                _isPlayingFullSong ? Colors.green : Colors.white),
          ),
          // Show message after preview ends or full song options
          if (_previewEnded && !_isPlaying)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Text(
                    'Preview ended. What would you like to do?',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Button row with options
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Try full song on YouTube button
                      InkWell(
                        onTap: _tryPlayFullSongFromYoutube,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8), // YouTube red
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Try Full Song',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Open in Spotify button
                      InkWell(
                        onTap: () {
                          if (_currentlyPlayingIndex != null) {
                            final song = _playlist[_currentlyPlayingIndex!];
                            final query = Uri.encodeComponent(
                                '${song['artist']} ${song['title']}');
                            launchUrl(
                              Uri.parse(
                                  'https://open.spotify.com/search/$query'),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954), // Spotify green
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/spotify.png',
                                width: 16,
                                height: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Spotify',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Update stopPlayback to handle full song mode
  void _stopPlayback() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _isPlayingFullSong = false;
      _currentlyPlayingIndex = null;
      _playbackProgress = 0.0;
      _currentSongUrl = null;
      _currentSongTitle = null;
      _currentSongArtist = null;
      _isPreviewMode = true;
      _previewEnded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Container for contents
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF330000),
              Color(0xFF000000),
            ],
          ),

          // Background image here
          image: DecorationImage(
            image: AssetImage(
              "assets/images/background.png",
            ),
            fit: BoxFit.cover,
          ),
        ),

        // Padding around contents
        child: Padding(
          padding: const EdgeInsets.only(top: 50.0, left: 16.0, right: 16.0),
          child: _isLoading
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    height: 50.0,
                    width: 50.0,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF000000),
                    ),
                  ),
                )
              : _playlist.isEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First expanded for random circles for moods
                        Expanded(
                          flex: 3, // Increased flex for better image proportion
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio:
                                    1, // Square aspect ratio for better fit
                                child: RandomCircles(
                                  onMoodSelected: (mood, image) {
                                    _selectedMood = mood;
                                    _selectedMoodImage = image;
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Second expanded for various genres and submit button
                        Expanded(
                          flex: 2, // Decreased flex for better balance
                          child: Padding(
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Genre text here
                                Text(
                                  'Genre',
                                  style: GoogleFonts.inter(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFFFFFF)
                                        .withOpacity(0.8),
                                  ),
                                ),

                                // Padding around various genres in a wrap
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 10.0,
                                    right: 10.0,
                                    top: 5.0,
                                  ),

                                  // Wrap starts here
                                  child: StatefulBuilder(
                                    builder: (BuildContext context,
                                        StateSetter setState) {
                                      return Wrap(
                                        children: genres.map((genre) {
                                          final isSelected =
                                              _selectedGenres.contains(genre);
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (_selectedGenres
                                                    .contains(genre)) {
                                                  _selectedGenres.remove(genre);
                                                } else {
                                                  _selectedGenres.add(genre);
                                                }
                                              });
                                            },

                                            // Container with border around each genre
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(3.0),
                                              margin: const EdgeInsets.only(
                                                  right: 4.0, top: 4.0),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                                border: Border.all(
                                                  width: 0.4,
                                                  color: const Color(0xFFFFFFFF)
                                                      .withOpacity(0.8),
                                                ),
                                              ),

                                              // Container for each genre
                                              child: Container(
                                                padding: const EdgeInsets.only(
                                                  left: 16.0,
                                                  right: 16.0,
                                                  top: 8.0,
                                                  bottom: 8.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? const Color(0xFF0000FF)
                                                      : const Color(0xFFFFFFFF)
                                                          .withOpacity(0.8),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20.0),
                                                ),

                                                // Text for each genre
                                                child: Text(
                                                  genre,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFFFFFFFF)
                                                        : const Color(
                                                            0xFF000000),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                  // Wrap ends here
                                ),

                                // Padding around the submit button here
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 60.0,
                                    left: 10.0,
                                    right: 10.0,
                                  ),

                                  // Container for submit button in GestureDetector
                                  child: GestureDetector(
                                    onTap: _submitSelections,

                                    // Container for submit button
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 15.0),
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        color: const Color(0xFFFFCCCC),
                                      ),

                                      // Submit text centered
                                      child: Center(
                                        // Submit text here
                                        child: Text(
                                          'Submit',
                                          style: GoogleFonts.inter(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Back button and title row
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                              ),
                              onPressed: _showFirstColumn,
                            ),
                            Text(
                              'Your Playlist',
                              style: GoogleFonts.inter(
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Mood and genres info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              if (_selectedMoodImage != null)
                                Image.asset(
                                  _selectedMoodImage!,
                                  width: 40,
                                  height: 40,
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mood: ${_selectedMood}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Genres: ${_selectedGenres.join(", ")}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Scrollable songs list with side indicator
                        Expanded(
                          child: Row(
                            children: [
                              // Main scrollable list
                              Expanded(
                                child: ScrollConfiguration(
                                  behavior:
                                      ScrollConfiguration.of(context).copyWith(
                                    scrollbars: false, // Hide default scrollbar
                                  ),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: _playlist.length,
                                    itemBuilder: (context, index) {
                                      final song = _playlist[index];
                                      return _buildSongListItem(index, song);
                                    },
                                  ),
                                ),
                              ),
                              // Custom scrollbar
                              GestureDetector(
                                onVerticalDragUpdate: (details) {
                                  // Calculate new scroll position based on drag
                                  if (_scrollController.hasClients) {
                                    final double scrollFraction =
                                        details.delta.dy /
                                            MediaQuery.of(context).size.height;
                                    final double scrollDistance =
                                        scrollFraction *
                                            _scrollController
                                                .position.maxScrollExtent;
                                    _scrollController.position.jumpTo(
                                      (_scrollController.position.pixels +
                                              scrollDistance)
                                          .clamp(
                                              0.0,
                                              _scrollController
                                                  .position.maxScrollExtent),
                                    );
                                  }
                                },
                                child: Container(
                                  width:
                                      8, // Made slightly wider for better touch target
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _scrollController,
                                    builder: (context, child) {
                                      // Only show scroll indicator if there are enough items to scroll
                                      if (!_scrollController.hasClients ||
                                          _scrollController
                                                  .position.maxScrollExtent ==
                                              0) {
                                        return const SizedBox.shrink();
                                      }

                                      // Calculate position of the scroll indicator
                                      final double scrollFraction =
                                          _scrollController.position.pixels /
                                              _scrollController
                                                  .position.maxScrollExtent;
                                      final double indicatorHeight =
                                          50.0; // Height of the scroll indicator
                                      final double maxOffset =
                                          MediaQuery.of(context).size.height *
                                                  0.5 -
                                              indicatorHeight;
                                      final double offset =
                                          scrollFraction * maxOffset;

                                      return Stack(
                                        children: [
                                          Positioned(
                                            top: offset,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: indicatorHeight,
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add player bar above the streaming service buttons
                        _buildPlayerBar(),
                        // Streaming service buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStreamingButton(
                                'assets/images/spotify.png',
                                'Open in Spotify',
                                _openSpotify,
                              ),
                              _buildStreamingButton(
                                'assets/images/audiomack.png',
                                'Open in Audiomack',
                                _openAudiomack,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
      floatingActionButton: _playlist.isEmpty
          ? Container()
          : Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFFFCCCC).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100.0),
                ),
                onPressed: _showFirstColumn,
                child: const Icon(
                  Icons.add_outlined,
                ),
              ),
            ),
    );
  }

  Widget _buildStreamingButton(
      String imagePath, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              width: 24,
              height: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to toggle play/pause
  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });
  }
}
