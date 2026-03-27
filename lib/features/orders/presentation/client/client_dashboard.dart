import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/global_state.dart';
import '../../../orders/data/order_repository.dart';
import '../../../orders/domain/enums/order_status.dart';

final clientOrdersProvider = StreamProvider.family((ref, String clientId) {
  return ref.watch(orderRepositoryProvider).clientOrders(clientId);
});

class ClientDashboard extends ConsumerWidget {
  const ClientDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    final ordersAsync = ref.watch(clientOrdersProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('MY ORDERS', style: TextStyle(letterSpacing: 2.0)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black, height: 1),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) return const Center(child: Text('NO ORDERS YET', style: TextStyle(letterSpacing: 2.0)));
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.black, height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text('ORDER #${order.id}'.toUpperCase()),
                subtitle: Text('STATUS: ${order.status.value}'.toUpperCase()),
                trailing: order.status == OrderStatus.ready 
                    ? const Icon(Icons.check, color: Colors.black) 
                    : const SizedBox.shrink(),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, stack) => Center(child: Text('ERROR: $err'.toUpperCase())),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Placeholder for adding a new order
        },
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
