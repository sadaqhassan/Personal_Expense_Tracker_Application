import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils.dart';
import '../../../core/theme.dart';
import '../../auth/presentation/auth_controller.dart';
import 'expense_controller.dart';
import 'add_expense_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesState = ref.watch(expensesProvider);
    final totalExpense = ref.watch(totalExpenseProvider);
    final expensesByCategory = ref.watch(expensesByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(expensesProvider.notifier).fetchExpenses(),
        child: expensesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $error'),
                ElevatedButton(
                  onPressed: () => ref.read(expensesProvider.notifier).fetchExpenses(),
                  child: const Text('Retry'),
                )
              ],
            ),
          ),
          data: (expenses) {
            if (expenses.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No expenses yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Total Expense Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.softShadows,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Expenses',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppUtils.formatCurrency(totalExpense),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Pie Chart
                if (expensesByCategory.isNotEmpty) ...[
                  const Text(
                    'Expenses by Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: expensesByCategory.entries.map((e) {
                          final color = _getColorForCategory(e.key);
                          return PieChartSectionData(
                            color: color,
                            value: e.value,
                            title: '\$${e.value.toStringAsFixed(0)}',
                            radius: 50,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  // Legend
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: expensesByCategory.entries.map((e) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: _getColorForCategory(e.key),
                          ),
                          const SizedBox(width: 4),
                          Text('${e.key} (${(e.value / totalExpense * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],

                // Recent Transactions
                const Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorForCategory(expense.category).withAlpha(51), // ~0.2 opacity
                          child: Icon(
                            _getIconForCategory(expense.category),
                            color: _getColorForCategory(expense.category),
                          ),
                        ),
                        title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(AppUtils.formatDate(expense.date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppUtils.formatCurrency(expense.amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.errorColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () {
                                ref.read(expensesProvider.notifier).deleteExpense(expense.id);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Food & Dining': return Colors.orange;
      case 'Transportation': return Colors.blue;
      case 'Shopping': return Colors.purple;
      case 'Entertainment': return Colors.pink;
      case 'Bills & Utilities': return Colors.teal;
      case 'Health': return Colors.red;
      case 'Travel': return Colors.indigo;
      case 'Education': return Colors.amber;
      default: return Colors.grey;
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Food & Dining': return Icons.restaurant;
      case 'Transportation': return Icons.directions_car;
      case 'Shopping': return Icons.shopping_bag;
      case 'Entertainment': return Icons.movie;
      case 'Bills & Utilities': return Icons.bolt;
      case 'Health': return Icons.medical_services;
      case 'Travel': return Icons.flight;
      case 'Education': return Icons.school;
      default: return Icons.category;
    }
  }
}
