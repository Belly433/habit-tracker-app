import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'habit_service.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HabitApp());
}

class HabitApp extends StatefulWidget {
  const HabitApp({super.key});

  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.grey.shade100,
      ),
      darkTheme: ThemeData(
  brightness: Brightness.dark,

  bottomNavigationBarTheme:
      const BottomNavigationBarThemeData(
    backgroundColor: Colors.black,
    selectedItemColor: Colors.teal,
    unselectedItemColor: Colors.grey,
  ),
),

      home: MainNavigation(
        toggleTheme: toggleTheme,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback toggleTheme;

  const MainNavigation({
    super.key,
    required this.toggleTheme,
  });

  @override
  State<MainNavigation> createState() =>
      _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  final HabitService _habitService = HabitService();

  List<Map<String, dynamic>> habits = [];
  Map<String, List<String>> dailyHistory = {};
  String dailyQuote =
    "Stay positive and productive!";
  int currentStreak = 0;
  int longestStreak = 0;
  Future<void> fetchQuote() async {

  try {

    final response = await http.get(
      Uri.parse(
        'https://api.quotable.io/random',
      ),
    );

    if (response.statusCode == 200) {

      final data = jsonDecode(response.body);

      setState(() {

        dailyQuote = data['content'];

      });
    }

  } catch (e) {

    dailyQuote =
        "Stay motivated every day!";

  }
}

  @override
  void initState() {
    fetchQuote();
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    String? habitData =
    await _habitService.loadHabits();
    String? historyData = prefs.getString("history");

    if (habitData != null) {
      habits = List<Map<String, dynamic>>.from(
        jsonDecode(habitData),
      );

      for (var habit in habits) {
        habit["done"] ??= false;
      }
    }

    if (historyData != null) {
      Map<String, dynamic> decoded =
          jsonDecode(historyData);

      dailyHistory = decoded.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(value),
        ),
      );
    }
    calculateStreaks();
    setState(() {});
  }
void calculateStreaks() {
  List<String> dates = dailyHistory.keys.toList();

  dates.sort();

  int streak = 0;
  int maxStreak = 0;

  DateTime today = DateTime.now();

  String todayKey =
      DateFormat('yyyy-MM-dd').format(today);

  bool todayCompleted =
      dailyHistory[todayKey] != null &&
      dailyHistory[todayKey]!.isNotEmpty;

  
  if (!todayCompleted) {
    currentStreak = 0;
  } else {
    DateTime currentDate = today;

    while (true) {
      String key =
          DateFormat('yyyy-MM-dd')
              .format(currentDate);

      if (dailyHistory[key] != null &&
          dailyHistory[key]!.isNotEmpty) {
        streak++;

        currentDate = currentDate.subtract(
          const Duration(days: 1),
        );
      } else {
        break;
      }
    }

    currentStreak = streak;
  }

  // Longest streak
  int tempStreak = 0;
  DateTime? previousDate;

  for (String date in dates) {
    if (dailyHistory[date]!.isNotEmpty) {
      DateTime currentDate =
          DateTime.parse(date);

      if (previousDate == null) {
        tempStreak = 1;
      } else {
        int difference =
            currentDate
                .difference(previousDate)
                .inDays;

        if (difference == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
      }

      previousDate = currentDate;

      if (tempStreak > maxStreak) {
        maxStreak = tempStreak;
      }
    }
  }

  longestStreak = maxStreak;
}
  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "habits",
      jsonEncode(habits),
    );

    await prefs.setString(
      "history",
      jsonEncode(dailyHistory),
    );
  }

  void addHabit(String name, String category) {
  habits.add({
    "name": name,
    "category": category,
    "done": false,
  });

  saveData();
  setState(() {});
}

  void deleteHabit(int index) {
    habits.removeAt(index);
    saveData();
    setState(() {});
  }

  void toggleHabit(int index) {
    String today =
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    habits[index]["done"] =
        !(habits[index]["done"] ?? false);

    String habitName = habits[index]["name"];

    dailyHistory.putIfAbsent(today, () => []);

    if (habits[index]["done"]) {
      if (!dailyHistory[today]!.contains(habitName)) {
        dailyHistory[today]!.add(habitName);
      }
    } else {
      dailyHistory[today]!.remove(habitName);
    }

    calculateStreaks();
    double progress = getProgress();

if (progress == 1.0) {
  Future.delayed(
    const Duration(milliseconds: 300),
    () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
  backgroundColor: Colors.teal,

  behavior: SnackBarBehavior.floating,

  shape: RoundedRectangleBorder(
    borderRadius:
        BorderRadius.circular(15),
  ),

  content: const Text("🎉 Completed!"),
),
      );
    },
  );
}

