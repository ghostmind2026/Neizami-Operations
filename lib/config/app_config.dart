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

  static Uri restRouteUri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final parameters = <String, String>{
      'rest_route': '/neizami-mobile/v1$normalizedPath',
      ...?query?.map((key, value) => MapEntry(key, '$value')),
    };
    return Uri.parse('$cleanBase/').replace(queryParameters: parameters);
  }

  static Uri mobileFormUri(String formKey, String token) {
    final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$cleanBase/').replace(
      queryParameters: {
        'nzmb_mobile_form': formKey,
        'app_id': appId,
        'token': token,
      },
    );
  }
}
