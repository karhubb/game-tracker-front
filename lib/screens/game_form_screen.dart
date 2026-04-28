import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_tracker/services/service.dart';
import 'package:game_tracker/models/game.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class GameFormScreen extends StatefulWidget {
  final Game? game;
  const GameFormScreen({super.key, this.game});

  @override
  State<GameFormScreen> createState() => _GameFormScreenState();
}

class _GameFormScreenState extends State<GameFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _franchiseController;
  late TextEditingController _categoryController;

  int _rating = 5;
  bool _played = false;
  List<GameNote> _notes = [];
  Uint8List? _webImage;
  String? _currentImageUrl;

  final Color aquaColor = const Color(0xFF40E0D0);
  final Color stateGreenColor = const Color(0xFF88F2C4);

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.game?.name ?? "");
    _franchiseController =
        TextEditingController(text: widget.game?.franchise ?? "");
    _categoryController =
        TextEditingController(text: widget.game?.category ?? "");
    _rating = widget.game?.rating ?? 5;
    _played = widget.game?.played ?? false;
    _notes = widget.game?.notes != null
        ? List.from(widget.game!.notes)
        : [];
    _currentImageUrl = widget.game?.coverUrl;
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      var f = await image.readAsBytes();
      setState(() {
        _webImage = f;
        _currentImageUrl = null;
      });
    }
  }

  Future<String?> _uploadToCloudinary() async {
    if (_webImage == null) return _currentImageUrl;
    final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/dqz5vxv7o/image/upload');
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = 'juegos_preset'
      ..files.add(http.MultipartFile.fromBytes('file', _webImage!,
          filename: 'cover.jpg'));
    final response = await request.send();
    if (response.statusCode == 200) {
      final res = await http.Response.fromStream(response);
      return jsonDecode(res.body)['secure_url'];
    }
    return _currentImageUrl;
  }

  // Diálogo para agregar nota
  void _addNote() {
    final TextEditingController noteController =
        TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)),
        title: Text(
          "Nueva impresión",
          style: GoogleFonts.nunito(
              color: aquaColor,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        content: TextField(
          controller: noteController,
          style:
              GoogleFonts.nunito(color: Colors.white, fontSize: 14),
          autofocus: true,
          decoration: _inputDecoration("¿Qué estás pensando del juego?"),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar",
                style: GoogleFonts.nunito(
                    color: Colors.white38,
                    fontWeight: FontWeight.w400)),
          ),
          TextButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                setState(() {
                  _notes.insert(
                      0,
                      GameNote(
                          content: noteController.text,
                          date: DateTime.now()));
                });
                Navigator.pop(ctx);
              }
            },
            child: Text("Guardar",
                style: GoogleFonts.nunito(
                    color: aquaColor,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _saveGame() async {
    if (_formKey.currentState!.validate()) {
      final coverUrl = await _uploadToCloudinary();
      final nuevoJuego = Game(
        id: widget.game?.id,
        name: _nameController.text,
        coverUrl: coverUrl ?? "",
        franchise: _franchiseController.text,
        category: _categoryController.text,
        rating: _rating,
        played: _played,
        notes: _notes,
      );

      if (widget.game == null) {
        await _apiService.createGame(nuevoJuego);
      } else {
        await _apiService.updateGame(widget.game!.id!, nuevoJuego);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  // Input con línea inferior sutil
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.nunito(
          color: Colors.white54,
          fontSize: 13,
          fontWeight: FontWeight.w300),
      enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white12)),
      focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: aquaColor)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.game != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Título con Orbitron, igual que "MY GAMES" (punto 2)
        title: Text(
          isEditing ? 'Editar juego' : 'Nuevo juego',
          style: GoogleFonts.orbitron(
              color: aquaColor,
              fontWeight: FontWeight.w500,
              fontSize: 15,
              letterSpacing: 1.5),
        ),
        iconTheme: IconThemeData(color: aquaColor),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Portada
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white10),
                      ),
                      child: _webImage != null
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(19),
                              child: Image.memory(_webImage!,
                                  fit: BoxFit.cover))
                          : (_currentImageUrl != null &&
                                  _currentImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(19),
                                  child: Image.network(
                                      _currentImageUrl!,
                                      fit: BoxFit.cover))
                              : Icon(Icons.gamepad_outlined,
                                  size: 50,
                                  color:
                                    aquaColor.withValues(alpha: 0.4))),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: aquaColor,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Campos de texto — input con Nunito
            TextFormField(
              controller: _nameController,
              style: GoogleFonts.nunito(
                  color: Colors.white, fontSize: 15),
              decoration: _inputDecoration('Nombre del juego'),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _franchiseController,
              style: GoogleFonts.nunito(
                  color: Colors.white, fontSize: 15),
              decoration: _inputDecoration('Franquicia o estudio'),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _categoryController,
              style: GoogleFonts.nunito(
                  color: Colors.white, fontSize: 15),
              decoration: _inputDecoration('Categoría'),
            ),
            const SizedBox(height: 30),

            // Rating
            Text("Tu calificación:",
                style: GoogleFonts.nunito(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w300)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: index < _rating
                        ? Colors.amber
                        : Colors.white24,
                    size: 28,
                  ),
                  onPressed: () =>
                      setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 30),

            // Timeline de impresiones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Timeline de impresiones",
                        style: GoogleFonts.nunito(
                            color: aquaColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text("Tus pensamientos sobre el juego.",
                        style: GoogleFonts.nunito(
                            color: Colors.white24,
                            fontSize: 11,
                            fontWeight: FontWeight.w300)),
                  ],
                ),
                _cardIconBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    onTap: _addNote),
              ],
            ),
            const SizedBox(height: 10),
            ..._notes
                .take(3)
                .map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        "· ${n.content}",
                        style: GoogleFonts.nunito(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w300),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
            if (_notes.length > 3)
              Text("...",
                  style: GoogleFonts.nunito(
                      color: Colors.white24)),

            Divider(color: Colors.white10, height: 40),

            // Switch jugado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("¿Ya lo has jugado?",
                    style: GoogleFonts.nunito(
                        color: Colors.white70, fontSize: 14)),
Switch(
  value: _played,
  onChanged: (v) => setState(() => _played = v),
  thumbColor: WidgetStateProperty.resolveWith<Color?>(
    (states) => states.contains(WidgetState.selected) 
        ? stateGreenColor 
        : null,
  ),
),
              ],
            ),

            const SizedBox(height: 40),

            // Botón guardar
            ElevatedButton(
              onPressed: _saveGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: aquaColor,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isEditing
                    ? "Guardar cambios"
                    : "Crear nuevo juego",
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _cardIconBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: aquaColor, size: 20),
      ),
    );
  }
}