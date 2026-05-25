import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import 'add_item_screen.dart';

class CartItem {
  final Item item;
  int cartQuantity;

  CartItem({required this.item, this.cartQuantity = 1});
  double get total => item.price * cartQuantity;
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
  );
  
  bool _isProcessing = false; 
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;

  final List<CartItem> _cart = [];

  double get _cartTotal => _cart.fold(0, (sum, current) => sum + current.total);

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(String barcode) async {
    final now = DateTime.now();
    if (_lastScannedBarcode == barcode && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return; 
    }

    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    final itemData = await DatabaseHelper.instance.getItemByBarcode(barcode);

    if (!mounted) return;

    if (itemData != null) {
      final item = Item.fromMap(itemData);
      HapticFeedback.mediumImpact();

      setState(() {
        final existingIndex = _cart.indexWhere((c) => c.item.id == item.id);
        if (existingIndex >= 0) {
          final existing = _cart[existingIndex];
          // Fix: Ensure we don't oversell stock
          if (existing.cartQuantity < existing.item.quantity) {
            existing.cartQuantity++;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Not enough stock for ${item.name}')),
            );
          }
        } else {
          // Fix: Ensure we have at least 1 in stock to add to cart
          if (item.quantity > 0) {
            _cart.add(CartItem(item: item));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${item.name} is out of stock!')),
            );
          }
        }
      });
    } else {
      _scannerController.stop();
      await _showUnknownBarcodeDialog(barcode);
      // Fix: Check mounted before restarting scanner
      if (mounted) _scannerController.start();
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _showUnknownBarcodeDialog(String barcode) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Item Not Found'),
        content: Text('The barcode $barcode is not in your inventory. Add it now?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddItemScreen(initialBarcode: barcode)),
              );
            },
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCheckoutDialog() async {
    if (_cart.isEmpty) return;

    final cashController = TextEditingController();
    final parentContext = context;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final cashReceived = double.tryParse(cashController.text) ?? 0.0;
            final change = cashReceived - _cartTotal;
            final hasEnoughCash = cashReceived >= _cartTotal;

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Checkout', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const Text('TOTAL DUE', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                        Text('₱${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(
                      labelText: 'Cash Received (₱)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.payments),
                    ),
                    onChanged: (val) => setModalState(() {}),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change:', style: TextStyle(fontSize: 20)),
                      Text(
                        // Fix: Display clean neutral colors when cash is zero
                        cashReceived == 0 ? '₱0.00' : '₱${change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: cashReceived == 0 ? Colors.grey : (hasEnoughCash ? Colors.blue : Colors.red)
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: hasEnoughCash ? () async {
                      // Fix: Wrapped everything inside a single DB Transaction for safety
                      final ops = _cart.map((cartItem) => {
                        'itemMap': cartItem.item.copyWith(
                          quantity: cartItem.item.quantity - cartItem.cartQuantity
                        ).toMap(),
                        'saleMap': {
                          'id': const Uuid().v4(),
                          'item_id': cartItem.item.id,
                          'quantity_sold': cartItem.cartQuantity,
                          'total_price': cartItem.total,
                          'sold_at': DateTime.now().toIso8601String(),
                        }
                      }).toList();

                      await DatabaseHelper.instance.processCheckout(ops);

                      setState(() => _cart.clear());
                      Navigator.pop(ctx);
                      
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('Transaction Complete!'), backgroundColor: Colors.green),
                        );
                      }
                    } : null,
                    child: const Text('CONFIRM SALE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      _handleBarcode(barcodes.first.rawValue!);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Text('CURRENT RECEIPT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  
                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Text('Scan items to add to receipt', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                          )
                        : ListView.separated(
                            itemCount: _cart.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final cItem = _cart[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.amber.shade100,
                                  child: Text('${cItem.cartQuantity}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                ),
                                title: Text(cItem.item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('@ ₱${cItem.item.price.toStringAsFixed(2)} each'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('₱${cItem.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() => _cart.removeAt(index));
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      // Fix: Theme-aware shadow
                      boxShadow: [BoxShadow(color: Theme.of(context).shadowColor.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total', style: TextStyle(color: Colors.grey)),
                                Text('₱${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade600,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('CHECKOUT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            onPressed: _cart.isNotEmpty ? _showCheckoutDialog : null,
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}