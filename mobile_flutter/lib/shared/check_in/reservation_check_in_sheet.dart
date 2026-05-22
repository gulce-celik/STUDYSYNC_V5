import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/checkin_api.dart';
import '../../features/reservation/domain/reservation_models.dart';
import 'check_in_window.dart';

/// Opens check-in UI and calls [CheckInApi.verify]. Feedback stays on the sheet.
Future<void> showReservationCheckInSheet({
  required BuildContext context,
  required ReservationDetail reservation,
  required VoidCallback onSuccess,
  bool allowManualQrEntry = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _ReservationCheckInSheet(
      reservation: reservation,
      onSuccess: onSuccess,
      allowManualQrEntry: allowManualQrEntry,
    ),
  );
}

class _ReservationCheckInSheet extends StatefulWidget {
  const _ReservationCheckInSheet({
    required this.reservation,
    required this.onSuccess,
    required this.allowManualQrEntry,
  });

  final ReservationDetail reservation;
  final VoidCallback onSuccess;
  final bool allowManualQrEntry;

  @override
  State<_ReservationCheckInSheet> createState() => _ReservationCheckInSheetState();
}

class _ReservationCheckInSheetState extends State<_ReservationCheckInSheet> {
  late final TextEditingController _payloadCtrl;
  bool _loading = false;
  String? _inlineMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    final preset = widget.reservation.qrPayload?.trim() ?? '';
    _payloadCtrl = TextEditingController(text: preset);
  }

  @override
  void dispose() {
    _payloadCtrl.dispose();
    super.dispose();
  }

  void _setMessage(String text, {required bool isError}) {
    setState(() {
      _inlineMessage = text;
      _isError = isError;
    });
  }

  String _resultMessage(Map<String, dynamic> body) {
    final msg = body['message']?.toString();
    if (msg != null && msg.isNotEmpty) return msg;
    final success = body['success'] == true;
    return success ? 'Check-in successful.' : 'Check-in failed.';
  }

  Future<void> _submit() async {
    if (_loading) return;

    final r = widget.reservation;
    if (!CheckInWindow.canCheckInNow(r)) {
      final hint = CheckInWindow.availabilityHint(r);
      _setMessage(
        hint ??
            'Check-in is only available from 15 minutes before until 15 minutes after your slot start.',
        isError: true,
      );
      return;
    }

    final payload = _payloadCtrl.text.trim();
    if (payload.isEmpty) {
      _setMessage('Enter your reservation QR code.', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _inlineMessage = null;
      _isError = false;
    });

    try {
      final result = await CheckInApi().verify(
        reservationId: r.id,
        qrPayload: payload,
      );
      if (!mounted) return;

      final success = result['success'] == true;
      if (!success) {
        setState(() {
          _loading = false;
          _inlineMessage = _resultMessage(result);
          _isError = true;
        });
        return;
      }

      Navigator.of(context).pop();
      widget.onSuccess();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = true;
        _inlineMessage = e.response?.data is Map && (e.response!.data as Map)['message'] != null
            ? (e.response!.data as Map)['message'].toString()
            : 'Check-in request failed. Is the backend running?';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isError = true;
        _inlineMessage = 'Check-in request failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final missingServerQr = (r.qrPayload == null || r.qrPayload!.trim().isEmpty);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'QR Check-In',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Text(
            '${r.courseCode} • ${r.workspaceId} • ${r.slotLabel}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (missingServerQr && widget.allowManualQrEntry)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Paste the QR code from your booking confirmation. '
                'If the field stays empty, ask the backend team to return qrPayload on GET /reservations/me.',
                style: TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF92400E)),
              ),
            ),
          TextField(
            controller: _payloadCtrl,
            enabled: !_loading && widget.allowManualQrEntry,
            readOnly: !widget.allowManualQrEntry && !missingServerQr,
            decoration: const InputDecoration(
              labelText: 'QR code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CheckInWindow.canCheckInNow(r)
                ? 'Enter the 4-digit desk QR. Window closes 15 minutes after slot start.'
                : (CheckInWindow.availabilityHint(r) ??
                    'Check-in opens 15 minutes before your slot start.'),
            style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xFF6B7280)),
          ),
          if (_inlineMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _inlineMessage!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isError ? const Color(0xFFDC2626) : const Color(0xFF92400E),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: (_loading || !CheckInWindow.canCheckInNow(r)) ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.qr_code_scanner_rounded, size: 20),
            label: Text(_loading ? 'Verifying…' : 'Verify check-in'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