saveData();

setState(() {});
  }

  double getProgress() {
    if (habits.isEmpty) return 0;

    int completed = habits
        .where((habit) => habit["done"] == true)
        .length;

    return completed / habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(
        habits: habits,
        dailyHistory: dailyHistory,
        dailyQuote: dailyQuote,
        toggleHabit: toggleHabit,
        progress: getProgress(),
        toggleTheme: widget.toggleTheme,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
      ),

      AllHabitsScreen(
        habits: habits,
        addHabit: addHabit,
        deleteHabit: deleteHabit,
      ),

      HistoryScreen(
        dailyHistory: dailyHistory,
      ),
      StatisticsScreen(
  habits: habits,
  dailyHistory: dailyHistory,
  currentStreak: currentStreak,
  longestStreak: longestStreak,
),
    ];

    return Scaffold(
      body: screens[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.teal,
        backgroundColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: "Today",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: "Habits",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),
          BottomNavigationBarItem(
  icon: Icon(Icons.bar_chart),
  label: "Stats",
),
        ],
      ),
    );
  }
}

class TodayScreen extends StatefulWidget {
  final List<Map<String, dynamic>> habits;
  final Map<String, List<String>> dailyHistory;
  final Function(int) toggleHabit;
  final double progress;
  final VoidCallback toggleTheme;
  final int currentStreak;
  final int longestStreak;
  final String dailyQuote;

  const TodayScreen({
    super.key,
    required this.habits,
    required this.dailyHistory,
    required this.toggleHabit,
    required this.progress,
    required this.toggleTheme,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyQuote,
  });

  @override
  State<TodayScreen> createState() =>
      _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String selectedDate =
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    bool isToday =
        selectedDate ==
            DateFormat('yyyy-MM-dd')
                .format(DateTime.now());

