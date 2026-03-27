import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../../shared/widgets/avishu_button.dart';

final newOrdersProvider = StreamProvider((ref) {
  return ref.watch(orderRepositoryProvider).ordersByStatus(OrderStatus.newOrder);
});

class FranchiseeDashboard extends ConsumerWidget {
  const FranchiseeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(newOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NEW ORDERS', style: TextStyle(letterSpacing: 2.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black, height: 1),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return const Center(child: Text('NO NEW ORDERS', style: TextStyle(letterSpacing: 2.0)));
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('ORDER #${order.id}'.toUpperCase()),
                trailing: AvishuButton(
                  text: 'ACCEPT', 
                  onPressed: () {
                    ref.read(orderRepositoryProvider).updateOrderStatus(order.id, OrderStatus.accepted);
                  }
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, stack) => Center(child: Text('ERROR: $err'.toUpperCase())),
      ),
    );
  }
}
