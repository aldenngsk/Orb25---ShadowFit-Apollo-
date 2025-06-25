import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StravaService {
  static const String _clientId = '163976'; 
  static const String _clientSecret = 'b4c88aee7865bdc6f51909d27a056f87b63ab4f7'; 
  static const String _redirectUri = 'https://shadowfit.netlify.app';
  static const String _authUrl = 'https://www.strava.com/oauth/authorize';
  static const String _tokenUrl = 'https://www.strava.com/oauth/token';
  static const String _apiBaseUrl = 'https://www.strava.com/api/v3';

  static String? _accessToken;
  static String? _refreshToken;
  static DateTime? _tokenExpiry;

  // Initialize Strava service
  static Future<void> initialize() async {
    await _loadTokens();
    print('[StravaService] initialize: _accessToken=$_accessToken, _tokenExpiry=$_tokenExpiry');
  }

  // Check if user is authenticated
  static bool get isAuthenticated {
    print('[StravaService] isAuthenticated: _accessToken=$_accessToken, _tokenExpiry=$_tokenExpiry');
    return _accessToken != null && _tokenExpiry != null && 
           DateTime.now().isBefore(_tokenExpiry!);
  }

  // Start OAuth flow
  static Future<bool> authenticate() async {
    try {
      final authUrl = Uri.parse(_authUrl).replace(queryParameters: {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUri,
        'scope': 'activity:read_all',
        'approval_prompt': 'force',
      });
      print('OAuth URL: $authUrl'); // Debug print

      final canLaunch = await canLaunchUrl(authUrl);
      if (!canLaunch) {
        print('Cannot launch Strava auth URL');
        return false;
      }

      await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      print('Error launching Strava auth: $e');
      return false;
    }
  }

  // Handle OAuth callback
  static Future<bool> handleCallback(String code) async {
    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        print('[StravaService] handleCallback: Got token, _accessToken=$_accessToken, _tokenExpiry=$_tokenExpiry');
        await _saveTokens();
        await initialize(); // Ensure in-memory state is up to date
        return true;
      } else {
        print('[StravaService] handleCallback: Token exchange failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('[StravaService] handleCallback: Error: $e');
      return false;
    }
  }

  // Refresh access token
  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse(_tokenUrl),
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'refresh_token': _refreshToken!,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        
        await _saveTokens();
        return true;
      } else {
        print('Token refresh failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  // Get user's recent activities
  static Future<List<StravaActivity>> getRecentActivities({int perPage = 10}) async {
    if (!isAuthenticated) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/athlete/activities').replace(queryParameters: {
          'per_page': perPage.toString(),
        }),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> activities = json.decode(response.body);
        return activities.map((activity) => StravaActivity.fromJson(activity)).toList();
      } else {
        print('Failed to fetch activities: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching activities: $e');
      return [];
    }
  }

  // Get activities for a specific date range
  static Future<List<StravaActivity>> getActivitiesForDateRange(
    DateTime startDate, 
    DateTime endDate
  ) async {
    if (!isAuthenticated) {
      final refreshed = await _refreshAccessToken();
      if (!refreshed) return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/athlete/activities').replace(queryParameters: {
          'after': (startDate.millisecondsSinceEpoch / 1000).round().toString(),
          'before': (endDate.millisecondsSinceEpoch / 1000).round().toString(),
          'per_page': '200',
        }),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> activities = json.decode(response.body);
        return activities.map((activity) => StravaActivity.fromJson(activity)).toList();
      } else {
        print('Failed to fetch activities: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching activities: $e');
      return [];
    }
  }

  // Check if user has completed a run today
  static Future<bool> hasCompletedRunToday({double minDistance = 2.4}) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final activities = await getActivitiesForDateRange(startOfDay, endOfDay);
    
    return activities.any((activity) => 
      activity.type == 'Run' && 
      activity.distance >= minDistance * 1000 // Convert km to meters
    );
  }

  // Save tokens to local storage
  static Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('strava_access_token', _accessToken ?? '');
    await prefs.setString('strava_refresh_token', _refreshToken ?? '');
    await prefs.setString('strava_token_expiry', _tokenExpiry?.toIso8601String() ?? '');
  }

  // Load tokens from local storage
  static Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('strava_access_token');
    _refreshToken = prefs.getString('strava_refresh_token');
    final expiryString = prefs.getString('strava_token_expiry');
    if (expiryString != null && expiryString.isNotEmpty) {
      _tokenExpiry = DateTime.parse(expiryString);
    }
  }

  // Logout
  static Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('strava_access_token');
    await prefs.remove('strava_refresh_token');
    await prefs.remove('strava_token_expiry');
  }
}

class StravaActivity {
  final int id;
  final String name;
  final String type;
  final double distance; // in meters
  final int movingTime; // in seconds
  final DateTime startDate;
  final String? description;

  StravaActivity({
    required this.id,
    required this.name,
    required this.type,
    required this.distance,
    required this.movingTime,
    required this.startDate,
    this.description,
  });

  factory StravaActivity.fromJson(Map<String, dynamic> json) {
    return StravaActivity(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      distance: json['distance']?.toDouble() ?? 0.0,
      movingTime: json['moving_time'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      description: json['description'],
    );
  }

  // Get distance in kilometers
  double get distanceInKm => distance / 1000;

  // Get moving time in minutes
  double get movingTimeInMinutes => movingTime / 60;
} 