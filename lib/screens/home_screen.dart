import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- STATE VARIABLES ---
  String _searchQuery = "";
  String _activeDateFilter = "All";
  String _activeCategoryFilter = "All";
  final TextEditingController _searchController = TextEditingController();
  final List<String> _categories = [
    "All",
    "Food",
    "Transport",
    "Shopping",
    "Bills",
  ];

  // --- PDF EXPORT LOGIC ---
  Future<void> _exportToPDF(List<ExpenseModel> expenses) async {
    try {
      final pdf = pw.Document();
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Xpenza - Expense Report",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Date', 'Title', 'Category', 'Amount'],
                  ...expenses.map(
                    (e) => [
                      DateFormat('dd/MM/yyyy').format(e.date),
                      e.title,
                      e.category,
                      'INR ${e.amount.toStringAsFixed(2)}',
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      // Wait for the print/save dialog to finish
      final bool result = await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Xpenza_Report_${DateFormat('MMM_yyyy').format(DateTime.now())}',
      );

      // If the user didn't cancel, show the SnackBar
      if (result && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("PDF Saved Successfully!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save PDF"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- DATA LOGIC ---
  double _getBudget() {
    final settingsBox = Hive.box('settings');
    return settingsBox.get('monthlyLimit', defaultValue: 5000.0);
  }

  bool _isWithinDateFilter(DateTime date) {
    final now = DateTime.now();
    if (_activeDateFilter == "Today") {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    } else if (_activeDateFilter == "Week") {
      final weekAgo = now.subtract(const Duration(days: 7));
      return date.isAfter(weekAgo);
    } else if (_activeDateFilter == "Month") {
      return date.year == now.year && date.month == now.month;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<ExpenseModel>("expenses");
    final settingsBox = Hive.box('settings');

    // This creates a general Listenable that notifies when either box changes
    final combinedListenable = Listenable.merge([
      box.listenable(),
      settingsBox.listenable(),
    ]);

    // FIX: Use AnimatedBuilder instead of ValueListenableBuilder
    // AnimatedBuilder works with any Listenable (including Merged ones)
    return AnimatedBuilder(
      animation: combinedListenable,
      builder: (context, _) {
        // --- 1. DATA CALCULATION ---
        final allExpenses = box.values.toList().reversed.toList();
        final isDark = settingsBox.get('isDarkMode', defaultValue: false);

        final filteredExpenses = allExpenses.where((e) {
          final matchesSearch = e.title.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          final matchesDate = _isWithinDateFilter(e.date);
          final matchesCategory =
              _activeCategoryFilter == "All" ||
              e.category == _activeCategoryFilter;
          return matchesSearch && matchesDate && matchesCategory;
        }).toList();

        final currentBudget = _getBudget();
        // Ensure totalSpent is a double
        double totalSpent = allExpenses.fold(
          0.0,
          (sum, item) => sum + item.amount,
        );
        double remaining = currentBudget - totalSpent;
        double progress = (totalSpent / currentBudget).clamp(0.0, 1.0);

        // --- 2. RETURN THE SCAFFOLD ---
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text(
              "Xpenza",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: () => settingsBox.put('isDarkMode', !isDark),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: () => _exportToPDF(filteredExpenses),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _showSettingsDialog(context),
              ),
              IconButton(
                onPressed: () => _confirmDeleteAll(context, box),
                icon: const Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(totalSpent, remaining, progress),
              ),
              if (filteredExpenses.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildChartSection(filteredExpenses, isDark),
                ),

              // Search Input
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Search transactions...",
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.indigo,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // Filter Tabs
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildFilterRow(
                      ["All", "Today", "Week", "Month"],
                      _activeDateFilter,
                      (val) => setState(() => _activeDateFilter = val),
                      isDark,
                    ),
                    _buildFilterRow(
                      _categories,
                      _activeCategoryFilter,
                      (val) => setState(() => _activeCategoryFilter = val),
                      isDark,
                    ),
                  ],
                ),
              ),

              // Summary Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total for this View:",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "₹${filteredExpenses.fold(0.0, (sum, e) => sum + e.amount).toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 15, 24, 16),
                  child: Text(
                    "History",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              filteredExpenses.isEmpty
                  ? _buildEmptyState(isDark)
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _ExpenseTile(
                            expense: filteredExpenses[index],
                            onTap: () => _showAddExpense(
                              context,
                              expense: filteredExpenses[index],
                            ),
                          ),
                          childCount: filteredExpenses.length,
                        ),
                      ),
                    ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddExpense(context),
            label: const Text(
              "Add Expense",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.add_rounded),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  // --- HELPERS ---

  Widget _buildFilterRow(
    List<String> items,
    String activeItem,
    Function(String) onSelect,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: items.map((item) {
          final isSelected = activeItem == item;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item),
              selected: isSelected,
              onSelected: (val) => onSelect(item),
              selectedColor: Colors.indigo,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(double spent, double remaining, double progress) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Remaining Balance",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          Text(
            "₹${remaining.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Spent: ₹${spent.toStringAsFixed(0)}",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: progress > 0.9 ? Colors.orangeAccent : Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(List<ExpenseModel> expenses, bool isDark) {
    Map<String, double> data = {};
    for (var e in expenses) {
      data[e.category] = (data[e.category] ?? 0) + e.amount;
    }
    Map<String, Color> catColors = {
      "Food": Colors.orangeAccent,
      "Transport": Colors.blueAccent,
      "Shopping": Colors.purpleAccent,
      "Bills": Colors.redAccent,
    };

    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 30,
                sections: data.entries
                    .map(
                      (entry) => PieChartSectionData(
                        color: catColors[entry.key] ?? Colors.grey,
                        value: entry.value,
                        title: '',
                        radius: 15,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: data.keys
                    .map(
                      (cat) => Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: catColors[cat] ?? Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddExpense(BuildContext context, {ExpenseModel? expense}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseScreen(expense: expense),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final controller = TextEditingController(text: _getBudget().toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Monthly Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            prefixText: "₹ ",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) Hive.box('settings').put('monthlyLimit', val);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, Box box) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              box.clear();
              Navigator.pop(context);
            },
            child: const Text(
              "Delete All",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              "No expenses found",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final VoidCallback onTap;
  const _ExpenseTile({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: Key(expense.hashCode.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
          onDismissed: (_) => expense.delete(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIcon(expense.category), color: Colors.indigo),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${expense.category} • ${DateFormat("MMM d").format(expense.date)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "-₹${expense.amount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String cat) {
    if (cat == "Food") return Icons.restaurant_rounded;
    if (cat == "Transport") return Icons.directions_car_rounded;
    if (cat == "Shopping") return Icons.shopping_bag_rounded;
    if (cat == "Bills") return Icons.receipt_long_rounded;
    return Icons.category_rounded;
  }
}
