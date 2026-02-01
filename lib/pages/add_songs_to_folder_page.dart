// lib/pages/add_songs_to_folder_page.dart
import 'package:muzik_app/models/song_model.dart';

import 'package:flutter/material.dart';

class AddSongsToFolderPage extends StatefulWidget {
  final List<Song> allSongs; // Bu sayfaya tüm şarkıların listesini göndereceğiz

  const AddSongsToFolderPage({super.key, required this.allSongs});

  @override
  State<AddSongsToFolderPage> createState() => _AddSongsToFolderPageState();
}

class _AddSongsToFolderPageState extends State<AddSongsToFolderPage> {
  // Kullanıcının seçtiği şarkıları tutmak için bir Set kullanalım.
  // Set, bir elemanı sadece bir kez içerebildiği için mükemmeldir.
  final Set<Song> _selectedSongs = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text('${_selectedSongs.length} şarkı seçildi'),
        actions: [
          // "Bitti" butonu. Sadece en az bir şarkı seçildiğinde aktif olur.
          TextButton(
            onPressed: _selectedSongs.isEmpty
                ? null // Eğer şarkı seçilmemişse buton pasif
                : () {
                    // "Bitti"ye tıklandığında, seçilen şarkı listesiyle birlikte
                    // bir önceki sayfaya (FilesPage'e) geri dön.
                    Navigator.pop(context, _selectedSongs.toList());
                  },
            child: Text(
              'Bitti',
              style: TextStyle(
                color: _selectedSongs.isEmpty
                    ? Colors
                          .grey // Pasif renk
                    : Color.fromARGB(255, 101, 144, 32), // Aktif renk
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.allSongs.length,
        itemBuilder: (context, index) {
          final song = widget.allSongs[index];
          // Bu şarkının seçilip seçilmediğini kontrol et
          final bool isSelected = _selectedSongs.contains(song);

          return ListTile(
            leading: Image.network(
              song.coverUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
            title: Text(song.title, style: TextStyle(color: Colors.white)),
            subtitle: Text(
              song.artist,
              style: TextStyle(color: Colors.grey.shade400),
            ),
            // Sağ tarafta "+" veya "tik" ikonu göster
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.blue) // Seçiliyse tik
                : Icon(
                    Icons.add_circle_outline,
                    color: Colors.grey,
                  ), // Seçili değilse +
            onTap: () {
              // Şarkıya tıklandığında seçimi tersine çevir
              setState(() {
                if (isSelected) {
                  _selectedSongs.remove(song); // Seçiliyse kaldır
                } else {
                  _selectedSongs.add(song); // Seçili değilse ekle
                }
              });
            },
          );
        },
      ),
    );
  }
}
