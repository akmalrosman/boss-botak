/// On/off switches for optional modules.
///
/// For the progress presentation only the core flow is shown:
/// customer shopping + checkout (DuitNow QR / FPX), and the owner's
/// dashboard, orders and inventory. The other modules are fully built and
/// can be switched back on for the final submission by setting them to true.
class Features {
  Features._();

  /// Owner: expense tracking tab (also adds expenses to the profit & loss).
  static const bool expenses = false;

  /// Owner: customer database tab.
  static const bool customers = false;

  /// Owner: record WhatsApp / walk-in sales on behalf of a customer.
  static const bool recordSale = false;
}
