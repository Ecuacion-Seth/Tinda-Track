import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/item.dart';
import 'add_item_screen.dart';
import 'edit_item_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> _items = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final itemsData = await DatabaseHelper.instance.getAllItems();
    final catsData = await DatabaseHelper.instance.getCategories();
    
    setState(() {
      _items = itemsData.map((map) => Item.fromMap(map)).toList();
      _categories = [{'id': 'All', 'name': 'All'}];
      _categories.addAll(catsData);
      _isLoading = false;
    });
  }

  List<Item> get _filteredItems {
    return _items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategoryFilter == 'All' || item.categoryId == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _showQuickRestockDialog(Item item) async {
    final qtyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add', 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_box),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              final int addedQty = int.tryParse(qtyController.text) ?? 0;
              
              // FIXED: Explicit error handling for 0 or empty input
              if (addedQty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.red),
                );
                return;
              }

              final updatedItem = item.copyWith(quantity: item.quantity + addedQty);
              await DatabaseHelper.instance.updateItem(updatedItem.toMap());
              
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $addedQty to ${item.name}'), backgroundColor: Colors.green),
                );
                _refreshData();
              }
            },
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search items...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: _categories.map((cat) {
                      final isSelected = _selectedCategoryFilter == cat['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          label: Text(cat['name']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategoryFilter = cat['id'];
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ? 'No matches found' : 'Your inventory is empty',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ? 'Try a different search term' : 'Tap the + button to add products',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isLowStock = item.quantity <= item.lowStockThreshold;

                            return Dismissible(
                              key: Key(item.id),
                              direction: DismissDirection.horizontal,
                              background: Container(
                                color: Colors.green,
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_box, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('RESTOCK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                  ],
                                ),
                              ),
                              secondaryBackground: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  return await showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Item'),
                                      content: Text('Are you sure you want to delete ${item.name}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true), 
                                          child: const Text('Delete', style: TextStyle(color: Colors.red))
                                        ),
                                      ],
                                    ),
                                  );
                                } else if (direction == DismissDirection.startToEnd) {
                                  await _showQuickRestockDialog(item);
                                  return false; 
                                }
                                return false;
                              },
                              onDismissed: (direction) async {
                                if (direction == DismissDirection.endToStart) {
                                  setState(() {
                                    _items.removeWhere((i) => i.id == item.id);
                                  });
                                  await DatabaseHelper.instance.deleteItem(item.id);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('${item.name} deleted')),
                                    );
                                  }
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: const Icon(Icons.inventory_2),
                                  ),
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('₱${item.price.toStringAsFixed(2)}'),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Qty: ${item.quantity}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                          color: isLowStock ? Colors.red : null,
                                        ),
                                      ),
                                      if (isLowStock)
                                        const Text('Low Stock', style: TextStyle(color: Colors.red, fontSize: 10)),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => EditItemScreen(item: item)),
                                    );
                                    _refreshData();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemScreen()),
          );
          _refreshData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}