    List<String> selectedTasks =
        widget.dailyHistory[selectedDate] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Daily Goals"),
        actions: [
          IconButton(
            onPressed: widget.toggleTheme,
            icon: const Icon(Icons.dark_mode),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
                  if (widget.progress == 1.0)

            Padding(
  padding: const EdgeInsets.only(bottom: 16),

  child: Card(
    color: Colors.teal.shade100,

    child: Padding(
      padding: const EdgeInsets.all(16),

      child: Column(
        children: [

          const Text(
            "Daily Motivation",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            widget.dailyQuote,
            textAlign: TextAlign.center,
            style: const TextStyle(
  color: Colors.black,
  fontWeight: FontWeight.w500,
),
          ),
        ],
      ),
    ),
  ),
),
            Text(
              "${(widget.progress * 100).toInt()}% Completed Today",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            LinearProgressIndicator(
              value: widget.progress,
              minHeight: 15,
              color: Colors.teal,
              backgroundColor: Colors.grey,
            ),
            const SizedBox(height: 16),

Text(
  "Current Streak: ${widget.currentStreak} days",
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 8),

Text(
  "Longest Streak: ${widget.longestStreak} days",
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 20),

            const SizedBox(height: 20),

            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  
                  DateTime today = DateTime.now();

                  DateTime day = today
                      .subtract(
                        Duration(
                          days: today.weekday - 1,
                        ),
                      )
                      .add(
                        Duration(days: index),
                      );

                  String label =
                      DateFormat('EEE').format(day);

                  String dateKey =
                      DateFormat('yyyy-MM-dd')
                          .format(day);

                  bool selected =
                      selectedDate == dateKey;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDate = dateKey;
                      });
                    },
                    child: Container(
                      width: 60,
                      margin:
                          const EdgeInsets.symmetric(
                              horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.teal
                            : Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: isToday
                  ? ListView.builder(
                      itemCount:
                          widget.habits.length,
                      itemBuilder:
                          (context, index) {
                            Color categoryColor = Colors.teal;

String category =
    widget.habits[index]["category"] ??
    "Health";

if (category == "Study") {
  categoryColor = Colors.blue;
} else if (category == "Productivity") {
  categoryColor = Colors.orange;
} else if (category == "Personal") {
  categoryColor = Colors.purple;
}
                            return AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  margin: const EdgeInsets.only(bottom: 12),

  decoration: BoxDecoration(
    color: widget.habits[index]["done"]
        ? Colors.teal.withValues(alpha: 0.15)
        : Theme.of(context).cardColor,

    borderRadius: BorderRadius.circular(18),

    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 6,
        offset: const Offset(0, 3),
      ),
    ],

    border: Border.all(
      color: widget.habits[index]["done"]
          ? Colors.teal
          : Colors.transparent,
      width: 1.5,
    ),
  ),

  child: ListTile(
    leading: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),

      child: Checkbox(
        key: ValueKey(
          widget.habits[index]["done"],
        ),

        activeColor: Colors.teal,

        value:
            widget.habits[index]["done"] ?? false,

        onChanged: (_) {
          widget.toggleHabit(index);

setState(() {});

int completedHabits =
    widget.habits
        .where(
          (habit) => habit["done"] == true,
        )
        .length;

if (completedHabits ==
    widget.habits.length) {
  ScaffoldMessenger.of(context)
      .hideCurrentSnackBar();

  ScaffoldMessenger.of(context)
      .showSnackBar(
    SnackBar(
      backgroundColor: Colors.teal,

      behavior: SnackBarBehavior.floating,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(15),
      ),

      content: const Text(
        "🎉 Congratulations! All habits completed!",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  );
};
        },
      ),
    ),

    title: AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),

      style: TextStyle(
        fontSize: 16,

        fontWeight:
            widget.habits[index]["done"]
                ? FontWeight.bold
                : FontWeight.w500,

        color:
            widget.habits[index]["done"]
                ? categoryColor
                : Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .color,
      ),

      child: Text(
        widget.habits[index]["name"],
      ),
    ),
  ),
);
                        
                      },
                    )
                  : selectedTasks.isEmpty
                      ? Center(
                          child: Text(
                            DateTime.parse(
                                        selectedDate)
                                    .isAfter(
                                        DateTime.now())
                                ? "No tasks completed yet"
                                : "No tasks completed",
                          ),
                        )
                      : ListView(
                          children: selectedTasks
                              .map(
                                (task) =>
                                    ListTile(
                                  leading:
                                      const Icon(
                                    Icons
                                        .check_circle,
                                    color:
                                        Colors
                                            .green,
                                  ),
                                  title:
                                      Text(task),
                                ),
                              )
                              .toList(),
                        ),
            )
          ],
        ),
      ),
    );
  }
}

class AllHabitsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> habits;
  final Function(String, String) addHabit;
  final Function(int) deleteHabit;

  const AllHabitsScreen({
    super.key,
    required this.habits,
    required this.addHabit,
    required this.deleteHabit,
  });

  void showAddDialog(BuildContext context) {

    TextEditingController controller =
        TextEditingController();

    bool showError = false;
    String selectedCategory = "Health";

List<String> categories = [
  "Health",
  "Study",
  "Productivity",
  "Personal",
];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title:
                  const Text("Add New Habit"),
              content: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TextField(
      controller: controller,

      onChanged: (value) {
        if (value.trim().isNotEmpty &&
            showError) {
          setStateDialog(() {
            showError = false;
          });
        }
      },

      decoration: InputDecoration(
        hintText:
            showError
                ? null
                : "Enter habit name",

        errorText:
            showError
                ? "Please enter a habit name"
                : null,

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),

          borderSide: const BorderSide(
          color: Colors.teal,
            width: 2,
          ),
        ),
      ),
    ),

    const SizedBox(height: 15),

    DropdownButtonFormField<String>(
      value: selectedCategory,

      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),

      items:
          categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Text(category),
        );
      }).toList(),

      onChanged: (value) {
        setStateDialog(() {
          selectedCategory = value!;
        });
      },
    ),
  ],
),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (controller.text
                        .trim()
                        .isEmpty) {
                      setStateDialog(() {
                        showError = true;
                      });
                      return;
                    }

                    addHabit(
  controller.text.trim(),
  selectedCategory,
);

                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Habits"),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: habits.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(
                habits[index]["name"],
              ),
              trailing: IconButton(
                icon: const Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                onPressed: () {
                  deleteHabit(index);
                },
              ),
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          showAddDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final Map<String, List<String>> dailyHistory;

  const HistoryScreen({
    super.key,
    required this.dailyHistory,
  });

  @override
  State<HistoryScreen> createState() =>
      _HistoryScreenState();
}
class StatisticsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> habits;
  final Map<String, List<String>> dailyHistory;
  final int currentStreak;
  final int longestStreak;

  const StatisticsScreen({
    super.key,
    required this.habits,
    required this.dailyHistory,
    required this.currentStreak,
    required this.longestStreak,
  });

  int getTotalCompleted() {
    int total = 0;

    for (var day in dailyHistory.values) {
      total += day.length;
    }

    return total;
  }

  int getActiveDays() {
    return dailyHistory.values
        .where((day) => day.isNotEmpty)
        .length;
  }

  double getCompletionRate() {
    if (habits.isEmpty) return 0;

    int completed = habits
        .where((habit) => habit["done"] == true)
        .length;

    return (completed / habits.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: ListView(
          children: [

            buildStatCard(
              "Total Habits Completed",
              "${getTotalCompleted()}",
              Icons.check_circle,
              Colors.green,
            ),

            const SizedBox(height: 15),

            buildStatCard(
              "Completion Rate",
              "${getCompletionRate().toInt()}%",
              Icons.bar_chart,
              Colors.teal,
            ),

            const SizedBox(height: 15),

            buildStatCard(
              "Current Streak",
              "$currentStreak days",
              Icons.local_fire_department,
              Colors.orange,
            ),

            const SizedBox(height: 15),

            buildStatCard(
              "Longest Streak",
              "$longestStreak days",
              Icons.emoji_events,
              Colors.purple,
            ),

            const SizedBox(height: 15),

            buildStatCard(
              "Active Days",
              "${getActiveDays()}",
              Icons.calendar_month,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: color.withOpacity(0.15),

        borderRadius:
            BorderRadius.circular(20),

        border: Border.all(
          color: color,
          width: 2,
        ),
      ),

      child: Row(
        children: [

          CircleAvatar(
            radius: 28,
            backgroundColor: color,

            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryScreenState
    extends State<HistoryScreen> {
  String selectedDate =
      DateFormat('yyyy-MM-dd')
          .format(DateTime.now());

  void pickDate() async {
    DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate =
            DateFormat('yyyy-MM-dd')
                .format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> tasks =
        widget.dailyHistory[selectedDate] ?? [];

    bool isFuture =
        DateTime.parse(selectedDate)
            .isAfter(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        actions: [
          IconButton(
            onPressed: pickDate,
            icon: const Icon(
              Icons.calendar_month,
            ),
          )
        ],
      ),

      body: tasks.isEmpty
          ? Center(
              child: Text(
                isFuture
                    ? "No tasks completed yet"
                    : "No tasks completed",
              ),
            )
          : ListView(
              children: tasks.map((task) {
                return ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  title: Text(task),
                );
              }).toList(),
            ),
    );
  }
}