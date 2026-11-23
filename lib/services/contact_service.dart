import 'package:url_launcher/url_launcher.dart';

import '../config/shop_config.dart';
import '../core/format.dart';
import '../data/backend.dart';

/// Deep links to WhatsApp, the phone dialer and Google Maps.
class ContactService {
  const ContactService();

  Future<void> whatsapp(String phone, {String message = ''}) => _open(Uri.https(
        'wa.me',
        '/${normalisePhone(phone)}',
        message.isEmpty ? null : {'text': message},
      ));

  Future<void> whatsappShop({String message = ''}) =>
      whatsapp(ShopConfig.whatsappNumber, message: message);

  Future<void> call(String phone) =>
      _open(Uri(scheme: 'tel', path: normalisePhone(phone)));

  Future<void> openMap(double lat, double lng) => _open(Uri.https(
      'www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'}));

  Future<void> openUrl(Uri uri) => _open(uri);

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw const AppException('No app found to open this link.');
  }
}
