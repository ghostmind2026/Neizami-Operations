class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'NEIZAMI_BASE_URL',
    defaultValue: 'https://signalsjo.com/pmo',
  );

  static const String appId = String.fromEnvironment(
    'NEIZAMI_APP_ID',
    defaultValue: 'operations',
  );

  static const String apiPrefix = '/wp-json/neizami-mobile/v1';

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$cleanBase$apiPrefix$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }
}
