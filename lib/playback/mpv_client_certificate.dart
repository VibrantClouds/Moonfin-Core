import 'package:get_it/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:server_core/server_core.dart';

import '../data/services/client_certificate_service.dart';
import '../preference/user_preferences.dart';

// mpv's own tls-verify default, read before the first open changes it.
String? _mpvTlsVerifyDefault;

/// Points mpv at the client certificate for [url]'s host, or clears the one a
/// previous open set. mpv only takes file paths and has no key password, so
/// the key is written unencrypted to app-private storage. Also stops mpv
/// verifying the server's certificate while self-signed ones are allowed.
Future<void> applyMpvClientCertificate(Player player, String url) async {
  final platform = player.platform;
  if (platform is! NativePlayer) return;
  try {
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
    // NativePlayer's web stub has no setProperty, so the web build needs dynamic here.
    final dynamic native = platform;
    await native.setProperty('tls-cert-file', certPath);
    await native.setProperty('tls-key-file', keyPath);
    // mpv 0.42 verifies certificates by default, so a self-signed server the
    // app was told to trust would refuse to play. Turning the setting off
    // puts back the build's own default rather than forcing verification on
    // older builds, whose FFmpeg may not load the system certificates.
    _mpvTlsVerifyDefault ??= (await native.getProperty('tls-verify')) as String;
    final allowSelfSigned = GetIt.instance<UserPreferences>().get(
      UserPreferences.allowSelfSignedCerts,
    );
    await native.setProperty(
      'tls-verify',
      allowSelfSigned ? 'no' : _mpvTlsVerifyDefault,
    );
  } catch (_) {
    // Playback still goes ahead, and a server that needs the certificate
    // refuses it.
  }
}
