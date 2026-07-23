import 'dart:convert';

class ApiConfig {
  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  int maxTokens;
  int timeout;
  int defaultEnhanceLevel;
  String defaultEnhanceStyle;
  bool autoRetry;
  int concurrency;
  String chapterSplitMode;
  int chapterWordCount;

  ApiConfig({
    this.baseUrl = 'https://api.siliconflow.cn/v1',
    this.apiKey = '',
    this.model = 'deepseek-ai/DeepSeek-V2.5',
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.timeout = 60,
    this.defaultEnhanceLevel = 2,
    this.defaultEnhanceStyle = 'standard',
    this.autoRetry = true,
    this.concurrency = 1,
    this.chapterSplitMode = 'regex',
    this.chapterWordCount = 3000,
  });

  Map<String, dynamic> toMap() {
    return {
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'timeout': timeout,
      'defaultEnhanceLevel': defaultEnhanceLevel,
      'defaultEnhanceStyle': defaultEnhanceStyle,
      'autoRetry': autoRetry,
      'concurrency': concurrency,
      'chapterSplitMode': chapterSplitMode,
      'chapterWordCount': chapterWordCount,
    };
  }

  factory ApiConfig.fromMap(Map<String, dynamic> map) {
    return ApiConfig(
      baseUrl: map['baseUrl'] as String? ?? 'https://api.siliconflow.cn/v1',
      apiKey: map['apiKey'] as String? ?? '',
      model: map['model'] as String? ?? 'deepseek-ai/DeepSeek-V2.5',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: map['maxTokens'] as int? ?? 4096,
      timeout: map['timeout'] as int? ?? 60,
      defaultEnhanceLevel: map['defaultEnhanceLevel'] as int? ?? 2,
      defaultEnhanceStyle: map['defaultEnhanceStyle'] as String? ?? 'standard',
      autoRetry: map['autoRetry'] as bool? ?? true,
      concurrency: map['concurrency'] as int? ?? 1,
      chapterSplitMode: map['chapterSplitMode'] as String? ?? 'regex',
      chapterWordCount: map['chapterWordCount'] as int? ?? 3000,
    );
  }

  ApiConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
    int? timeout,
    int? defaultEnhanceLevel,
    String? defaultEnhanceStyle,
    bool? autoRetry,
    int? concurrency,
    String? chapterSplitMode,
    int? chapterWordCount,
  }) {
    return ApiConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeout: timeout ?? this.timeout,
      defaultEnhanceLevel: defaultEnhanceLevel ?? this.defaultEnhanceLevel,
      defaultEnhanceStyle: defaultEnhanceStyle ?? this.defaultEnhanceStyle,
      autoRetry: autoRetry ?? this.autoRetry,
      concurrency: concurrency ?? this.concurrency,
      chapterSplitMode: chapterSplitMode ?? this.chapterSplitMode,
      chapterWordCount: chapterWordCount ?? this.chapterWordCount,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory ApiConfig.fromJson(String json) => ApiConfig.fromMap(jsonDecode(json) as Map<String, dynamic>);
}
