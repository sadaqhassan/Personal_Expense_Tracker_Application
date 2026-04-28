import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/expense_repository.dart';
import '../domain/expense_model.dart';

final expensesProvider = AsyncNotifierProvider<ExpenseController, List<Expense>>(() {
  return ExpenseController();
});

final totalExpenseProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? [];
  return expenses.fold(0.0, (sum, item) => sum + item.amount);
});

final expensesByCategoryProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(expensesProvider).value ?? [];
  final map = <String, double>{};
  for (var expense in expenses) {
    map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
  }
  return map;
});

class ExpenseController extends AsyncNotifier<List<Expense>> {
  late ExpenseRepository _repository;

  @override
  Future<List<Expense>> build() async {
    _repository = ref.watch(expenseRepositoryProvider);
    return _repository.getExpenses();
  }

  Future<void> fetchExpenses() async {
    state = const AsyncValue.loading();
    try {
      final expenses = await _repository.getExpenses();
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addExpense(String title, double amount, DateTime date, String category, String userId) async {
    try {
      final newExpense = Expense(
        id: '', // Supabase will generate this
        title: title,
        amount: amount,
        date: date,
        category: category,
        userId: userId,
        createdAt: DateTime.now(), // Supabase will override this
      );
      
      final created = await _repository.addExpense(newExpense);
      
      // Update state
      if (state.value != null) {
        state = AsyncValue.data([created, ...state.value!]);
      } else {
        state = AsyncValue.data([created]);
      }
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _repository.deleteExpense(id);
      
      // Update state
      if (state.value != null) {
        state = AsyncValue.data(
          state.value!.where((e) => e.id != id).toList()
        );
      }
    } catch (e) {
      throw e.toString();
    }
  }
}
