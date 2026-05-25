import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/database_helper.dart';
import '../models/item.dart';

class EditItemScreen extends StatefulWidget {
  final Item item;
  const EditItemScreen({super.key, required this.item});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;
  late final TextEditingController _barcodeController;
  
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _priceController = TextEditingController(text: widget.item.price.toStringAsFixed(2));
    _qtyController = TextEditingController(text: widget.item.quantity.toString());
    _barcodeController = TextEditingController(text: widget.item.barcode ?? '');
    _selectedCategory = widget.item.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await DatabaseHelper.instance.getCategories();
    setState(() {
      _categories = cats;
      _isLoading = false;
    });
  }

  Future<void> _scanBarcodeForEdit() async {
    // FIXED: Controller explicitly created so it can be disposed
    final scanController = MobileScannerController(); 
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          // FIXED: Replaced Scaffold with Column to prevent visual flashing on Android
          child: Column(
            children: [
              AppBar(
                title: const Text('Scan Barcode'),
                leading: IconButton(
                  icon: const Icon(Icons.close), 
                  onPressed: () {
                    scanController.dispose(); // FIXED: Dispose on manual close
                    Navigator.pop(ctx);
                  }
                ),
              ),
              Expanded(
                child: MobileScanner(
                  controller: scanController,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                      setState(() {
                        _barcodeController.text = barcodes.first.rawValue!;
                      });
                      scanController.dispose(); // FIXED: Dispose on successful scan
                      Navigator.pop(ctx); 
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateItem() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final updatedItem = widget.item.copyWith(
        name: _nameController.text.trim(),
        categoryId: _selectedCategory!,
        price: double.tryParse(_priceController.text) ?? 0.0,
        quantity: int.tryParse(_qtyController.text) ?? 0,
        barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await DatabaseHelper.instance.updateItem(updatedItem.toMap());
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Item')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'],
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(labelText: 'Price (₱)', border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (double.tryParse(val) == null) return 'Must be a number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        if (int.tryParse(val) == null) return 'Must be an integer';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode', 
                  border: const OutlineInputBorder(),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
                      onPressed: _scanBarcodeForEdit,
                      tooltip: 'Scan Barcode',
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber.shade600,
                  foregroundColor: Colors.black87,
                ),
                onPressed: _updateItem,
                child: const Text('UPDATE ITEM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}