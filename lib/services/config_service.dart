import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_config.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const _key = 'api_config';
  ApiConfig? _cached;

  Future<ApiConfig> loadConfig() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) {
      _cached = ApiConfig();
    } else {
      _cached = ApiConfig.fromJson(json);
    }
    return _cached!;
  }

  Future<void> saveConfig(ApiConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, config.toJson());
    _cached = config;
  }

  Future<void> resetConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cached = ApiConfig();
  }
}
