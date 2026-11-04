import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color red = Color(0xFF990909);
const Color darkRed = Color(0xFF650606);

void main() => runApp(const ChickenApp());

class ChickenApp extends StatelessWidget {
  const ChickenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TU Chicken Zone',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: red),
      scaffoldBackgroundColor: const Color(0xFFF7F5F5),
      appBarTheme: const AppBarTheme(backgroundColor: red, foregroundColor: Colors.white),
    ),
    home: const ChickenHome(),
  );
}

class Entry {
  String id, type, date, party, note;
  int kg, grams;
  double rate, received, expense, oldBalance;
  Entry({required this.id, required this.type, required this.date, required this.party,
    required this.kg, required this.grams, required this.rate, required this.received,
    required this.expense, required this.note, this.oldBalance = 0});
  double get weight => kg + grams / 1000.0;
  double get amount => weight * rate;
  double get balance => amount + expense - received;
  Map<String, dynamic> toJson() => {
    'id':id, 'type':type, 'date':date, 'party':party, 'kg':kg, 'grams':grams,
    'rate':rate, 'received':received, 'expense':expense, 'note':note, 'oldBalance':oldBalance
  };
  factory Entry.fromJson(Map<String,dynamic> j) => Entry(
    id: j['id'] ?? '', type: j['type'] ?? 'Mall', date: j['date'] ?? '',
    party: j['party'] ?? '', kg: j['kg'] ?? 0, grams: j['grams'] ?? 0,
    rate: (j['rate'] ?? 0).toDouble(), received: (j['received'] ?? 0).toDouble(),
    expense: (j['expense'] ?? 0).toDouble(), note: j['note'] ?? '', oldBalance: (j['oldBalance'] ?? 0).toDouble());
}

class ChickenHome extends StatefulWidget {
  const ChickenHome({super.key});
  @override
  State<ChickenHome> createState() => _ChickenHomeState();
}

class _ChickenHomeState extends State<ChickenHome> {
  int tab = 0;
  String appName = 'TU Chicken Zone';
  List<Entry> entries = [];
  bool loaded = false;
  bool licenseActive = false;
  String licenseExpiry = '';
  static const String _licenseSalt = 'TU_CHICKEN_ZONE_OFFLINE_V1';
  final money = NumberFormat('#,##0.00');

  String rupees(double value) => 'Rs. ${money.format(value)}';

