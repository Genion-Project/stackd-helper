/// Konfigurasi aplikasi Stackd Helper.
/// Kredensial Notion OAuth yang digunakan untuk proses autentikasi.
class AppConfig {
  AppConfig._();

  static const String notionClientId = '366d872b-594c-8183-a25e-00371c7fbcdb';
  static const String notionRedirectUri = 'https://stackd.smknurisjkt.org/oauth/callback';
  static const String notionDatabaseId = '29d47a42e70680f5baece5d0e2bde50a';
  static const String notionPollBaseUrl = 'https://stackd.smknurisjkt.org/oauth/status';
}
