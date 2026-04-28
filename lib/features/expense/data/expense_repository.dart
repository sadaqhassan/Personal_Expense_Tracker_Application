import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/expense_model.dart';
import '../../auth/data/auth_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Initialized in main.dart
});

final expenseRepositoryProvider = Provider((ref) {
  return ExpenseRepository(
    Supabase.instance.client,
    ref.watch(sharedPreferencesProvider),
    ref.watch(authRepositoryProvider),
  );
});

class ExpenseRepository {
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  final AuthRepository _authRepo;
  static const String _cacheKey = 'cached_expenses';

  ExpenseRepository(this._supabase, this._prefs, this._authRepo);

  String get _userId {
    final user = _authRepo.currentUser;
    if (user == null) throw 'User not logged in';
    return user.id;
  }

  Future<List<Expense>> getExpenses() async {
    try {
      final response = await _supabase
          .from('expenses')
          .select()
          .eq('user_id', _userId)
          .order('date', ascending: false);

      final expenses = (response as List).map((e) => Expense.fromJson(e)).toList();
      
      // Cache expenses locally
      _cacheExpenses(expenses);
      
      return expenses;
    } catch (e) {
      // Fallback to local cache if offline
      return _getCachedExpenses();
    }
  }

  Future<Expense> addExpense(Expense expense) async {
    try {
      final response = await _supabase
          .from('expenses')
          .insert(expense.toJson())
          .select()
          .single();
      
      return Expense.fromJson(response);
    } catch (e) {
      throw 'Failed to add expense. Please check your connection.';
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
    } catch (e) {
      throw 'Failed to delete expense.';
    }
  }

  // Local Caching logic
  void _cacheExpenses(List<Expense> expenses) {
    final List<String> encodedList = expenses.map((e) {
      final json = e.toJson();
      json['id'] = e.id;
      json['created_at'] = e.createdAt.toIso8601String();
      return jsonEncode(json);
    }).toList();
    _prefs.setStringList(_cacheKey, encodedList);
  }

  List<Expense> _getCachedExpenses() {
    final List<String>? cachedList = _prefs.getStringList(_cacheKey);
    if (cachedList == null) return [];
    
    return cachedList.map((e) {
      final json = jsonDecode(e);
      return Expense.fromJson(json);
    }).toList();
  }
}
