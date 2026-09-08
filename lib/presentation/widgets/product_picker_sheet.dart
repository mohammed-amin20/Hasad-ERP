import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../domain/products/product.dart';
import '../providers/products_providers.dart';

/// Opens a searchable bottom sheet and returns the selected [Product],
/// or null if dismissed.
Future<Product?> showProductPicker(BuildContext context) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() =>
      _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختيار منتج',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) =>
                  ref.read(productSearchProvider.notifier).update(v),
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الباركود...',
                prefixIcon: FaIcon(FontAwesomeIcons.magnifyingGlass),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: productsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
                data: (products) {
                  if (products.isEmpty) {
                    return const Center(child: Text('لا توجد منتجات'));
                  }
                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.unit} · الكمية: '
                            '${formatQty(p.qty, p.unitType)}'),
                        trailing: Text(
                          Money.format(p.salePrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}