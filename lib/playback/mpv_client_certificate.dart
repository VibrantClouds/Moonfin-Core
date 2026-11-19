import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:server_core/server_core.dart';

import '../data/services/client_certificate_service.dart';
import '../preference/user_preferences.dart';

/// Points mpv at the client certificate for [url]'s host, or clears the one a
/// previous open set. mpv only takes file paths and has no key password, so
/// the key is written unencrypted to app-private storage. Also stops mpv
/// verifying the server's certificate while self-signed ones are allowed.
Future<void> applyMpvClientCertificate(Player player, String url) async {
  final platform = player.platform;
  if (platform is! NativePlayer) return;
  try {
    // NativePlayer's web stub has no setProperty, so the web build needs dynamic here.
    final dynamic native = platform;
    // mpv builds with libcurl, like the Windows one, verify certificates by
    // default, so a self-signed server the app was told to trust would refuse
    // to play. With the setting off, mpv gets its own default back rather
    // than a forced yes, because the FFmpeg 6.1 OpenSSL and mbedtls backends
    // in older builds load no system certificates.
    final allowSelfSigned = GetIt.instance<UserPreferences>().get(
      UserPreferences.allowSelfSignedCerts,
    );
    await native.setProperty(
      'tls-verify',
      allowSelfSigned
          ? 'no'
          : await native.getProperty('option-info/tls-verify/default-value'),
    );
    final certificate = clientCertificateFor(Uri.tryParse(url)?.host ?? '');
    var certPath = '';
    var keyPath = '';
    if (certificate != null) {
      final certFile = await clientCertificateFile(certificate.host, 'crt');
      final keyFile = await clientCertificateFile(certificate.host, 'key');
      await certFile.writeAsString(certificate.chainPem);
      await keyFile.writeAsString(certificate.keyPem);
      certPath = certFile.path;
      keyPath = keyFile.path;
    }
    await native.setProperty('tls-cert-file', certPath);
    await native.setProperty('tls-key-file', keyPath);
  } catch (_) {
    // Playback still goes ahead, and a server that needs the certificate
    // refuses it.
  }
}