  @override
  void initState() { super.initState(); loadData(); }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    appName = prefs.getString('appName') ?? appName;
    licenseActive = prefs.getBool('licenseActive') ?? false;
    licenseExpiry = prefs.getString('licenseExpiry') ?? '';
    if (licenseActive && licenseExpiry.isNotEmpty) {
      final expiry = DateTime.tryParse(licenseExpiry);
      if (expiry == null || DateTime.now().isAfter(expiry)) licenseActive = false;
    }
    try {
      final raw = jsonDecode(prefs.getString('entries') ?? '[]') as List;
      entries = raw.map((e) => Entry.fromJson(Map<String,dynamic>.from(e))).toList();
    } catch (_) { entries = []; }
    if (mounted) setState(() => loaded = true);
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appName', appName);
    await prefs.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await prefs.setBool('licenseActive', licenseActive);
    await prefs.setString('licenseExpiry', licenseExpiry);
  }

  double sum(String type, double Function(Entry) value) =>
      entries.where((e) => e.type == type).fold(0.0, (s,e) => s + value(e));

  double get totalCustomerBalance {
    final customers = entries.where((e) => e.type == 'Customer').toList();
    final transactionBalance = customers.fold<double>(0, (s,e) => s + e.balance);
    final oldBalances = <String,double>{};
    for (final e in customers) {
      oldBalances.putIfAbsent(e.party, () => e.oldBalance);
    }
    return transactionBalance + oldBalances.values.fold<double>(0, (s,v) => s + v);
  }

  double customerBalance(String name) {
    final rows = entries.where((e) => e.type == 'Customer' && e.party == name).toList();
    if (rows.isEmpty) return 0;
    return rows.fold<double>(0, (s,e) => s + e.balance) + rows.first.oldBalance;
  }

  TextFormField textField(TextEditingController controller, String label, {bool numeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
    );
  }

  Future<void> openEntryForm(String type, {Entry? existing}) async {
    final formKey = GlobalKey<FormState>();
    final party = TextEditingController(text: existing?.party ?? '');
    final kg = TextEditingController(text: '${existing?.kg ?? 0}');
    final grams = TextEditingController(text: '${existing?.grams ?? 0}');
    final rate = TextEditingController(text: '${existing?.rate ?? 0}');
    final received = TextEditingController(text: '${existing?.received ?? 0}');
    final expense = TextEditingController(text: '${existing?.expense ?? 0}');
    final note = TextEditingController(text: existing?.note ?? '');
    final oldBalance = TextEditingController(text: '${existing?.oldBalance ?? 0}');

    final result = await showDialog<Entry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${existing == null ? 'Add' : 'Edit'} $type'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  textField(party, type == 'Customer' ? 'Customer Name' : 'Supplier / Party Name'),
                  const SizedBox(height: 9),
                  Row(children: [
                    Expanded(child: textField(kg, 'Weight KG', numeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: textField(grams, 'Grams (0-999)', numeric: true)),
                  ]),
                  const SizedBox(height: 9),
                  textField(rate, 'Rate Rs/Kg', numeric: true),
                  if (type == 'Customer') ...[
                    const SizedBox(height: 9),
                    textField(oldBalance, 'Old Balance Rs', numeric: true),
                    const SizedBox(height: 9),
                    textField(received, 'Received Rs', numeric: true),
                  ],
                  if (type == 'Mall') ...[
                    const SizedBox(height: 9),
                    textField(expense, 'Vehicle Expense Rs', numeric: true),
                  ],
                  const SizedBox(height: 9),
                  textField(note, 'Note'),
                  const SizedBox(height: 10),
                  Builder(builder: (context) {
                    final w = (int.tryParse(kg.text) ?? 0) + (int.tryParse(grams.text) ?? 0) / 1000.0;
                    final a = w * (double.tryParse(rate.text) ?? 0);
                    return Text('Total: ${w.toStringAsFixed(3)} Kg  |  ${rupees(a)}');
                  }),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final g = int.tryParse(grams.text) ?? 0;
              if (g < 0 || g > 999) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grams must be between 0 and 999')));
                return;
              }
              Navigator.pop(dialogContext, Entry(
                id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                type: type, date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                party: party.text.trim(), kg: int.tryParse(kg.text) ?? 0, grams: g,
                rate: double.tryParse(rate.text) ?? 0, received: double.tryParse(received.text) ?? 0,
                expense: double.tryParse(expense.text) ?? 0, note: note.text.trim(),
                oldBalance: double.tryParse(oldBalance.text) ?? 0,
              ));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (existing == null) {
          entries.insert(0, result);
        } else {
          final index = entries.indexWhere((e) => e.id == existing.id);
          if (index >= 0) entries[index] = result;
        }
      });
      await saveData();
    }
  }

  String _makeLicenseKey(String expiry) {
    var hash = 17;
    final source = '$_licenseSalt|$expiry';
    for (final unit in source.codeUnits) { hash = (hash * 31 + unit) & 0x7fffffff; }
    return 'TU-${expiry.replaceAll('-', '')}-${hash.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }

  Future<void> activateLicense() async {
    final controller = TextEditingController();
    final key = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Activate Customer License'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'License Key', hintText: 'TU-YYYYMMDD-CODE')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase()), child: const Text('Activate'))],
    ));
    if (key == null || key.isEmpty) return;
    final parts = key.split('-');
    if (parts.length != 3 || parts[0] != 'TU' || parts[1].length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid license key'))); return;
    }
    final dateText = '${parts[1].substring(0,4)}-${parts[1].substring(4,6)}-${parts[1].substring(6,8)}';
    final expiry = DateTime.tryParse(dateText);
    if (expiry == null || _makeLicenseKey(dateText) != key || DateTime.now().isAfter(expiry)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('License is invalid or expired'))); return;
    }
    setState(() { licenseActive = true; licenseExpiry = dateText; });
    await saveData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('License activated until $dateText')));
  }

  Future<void> showLicenseGenerator() async {
    final pin = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Owner License Generator'),
      content: TextField(controller: pin, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Admin License Password')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, pin.text == '03135353153'), child: const Text('Continue'))],
    ));
    if (ok != true) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN'))); return; }
    DateTime expiry = DateTime.now().add(const Duration(days: 30));
    final generated = await showDialog<String>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Generate Offline License'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Expiry: ${DateFormat('yyyy-MM-dd').format(expiry)}'),
        Wrap(spacing: 6, children: [
          TextButton(onPressed: () => refresh(() => expiry = DateTime.now().add(const Duration(days: 30))), child: const Text('1 Month')),
          TextButton(onPressed: () => refresh(() => expiry = DateTime.now().add(const Duration(days: 180))), child: const Text('6 Months')),
          TextButton(onPressed: () => refresh(() => expiry = DateTime.now().add(const Duration(days: 365))), child: const Text('1 Year')),
          TextButton(onPressed: () => refresh(() => expiry = DateTime(2099,12,31)), child: const Text('Lifetime')),
        ]),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, _makeLicenseKey(DateFormat('yyyy-MM-dd').format(expiry))), child: const Text('Generate Key'))],
    )));
    if (generated != null && mounted) showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Customer License Key'), content: SelectableText(generated),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ));
  }

  Future<void> renameApp() async {
    final controller = TextEditingController(text: appName);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change App Name'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'App name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() => appName = value);
      await saveData();
    }
  }

  Future<void> makePdf({String? customer}) async {
    final list = entries.where((e) => customer == null || (e.type == 'Customer' && e.party == customer)).toList();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Text(customer == null ? '$appName Report' : 'Customer Ledger: $customer',
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Table.fromTextArray(
        headers: ['Date','Type','Party','Weight Kg','Rate','Amount','Received','Balance'],
        data: list.map((e) => [e.date,e.type,e.party,e.weight.toStringAsFixed(3),
          e.rate.toStringAsFixed(2),e.amount.toStringAsFixed(2),e.received.toStringAsFixed(2),
          e.balance.toStringAsFixed(2)]).toList(),
      ),
    ]));
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  Widget summaryCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Colors.white), const SizedBox(height: 7),
      Text(label, style: const TextStyle(color: Colors.white)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
    ]),
  );

  Widget homePage() => ListView(padding: const EdgeInsets.all(12), children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [red,darkRed]), borderRadius: BorderRadius.circular(18)),
      child: GestureDetector(onLongPress: showLicenseGenerator, child: Text(appName, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 12),
    GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2,
      crossAxisSpacing: 9, mainAxisSpacing: 9, children: [
        summaryCard('Total Mall', '${sum('Mall',(e)=>e.weight).toStringAsFixed(3)} Kg', Colors.green, Icons.scale),
        summaryCard('Total Kami', '${sum('Kami',(e)=>e.weight).toStringAsFixed(3)} Kg', red, Icons.remove_circle),
        summaryCard('Received', rupees(sum('Customer',(e)=>e.received)), Colors.blue, Icons.payments),
        summaryCard('Total Balance', rupees(totalCustomerBalance), Colors.orange, Icons.account_balance_wallet),
        summaryCard('Today Mall Purchase', rupees(entries.where((e) => e.type == 'Mall' && e.date == DateFormat('yyyy-MM-dd').format(DateTime.now())).fold<double>(0, (s,e) => s + e.amount + e.expense)), Colors.deepPurple, Icons.shopping_cart),
      ]),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, children: [
      actionButton('Add Mall', () => openEntryForm('Mall')),
      actionButton('Add Kami', () => openEntryForm('Kami')),
      actionButton('Add Customer', () => openEntryForm('Customer')),
      actionButton('All PDF', () => makePdf()),
      actionButton('Rename App', renameApp),
      actionButton('Activate License', activateLicense),
      actionButton('License Generator', showLicenseGenerator),
      const ListTile(leading: Icon(Icons.phone, color: red), title: Text('Contact for customer schemes / license'), subtitle: Text('03161847676')),
      if (licenseActive) Text('License active until: $licenseExpiry', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    ]),
  ]);

  Widget actionButton(String label, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap, icon: const Icon(Icons.add, color: red), label: Text(label));

  Widget recordsPage(String? type) {
    final list = entries.where((e) => type == null || e.type == type).toList();
    return ListView(padding: const EdgeInsets.all(10), children: [
      ListTile(title: Text(type ?? 'All Records', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        trailing: IconButton(onPressed: () => openEntryForm(type ?? 'Mall'), icon: const Icon(Icons.add_circle, color: red))),
      if (list.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('No records yet')),
      ...list.map((e) => Card(child: ListTile(
        title: Text(e.party), subtitle: Text('${e.type} • ${e.date} • ${e.weight.toStringAsFixed(3)} Kg'),
        trailing: Text(rupees(e.amount)),
        onTap: () => openEntryForm(e.type, existing: e),
        onLongPress: () async {
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Delete record?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Delete')),
            ],
          ));
          if (ok == true) { setState(() => entries.removeWhere((x) => x.id == e.id)); await saveData(); }
        },
      ))),
    ]);
  }

  Widget customersPage() {
    final names = entries.where((e) => e.type == 'Customer').map((e) => e.party).toSet().toList();
    return ListView(children: [
      ListTile(title: const Text('Customers / کسٹمرز', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        trailing: IconButton(onPressed: () => openEntryForm('Customer'), icon: const Icon(Icons.person_add))),
      ...names.map((name) {
        final rows = entries.where((e) => e.type == 'Customer' && e.party == name).toList();
        final due = customerBalance(name);
        return ListTile(title: Text(name), subtitle: Text('Balance ${rupees(due)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
            builder: (ctx) => SafeArea(child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(12), child: Text(name, style: const TextStyle(fontSize: 20))),
              ...rows.map((e) => ListTile(title: Text(e.date), subtitle: Text('${e.weight.toStringAsFixed(3)} Kg'), trailing: Text(rupees(e.balance)))),
              FilledButton(onPressed: () => makePdf(customer: name), child: const Text('Customer PDF')),
            ])))),
        );
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [homePage(), recordsPage(null), recordsPage('Mall'), customersPage(), recordsPage('Kami')];
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: loaded ? pages[tab] : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Records'),
          NavigationDestination(icon: Icon(Icons.scale), label: 'Mall'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Customers'),
          NavigationDestination(icon: Icon(Icons.remove_circle), label: 'Kami'),
        ]),
      floatingActionButton: tab == 0 ? null : FloatingActionButton(
        backgroundColor: red, foregroundColor: Colors.white,
        onPressed: () => openEntryForm(tab == 2 ? 'Mall' : tab == 4 ? 'Kami' : 'Customer'),
        child: const Icon(Icons.add)),
    );
  }
}
