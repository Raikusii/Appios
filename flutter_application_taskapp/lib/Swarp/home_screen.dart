import 'package:flutter/material.dart';
import 'package:My_car_tse/Swarp/RegisterSaleScreen.dart';
import 'package:My_car_tse/Swarp/SaleDetailsScreen.dart';
import 'package:My_car_tse/Swarp/SalesListScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:My_car_tse/Swarp/LoginScreen.dart';
import 'package:intl/intl.dart';
import 'package:My_car_tse/Swarp/ProfileScreen.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:My_car_tse/Swarp/RegisterTollScreen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _selectedMonth;
  bool _isMonthFilterActive = false;
  int _selectedIndex = 0;
  String? _selectedUserId;
  List<Map<String, dynamic>> _pinnedUsersList = [];
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _loadPinnedUsers();
  }

  Future<void> _loadPinnedUsers() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final pinnedUserIds = List<String>.from(userDoc.data()?['pinnedUserIds'] ?? []);

    for (String userId in pinnedUserIds) {
      final userSnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.data();
        _pinnedUsersList.add({
          'id': userId,
          'name': userData?['name'] ?? 'Sin nombre',
          'email': userData?['email'] ?? 'Sin email',
        });
      }
    }
    setState(() {});
  }

  Future<bool> _isUserBoss() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    return userDoc.data()?['isBoss'] ?? false;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return Container(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.local_gas_station, color: Colors.blue),
                  title: Text('Registrar Servicio'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterSaleScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.toll, color: Colors.green),
                  title: Text('Registrar Peajes'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegisterTollScreen()),
                    );
                  },
                ),
                SizedBox(height: 20),
              ],
            ),
          );
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      );
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SalesListScreen()),
      );
    }
  }

  void _pickMonth() async {
    DateTime? pickedMonth = await showMonthPicker(
      context: context,
      initialDate: _selectedMonth ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedMonth != null) {
      setState(() {
        _selectedMonth = pickedMonth;
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Stream<QuerySnapshot> _getSalesStream() {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .asyncMap((userDoc) async {
          final isBoss = userDoc.data()?['isBoss'] ?? false;
          final pinnedUserIds = List<String>.from(userDoc.data()?['pinnedUserIds'] ?? []);
          
          if (_selectedType == 'Nada') {
            return FirebaseFirestore.instance
                .collection('sales')
                .where('userId', isEqualTo: 'non_existent_id')
                .snapshots()
                .first;
          }

          Query query = FirebaseFirestore.instance.collection('sales');
          
          if (_selectedType != null && _selectedType != 'Nada') {
            if (_selectedType == 'Combustible') {
              query = query.where('type', whereIn: ['Gas', 'Gasolina']);
            } else if (_selectedType == 'Peajes') {
              query = query.where('type', isEqualTo: 'Peaje');
            }
          }

          if (!isBoss) {
            query = query.where('userId', isEqualTo: currentUserId);
          } else {
            if (_selectedUserId != null) {
              query = query.where('userId', isEqualTo: _selectedUserId);
            } else if (pinnedUserIds.isNotEmpty) {
              pinnedUserIds.add(currentUserId);
              query = query.where('userId', whereIn: pinnedUserIds);
            }
          }
          
          return query
            .orderBy('timestamp', descending: true)
            .snapshots()
            .first;
    });
  }

  Widget _buildSalesListView(List<DocumentSnapshot> filteredDocs) {
    Map<String, Map<String, List<DocumentSnapshot>>> groupedByUserAndDate = {};

    for (var doc in filteredDocs) {
      final userId = doc['userId'] as String;
      final timestamp = doc['timestamp'] as Timestamp?;
      
      if (timestamp != null) {
        final date = timestamp.toDate();
        final formattedDate = '${date.day}/${date.month}/${date.year}';

        groupedByUserAndDate.putIfAbsent(userId, () => {});
        groupedByUserAndDate[userId]!.putIfAbsent(formattedDate, () => []);
        groupedByUserAndDate[userId]![formattedDate]!.add(doc);
      }
    }

    return ListView.builder(
      itemCount: groupedByUserAndDate.length,
      itemBuilder: (context, userIndex) {
        final userId = groupedByUserAndDate.keys.elementAt(userIndex);
        final userDates = groupedByUserAndDate[userId]!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final userName = userData['name'] ?? 'Usuario desconocido';

            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    for (var date in userDates.keys)
                      _buildDateSection(date, userDates[date]!),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateSection(String date, List<DocumentSnapshot> sales) {
    double dailyTotal = sales.fold(0.0, (sum, sale) {
      final price = sale['price'] is num ? sale['price'].toDouble() : 0.0;
      return sum + price;
    });

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            Text(
              'Total del día: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(dailyTotal)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            SizedBox(height: 8),
            Column(
              children: sales.map((sale) {
                return ListTile(
                  title: Text('${sale['type']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio: ${NumberFormat.currency(locale: 'es_CO', symbol: 'COP ', decimalDigits: 0).format(sale['price']?.toDouble() ?? 0.0)}'),
                      Text('Estado: ${sale['status']}'),
                      Text(
                        'Revisado: ${sale['status'] == 'revisado' ? 'Sí' : 'No'}',
                        style: TextStyle(
                          color: sale['status'] == 'revisado' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SaleDetailsScreen(saleId: sale.id),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text('Cargando...', style: TextStyle(fontSize: 16));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text('Usuario no encontrado', style: TextStyle(fontSize: 16));
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final userName = userData['name'] ?? 'Usuario';
            final userRole = userData['isBoss'] == true ? 'Jefe' : 'Trabajador';

            return RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: userName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: ' - $userRole',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // Forzar la actualización de la lista de ventas
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isUserBoss(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final isBoss = snapshot.data ?? false;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<String?>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Tipo de Registro',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: 'Nada',
                      child: Text('Nada', 
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Combustible',
                      child: Text('Combustible'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'Peajes',
                      child: Text('Peajes'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
                    });
                  },
                ),
              ),
              if (isBoss)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButtonFormField<String?>(
                    value: _selectedUserId,
                    decoration: InputDecoration(
                      labelText: 'Seleccionar Usuario Fijado',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nada', 
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ..._pinnedUsersList.map((user) {
                        return DropdownMenuItem<String?>(
                          value: user['id'],
                          child: Text('${user['name']} (${user['email']})'),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _pickMonth,
                      child: Text(_selectedMonth == null
                          ? 'Seleccionar Mes'
                          : 'Mes: ${DateFormat('MMMM yyyy').format(_selectedMonth!)}'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Text('Filtrar por mes'),
                        Switch(
                          value: _isMonthFilterActive,
                          onChanged: (value) {
                            setState(() {
                              _isMonthFilterActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getSalesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No hay registros disponibles.'));
                    }

                    if (!isBoss) {
                      var filteredDocs = snapshot.data!.docs;
                      if (_isMonthFilterActive && _selectedMonth != null) {
                        filteredDocs = filteredDocs.where((doc) {
                          final saleDate = (doc['timestamp'] as Timestamp).toDate();
                          return saleDate.year == _selectedMonth!.year && 
                                 saleDate.month == _selectedMonth!.month;
                        }).toList();
                      }

                      if (filteredDocs.isEmpty) {
                        return Center(child: Text('No se encontraron registros para el período seleccionado.'));
                      }

                      return _buildSalesListView(filteredDocs);
                    }

                    if (_selectedUserId == null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Selecciona un usuario para ver sus registros',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }

                    var filteredDocs = snapshot.data!.docs.where((doc) {
                      if (_isMonthFilterActive && _selectedMonth != null) {
                        final saleDate = (doc['timestamp'] as Timestamp).toDate();
                        return saleDate.year == _selectedMonth!.year && 
                               saleDate.month == _selectedMonth!.month;
                      }
                      return true;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(child: Text('No se encontraron resultados.'));
                    }

                    return _buildSalesListView(filteredDocs);
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Nuevo Registro',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Listado de Registros',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
