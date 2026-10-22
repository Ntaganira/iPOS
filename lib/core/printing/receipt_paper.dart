/**
 * <pre>
 * - Project   : iPOS - Point of Sale
 * - Package   : com.ntaganira.heritier.ipos.core.printing
 * - File      : receipt_paper.dart
 * - Date      : 2026. 10. 22.
 * - User      : NTAGANIRA H.
 * - Desc      : Supported receipt output formats. Thermal rolls use a fixed
 *               character grid (80 mm = 42 columns, 58 mm mini/mobile = 32
 *               columns); A4 is rendered as a paginated invoice through the
 *               operating system print dialog. The persisted identifier keeps
 *               the operator's last choice across restarts.
 * </pre>
 */

/// Output format selected for a receipt.
enum ReceiptPaperSize {
  a4('a4', 0),
  mm80('80mm', 42),
  mm58('58mm', 32);

  const ReceiptPaperSize(this.id, this.columns);

  /// Stable value stored in the encrypted settings registry.
  final String id;

  /// Character columns for thermal layouts; zero for paginated A4.
  final int columns;

  bool get isThermal => this != ReceiptPaperSize.a4;

  bool get isMini => this == ReceiptPaperSize.mm58;

  static ReceiptPaperSize fromId(String? raw) {
    final value = raw?.trim().toLowerCase();
    for (final paper in values) {
      if (paper.id == value) {
        return paper;
      }
    }
    return ReceiptPaperSize.mm80;
  }
}
