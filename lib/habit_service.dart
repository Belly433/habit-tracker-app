import 'package:shared_preferences/shared_preferences.dart';

class HabitService {

  Future<void> saveCompletedHabits(
      List<String> completedHabits) async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'completedHabits',
      completedHabits,
    );
  }

  Future<List<String>> loadCompletedHabits() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(
          'completedHabits',
        ) ??
        [];
  }
  Future<String?> loadHabits() async {

  final prefs =
      await SharedPreferences.getInstance();

  return prefs.getString('habits');
}
  
}
