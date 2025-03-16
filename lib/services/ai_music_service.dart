import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIMusicService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  static Future<List<Map<String, String>>> generateMusicRecommendations({
    required String mood,
    required List<String> genres,
  }) async {
    try {
      final prompt = _buildPrompt(mood, genres);
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['token']}',
        },
        body: jsonEncode({
          'model':
              'mixtral-8x7b-32768', // Using Mixtral model for better recommendations
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a music expert who provides song recommendations based on mood and genres.
Always respond with a list of songs in the format: "Artist - Song Title" with each song on a new line.
Ensure recommendations are accurate and match both the mood and genres specified.
Include a mix of classic and contemporary tracks.''',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 2048,
          'top_p': 0.9,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        print('API Response: $content');
        return _parseSongList(content);
      } else {
        print('API Error Response: ${response.body}');
        throw Exception(
            'Failed to generate recommendations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating recommendations: $e');
      return [];
    }
  }

  static String _buildPrompt(String mood, List<String> genres) {
    return '''
Generate a curated list of 10 songs that perfectly match this mood and these genres:
Mood: $mood
Genres: ${genres.join(', ')}

Requirements:
1. Songs should strongly reflect the $mood mood
2. Each song must belong to one of these genres: ${genres.join(', ')}
3. Include both well-known and lesser-known artists
4. Mix of classic and modern songs
5. Ensure high-quality, memorable songs that fit the mood

Format: List each song as "Artist - Song Title"
''';
  }

  static List<Map<String, String>> _parseSongList(String content) {
    final songs = content
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final parts = line.split(' - ');
          if (parts.length == 2) {
            return {
              'artist': parts[0].trim(),
              'title': parts[1].trim(),
            };
          }
          return null;
        })
        .where((song) => song != null)
        .cast<Map<String, String>>()
        .toList();

    return songs;
  }
}
