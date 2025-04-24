import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ExpensesReportScreen extends StatefulWidget {
  @override
  _ExpensesReportScreenState createState() => _ExpensesReportScreenState();
}

class _ExpensesReportScreenState extends State<ExpensesReportScreen> {
  String? _selectedUserId;
  List<Map<String, dynamic>> _usersList = [];
  bool _isBoss = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _loadUsers();
  }

  Future<void> _checkUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (mounted) {
        setState(() {
          _isBoss = userDoc.data()?['isBoss'] ?? false;
          if (!_isBoss) {
            _selectedUserId = currentUser.uid; // Auto-seleccionar para trabajadores
          }
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      
      if (mounted) {
        setState(() {
          _usersList = usersSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Sin nombre',
              'email': data['email'] ?? 'Sin email',
            };
          }).toList();
        });
      }
    } catch (e) {
      print('Error cargando usuarios: $e');
    }
  }

  Stream<QuerySnapshot> _getExpensesStream() {
    if (_selectedUserId == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('sales')
        .where('userId', isEqualTo: _selectedUserId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _formatMonth(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reporte de Gastos'),
      ),
      body: Column(
        children: [
          if (_isBoss)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedUserId,
                decoration: InputDecoration(
                  labelText: 'Seleccionar Usuario',
                  border: OutlineInputBorder(),
                ),
                items: _usersList.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'] as String,
                    child: Text('${user['name']} (${user['email']})'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedUserId = value;
                  });
                },
              ),
            ),

          if (!_isBoss)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Visualizando tu reporte personal',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getExpensesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay registros para este usuario',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Agrupar ventas por mes y calcular totales
                Map<String, List<DocumentSnapshot>> salesByMonth = {};
                Map<String, double> totalsByMonth = {};
                Map<String, double> gasolinaByMonth = {};
                Map<String, double> gasByMonth = {};
                Map<String, double> peajesByMonth = {};

                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final timestamp = data['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  final monthKey = _formatMonth(date);
                  final price = (data['price'] ?? 0).toDouble();
                  final type = data['type'] as String?;

                  if (!salesByMonth.containsKey(monthKey)) {
                    salesByMonth[monthKey] = [];
                    totalsByMonth[monthKey] = 0;
                    gasolinaByMonth[monthKey] = 0;
                    gasByMonth[monthKey] = 0;
                    peajesByMonth[monthKey] = 0;
                  }

                  salesByMonth[monthKey]!.add(doc);
                  totalsByMonth[monthKey] = (totalsByMonth[monthKey] ?? 0) + price;

                  // Sumar a los totales específicos según el tipo
                  switch (type?.toLowerCase()) {
                    case 'gasolina':
                      gasolinaByMonth[monthKey] = (gasolinaByMonth[monthKey] ?? 0) + price;
                      break;
                    case 'gas':
                      gasByMonth[monthKey] = (gasByMonth[monthKey] ?? 0) + price;
                      break;
                    case 'peaje':
                      peajesByMonth[monthKey] = (peajesByMonth[monthKey] ?? 0) + price;
                      break;
                  }
                }

                return ListView.builder(
                  itemCount: salesByMonth.length,
                  itemBuilder: (context, index) {
                    final monthKey = salesByMonth.keys.elementAt(index);
                    final monthSales = salesByMonth[monthKey]!;
                    final monthTotal = totalsByMonth[monthKey]!;
                    final monthGasolina = gasolinaByMonth[monthKey]!;
                    final monthGas = gasByMonth[monthKey]!;
                    final monthPeajes = peajesByMonth[monthKey]!;

                    return Card(
                      margin: EdgeInsets.all(8),
                      child: ExpansionTile(
                        title: Text(monthKey),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(monthTotal)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Gasolina: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(monthGasolina)}',
                              style: TextStyle(
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              'Gas: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(monthGas)}',
                              style: TextStyle(
                                color: Colors.orange[700],
                              ),
                            ),
                            Text(
                              'Peajes: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(monthPeajes)}',
                              style: TextStyle(
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                        children: monthSales.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            leading: data['images'] != null && (data['images'] as List).isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      data['images'][0],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Icon(
                                    data['type'] == 'Peaje' 
                                      ? Icons.toll 
                                      : Icons.receipt,
                                    color: data['type'] == 'Peaje' 
                                      ? Colors.purple[700] 
                                      : null,
                                  ),
                            title: Row(
                              children: [
                                Text(data['type'] ?? 'Sin tipo'),
                                if (data['type'] == 'Peaje' && data['location'] != null)
                                  Text(
                                    ' - ${data['location']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(NumberFormat.currency(
                                  locale: 'es_CO',
                                  symbol: 'COP ',
                                  decimalDigits: 0
                                ).format(data['price'] ?? 0)),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(
                                    (data['timestamp'] as Timestamp).toDate()
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: data['status'] == 'revisado' 
                                    ? Colors.green[100] 
                                    : Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                data['status'] ?? 'pendiente',
                                style: TextStyle(
                                  color: data['status'] == 'revisado' 
                                      ? Colors.green[700] 
                                      : Colors.orange[700],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 