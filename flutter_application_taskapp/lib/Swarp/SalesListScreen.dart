import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:My_car_tse/Swarp/SaleDetailsScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SalesListScreen extends StatefulWidget {
  @override
  _SalesListScreenState createState() => _SalesListScreenState();
}

class _SalesListScreenState extends State<SalesListScreen> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  Future<void> _deleteSale(String docId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Eliminación'),
          content: Text('¿Seguro que quieres eliminar este servicio?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Sí'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      await FirebaseFirestore.instance.collection('sales').doc(docId).delete();
      
      // Usar el GlobalKey para mostrar el SnackBar
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Servicio eliminado correctamente')),
      );
    }
  }

  Future<bool> _isUserBoss() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    return userDoc.data()?['isBoss'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(title: Text('Listado de Ventas')),
        body: FutureBuilder<bool>(
          future: _isUserBoss(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final isBoss = snapshot.data ?? false;
            final currentUserId = FirebaseAuth.instance.currentUser!.uid;

            return StreamBuilder(
              stream: FirebaseFirestore.instance
                .collection('sales')
                .orderBy('timestamp', descending: true)
                .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No hay ventas registradas.'));
                }

                // Filtrar los registros según el rol del usuario
                final sales = snapshot.data!.docs.where((sale) {
                  if (isBoss) {
                    return true;
                  } else {
                    return sale['userId'] == currentUserId;
                  }
                }).toList();

                // Agrupar ventas por mes
                Map<String, List<QueryDocumentSnapshot>> groupedSales = {};
                for (var sale in sales) {
                  final timestamp = sale['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  final monthYear = DateFormat('MMMM yyyy').format(date);

                  if (!groupedSales.containsKey(monthYear)) {
                    groupedSales[monthYear] = [];
                  }
                  groupedSales[monthYear]!.add(sale);
                }

                // Ordenar los meses de más reciente a más antiguo
                var sortedMonths = groupedSales.keys.toList()..sort((a, b) {
                  final dateA = DateFormat('MMMM yyyy').parse(a);
                  final dateB = DateFormat('MMMM yyyy').parse(b);
                  return dateB.compareTo(dateA);
                });

                // Ordenar las ventas dentro de cada mes
                groupedSales.forEach((month, sales) {
                  sales.sort((a, b) {
                    final timestampA = a['timestamp'] as Timestamp;
                    final timestampB = b['timestamp'] as Timestamp;
                    return timestampB.compareTo(timestampA);
                  });
                });

                return ListView.builder(
                  itemCount: sortedMonths.length,
                  itemBuilder: (context, index) {
                    final monthYear = sortedMonths[index];
                    final salesInMonth = groupedSales[monthYear]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Text(
                            monthYear,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: salesInMonth.length,
                          itemBuilder: (context, saleIndex) {
                            final sale = salesInMonth[saleIndex];
                            final userId = sale['userId'];
                            final timestamp = sale['timestamp'] as Timestamp;
                            final formattedDate = DateFormat('dd/MM/yyyy').format(timestamp.toDate());

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('${sale['type']}'),
                            subtitle: Text('Cargando usuario...'),
                          );
                        }

                        final userName = userSnapshot.hasData && userSnapshot.data!.exists
                            ? userSnapshot.data!['name'] ?? 'Usuario no disponible'
                            : 'Usuario no disponible';

                                return Card(
                                  margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                  elevation: 4,
                          child: ListTile(
                                    leading: Icon(
                                      sale['type'] == 'Peaje' 
                                          ? Icons.toll
                                          : Icons.local_gas_station,
                                      color: sale['type'] == 'Peaje' 
                                          ? Colors.purple[700]
                                          : sale['type'] == 'Gas' 
                                              ? Colors.orange[700]
                                              : Colors.blue[700],
                                      size: 28,
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          '${sale['type']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: sale['type'] == 'Peaje' 
                                                ? Colors.purple[700]
                                                : sale['type'] == 'Gas' 
                                                    ? Colors.orange[700]
                                                    : Colors.blue[700],
                                          ),
                                        ),
                                        if (sale['type'] == 'Peaje' && sale['location'] != null) ...[
                                          SizedBox(width: 8),
                                          Text(
                                            '${sale['location']}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: sale['status'] == 'revisado' 
                                                    ? Colors.green[100] 
                                                    : Colors.orange[100],
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Estado: ${sale['status']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: sale['status'] == 'revisado' 
                                                      ? Colors.green[700] 
                                                      : Colors.orange[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Creado por: $userName',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'Fecha: $formattedDate',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'es_CO',
                                            symbol: '\$',
                                            decimalDigits: 0,
                                          ).format(sale['price'] ?? 0),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        if (isBoss) ...[
                                          SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(Icons.delete, color: Colors.red[400], size: 22),
                                            onPressed: () => _deleteSale(sale.id),
                                          ),
                                        ],
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
                          ),
                        );
                      },
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
