import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 扫码页面：扫描到内容后 `Navigator.pop(context, text)` 返回。
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.title = '扫码'});

  final String title;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _returned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned) return;
    final barcode = capture.barcodes.firstWhere(
      (b) => (b.rawValue ?? '').isNotEmpty,
      orElse: () => const Barcode(rawValue: null),
    );
    final text = barcode.rawValue;
    if (text == null || text.isEmpty) return;
    _returned = true;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: '闪光灯',
                onPressed: unavailable ? null : _controller.toggleTorch,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
              );
            },
          ),
          IconButton(
            tooltip: '切换摄像头',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
      ),
    );
  }
}

