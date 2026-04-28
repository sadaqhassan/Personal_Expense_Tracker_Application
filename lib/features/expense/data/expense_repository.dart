import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/expense_model.dart';
import '../../auth/data/auth_repository.dart';

/// 🔹 SharedPreferences Provider (override in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// 🔹 Repository Provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    supabase: Supabase.instance.client,
    prefs: ref.watch(sharedPreferencesProvider),
    authRepo: ref.watch(authRepositoryProvider),
  );
});

/// 🔹 Custom Exception
class ExpenseException implements Exception {
  final String message;
  ExpenseException(this.message);

  @override
  String toString() => message;
}

class ExpenseRepository {
  final SupabaseClient supabase;
  final SharedPreferences prefs;
  final AuthRepository authRepo;

  static const String _cacheKey = 'cached_expenses';

  ExpenseRepository({
    required this.supabase,
    required this.prefs,
    required this.authRepo,
  });

  /// 🔐 Get current user id
  String get _userId {
    final user = authRepo.currentUser;
    if (user == null) {
      throw ExpenseException('User not authenticated');
    }
    return user.id;
  }

  /// 📥 Get expenses (API + cache fallback)
  Future<List<Expense>> getExpenses() async {
    try {
      final response = await supabase
          .from('expenses')
          .select()
          .eq('user_id', _userId)
          .order('date', ascending: false);

      final expenses = (response as List)
          .map((e) => Expense.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      await _cacheExpenses(expenses);

      return expenses;
    } catch (e, stack) {
      debugPrint('❌ getExpenses error: $e');
      debugPrintStack(stackTrace: stack);

      final cached = _getCachedExpenses();
      if (cached.isNotEmpty) return cached;

      throw ExpenseException('Failed to fetch expenses');
    }
  }

  /// ➕ Add expense
  Future<Expense> addExpense(Expense expense) async {
    try {
      final data = expense.toJson()..['user_id'] = _userId;

      final response = await supabase
          .from('expenses')
          .insert(data)
          .select()
          .single();

      final newExpense = Expense.fromJson(Map<String, dynamic>.from(response));

      /// update cache
      final current = _getCachedExpenses();
      final updated = [newExpense, ...current];
      await _cacheExpenses(updated);

      return newExpense;
    } catch (e) {
      debugPrint('❌ addExpense error: $e');
      throw ExpenseException('Failed to add expense');
    }
  }

  /// 🗑️ Delete expense
  Future<void> deleteExpense(String id) async {
    try {
      await supabase.from('expenses').delete().eq('id', id);

      /// update cache
      final current = _getCachedExpenses();
      final updated = current.where((e) => e.id != id).toList();
      await _cacheExpenses(updated);
    } catch (e) {
      debugPrint('❌ deleteExpense error: $e');
      throw ExpenseException('Failed to delete expense');
    }
  }

  /// ✏️ Update expense
  Future<Expense> updateExpense(Expense expense) async {
    try {
      final data = expense.toJson()..['user_id'] = _userId;

      final response = await supabase
          .from('expenses')
          .update(data)
          .eq('id', expense.id)
          .select()
          .single();

      final updatedExpense = Expense.fromJson(
        Map<String, dynamic>.from(response),
      );

      /// update cache
      final current = _getCachedExpenses();
      final updatedList = current.map((e) {
        return e.id == expense.id ? updatedExpense : e;
      }).toList();

      await _cacheExpenses(updatedList);

      return updatedExpense;
    } catch (e) {
      debugPrint('❌ updateExpense error: $e');
      throw ExpenseException('Failed to update expense');
    }
  }

  /// 💾 Cache expenses
  Future<void> _cacheExpenses(List<Expense> expenses) async {
    try {
      final encoded = expenses.map((e) {
        final json = e.toJson()
          ..['id'] = e.id
          ..['created_at'] = e.createdAt.toIso8601String();
        return jsonEncode(json);
      }).toList();

      await prefs.setStringList(_cacheKey, encoded);
    } catch (e) {
      debugPrint('⚠️ Cache error: $e');
    }
  }

  /// 📦 Get cached expenses
  List<Expense> _getCachedExpenses() {
    try {
      final cachedList = prefs.getStringList(_cacheKey);
      if (cachedList == null) return [];

      return cachedList.map((e) {
        final json = jsonDecode(e) as Map<String, dynamic>;
        return Expense.fromJson(json);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Cache read error: $e');
      return [];
    }
  }
}
