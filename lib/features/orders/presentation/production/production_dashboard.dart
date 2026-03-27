import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';
import '../../../../shared/widgets/avishu_button.dart';

final productionOrdersProvider = StreamProvider((ref) {
  return ref.watch(orderRepositoryProvider).ordersByStatus(OrderStatus.inProduction);
});

class ProductionDashboard extends ConsumerWidget {
  const ProductionDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(productionOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PRODUCTION TASKS', style: TextStyle(letterSpacing: 2.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black, height: 1),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return const Center(child: Text('NO ACTIVE TASKS', style: TextStyle(letterSpacing: 2.0)));
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                title: Text('ORDER #${order.id}'.toUpperCase()),
                trailing: AvishuButton(
                  text: 'ЗАВЕРШИТЬ', 
                  onPressed: () {
                    ref.read(orderRepositoryProvider).updateOrderStatus(order.id, order.shiftToNextState().status);
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
