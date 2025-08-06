import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:graphview/GraphView.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Écran affichant un organigramme hiérarchique avec liens et icônes action
/// - Utilise Firestore avec cache local activé
/// - Lecture optimisée : cache d'abord puis serveur, et reconstruction synchrone du graphe
/// - Les utilisateurs sont dans la collection 'users', la hiérarchie dans 'organigramme'
/// - Mode admin : modification du parent via un dialog
/// - Mode lecture seule : seules les icônes déclenchent des actions
class OrganigrammeScreen extends StatefulWidget {
  final bool isAdmin;
  const OrganigrammeScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  _OrganigrammeScreenState createState() => _OrganigrammeScreenState();
}

class _OrganigrammeScreenState extends State<OrganigrammeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Graph _graph = Graph();
  late BuchheimWalkerConfiguration _builderConfig;
  final Map<String, Node> _nodesMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Activer la persistance locale
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    // Config layout hiérarchique
    _builderConfig = BuchheimWalkerConfiguration()
      ..siblingSeparation = 20
      ..levelSeparation = 30
      ..subtreeSeparation = 30
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
    _loadOrganigramme();
  }

  /// Charge d'abord le cache, puis le serveur
  Future<void> _loadOrganigramme() async {
    setState(() => _isLoading = true);
    List<QueryDocumentSnapshot> docs = [];
    try {
      // 1) cache
      final cacheSnap = await _firestore
          .collection('organigramme')
          .get(const GetOptions(source: Source.cache));
      if (cacheSnap.docs.isNotEmpty) {
        docs = cacheSnap.docs;
      }
      // 2) serveur
      final serverSnap = await _firestore
          .collection('organigramme')
          .get();
      // si différent, on prend le serveur
      if (!_listEquals(docs, serverSnap.docs)) {
        docs = serverSnap.docs;
      }
    } catch (e) {
      debugPrint('Erreur chargement organigramme : $e');
    }

    // Construction synchrone du graphe
    _graph.nodes.clear();
    _graph.edges.clear();
    _nodesMap.clear();
    for (final doc in docs) {
      final userId = doc.id;
      // lecture utilisateur
      final userSnap = await _firestore.collection('users').doc(userId).get();
      final data = userSnap.data();
      if (data == null) continue;
      final phone = data['phone'] as String?;
      final whatsapp = data['whatsapp'] as String? ?? phone;
      final card = _buildUserCard(userId, phone, whatsapp);
      final node = Node.Id(card);
      _nodesMap[userId] = node;
      _graph.addNode(node);
    }
    for (final doc in docs) {
      final userId = doc.id;
      final data = doc.data() as Map<String, dynamic>?;
      final parentId = data?['parentId'] as String?;
      if (parentId != null && _nodesMap.containsKey(parentId)) {
        _graph.addEdge(_nodesMap[parentId]!, _nodesMap[userId]!);
      }
    }

    setState(() => _isLoading = false);
  }

  /// Compare deux listes pour id + parentId
  bool _listEquals(
      List<QueryDocumentSnapshot> a,
      List<QueryDocumentSnapshot> b,
      ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      final da = a[i].data() as Map<String, dynamic>?;
      final db = b[i].data() as Map<String, dynamic>?;
      if (da?['parentId'] != db?['parentId']) return false;
    }
    return true;
  }

  /// Construit la carte utilisateur (trigram + actions)
  Widget _buildUserCard(String trigram, String? phone, String? whatsapp) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trigram, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, size: 20),
                  onPressed: phone != null ? () => _launchDial(phone) : null,
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  onPressed: whatsapp != null ? () => _launchWhatsApp(whatsapp) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de lancer l’appel - $uri'))
      );
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    final native = Uri(
      scheme: 'whatsapp', host: 'send',
      queryParameters: {'phone': phone.replaceFirst('+', '')},
    );
    if (await canLaunchUrl(native)) {
      await launchUrl(native, mode: LaunchMode.externalApplication);
      return;
    }
    final web = Uri.parse('https://wa.me/${phone.replaceFirst('+', '')}');
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer WhatsApp'))
      );
    }
  }

  Future<void> _editNode(String userId) async {
    if (!mounted) return;
    final col = _firestore.collection('organigramme');
    final doc = await col.doc(userId).get();
    String? newParent = doc.data()?['parentId'] as String?;
    final usersSnap = await _firestore.collection('users').get();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Modifier parent'),
          content: StatefulBuilder(
            builder: (c, setC) {
              return DropdownButtonFormField<String?>(
                value: newParent,
                decoration: const InputDecoration(labelText: 'Parent'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ...usersSnap.docs.map((u) => DropdownMenuItem(
                    value: u.id,
                    child: Text(u.data()['fullName'] as String? ?? u.id),
                  )),
                ],
                onChanged: (v) => setC(() => newParent = v),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                await col.doc(userId).update({'parentId': newParent});
                Navigator.pop(ctx);
                _loadOrganigramme();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organigramme'),
        actions: [
          if (widget.isAdmin)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrganigramme)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _graph.nodes.isEmpty
          ? const Center(child: Text('Aucun élément dans l\'organigramme'))
          : InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.1,
        maxScale: 5.0,
        child: GraphView(
          graph: _graph,
          algorithm: BuchheimWalkerAlgorithm(
            _builderConfig,
            TreeEdgeRenderer(_builderConfig),
          ),
          builder: (Node node) {
            final key = node.key as ValueKey;
            return key.value as Widget;
          },
          paint: Paint()
            ..color = Colors.blue
            ..strokeWidth = 2,
        ),
      ),
    );
  }
}
