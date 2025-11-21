import 'package:flutter/material.dart';

/// Stub para mobile_scanner quando compilado para web
/// Este arquivo substitui o mobile_scanner que não funciona na web

class MobileScannerController {
  MobileScannerController();

  Future<void> dispose() async {}

  Future<void> toggleTorch() async {
    throw UnsupportedError('Scanner não disponível na web');
  }

  Future<void> switchCamera() async {
    throw UnsupportedError('Scanner não disponível na web');
  }
}

class MobileScanner extends StatelessWidget {
  const MobileScanner({
    super.key,
    required this.controller,
    this.fit,
    this.onDetect,
  });

  final MobileScannerController controller;
  final BoxFit? fit;
  final Function(BarcodeCapture)? onDetect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Scanner não disponível na web',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

class BarcodeCapture {
  final List<Barcode> barcodes;
  BarcodeCapture(this.barcodes);
}

class Barcode {
  final String? rawValue;
  Barcode(this.rawValue);
}
