import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SaleDetailsScreen extends StatelessWidget {
  final String saleId;

  const SaleDetailsScreen({Key? key, required this.saleId}) : super(key: key);

  Stream<DocumentSnapshot> _getSaleDetails() {
    return FirebaseFirestore.instance.collection('sales').doc(saleId).snapshots();
  }

  Future<bool> _isUserBoss() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    return userDoc.data()?['isBoss'] ?? false;
  }

  Future<void> _toggleStatus(BuildContext context, String currentStatus) async {
    String newStatus = currentStatus == 'no revisado' ? 'revisado' : 'no revisado';

    try {
      await FirebaseFirestore.instance.collection('sales').doc(saleId).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el estado: $e')),
      );
    }
  }

  Future<String> _getUserName(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data()?['name'] ?? 'Usuario no disponible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles del Registro')),
      body: StreamBuilder(
        stream: _getSaleDetails(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('No se encontraron detalles para esta venta.'));
          }

          final sale = snapshot.data!.data() as Map<String, dynamic>;
          final userId = sale['userId']; // Obtener el userId de la venta

          return FutureBuilder<bool>(
            future: _isUserBoss(),
            builder: (context, bossSnapshot) {
              if (bossSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              final isBoss = bossSnapshot.data ?? false;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sale['images'] != null && sale['images'].isNotEmpty) ...[
                        Container(
                          height: 200,
                          child: PageView.builder(
                            itemCount: sale['images'].length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImage(imageUrl: sale['images'][index]),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    sale['images'][index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      _buildDetailCard('Tipo', sale['type']),
                      _buildDetailCard('Nota', sale['description']),
                      _buildDetailCard('Estado', sale['status'], status: sale['status']),
                      _buildDetailCard('Valor Cobrado', '${sale['price']?.toString() ?? 'No disponible'}'),
                      FutureBuilder<String>(
                        future: _getUserName(userId),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }
                          return _buildDetailCard('Creado por', userSnapshot.data ?? 'Usuario no disponible');
                        },
                      ),
                      SizedBox(height: 20),
                      if (isBoss) ...[
                        Container(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: sale['status'] == 'revisado' ? Colors.orange : Colors.green,
                              padding: EdgeInsets.symmetric(vertical: 15),
                            ),
                            onPressed: () => _toggleStatus(context, sale['status']),
                            child: Text(
                              sale['status'] == 'no revisado' 
                                  ? 'Marcar como Revisado' 
                                  : 'Marcar como No Revisado',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, {String? status}) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 18, color: status == 'revisado' ? Colors.green : null),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Hero(
            tag: imageUrl,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
