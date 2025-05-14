import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

late final Future<void> fbInit;

/// Da chiamare una sola volta (es. in main.dart)
Future<void> setupFacebook() async {
  fbInit = kIsWeb
      ? FacebookAuth.i.webAndDesktopInitialize(
          appId: '1813328279214129',
          cookie: true,
          xfbml: true,
          version: 'v18.0',
        )
      : Future.value();
}
