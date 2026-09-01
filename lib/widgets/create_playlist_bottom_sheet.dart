import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/models/song_model.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/providers/language_provider.dart';

class CreatePlaylistBottomSheet {
  static void show({
    required BuildContext context,
    required List<Song> songs,
    VoidCallback? onSuccess,
    bool isFromDownloads = false,
  }) {
    final TextEditingController controller = TextEditingController();
    String? selectedImagePath;
    final langProvider = context.read<LanguageProvider>();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (modalContext, setModalState) => Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 32),
                          onPressed: () => Navigator.pop(pageContext),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  setModalState(() {
                                    selectedImagePath = image.path;
                                  });
                                }
                              },
                              child: Container(
                                width: 256,
                                height: 144,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                  image: selectedImagePath != null
                                      ? DecorationImage(
                                          image: FileImage(
                                              File(selectedImagePath!)),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: selectedImagePath == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            color:
                                                Theme.of(context).primaryColor,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            langProvider.t('choose_cover'),
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: TextField(
                                controller: controller,
                                textAlign: TextAlign.start,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: langProvider.t('list_name'),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  filled: false,
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        blurRadius: 15,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (controller.text.isNotEmpty) {
                                          context
                                              .read<SongProvider>()
                                              .createFolder(
                                                name: controller.text,
                                                songs: songs,
                                                customImagePath:
                                                    selectedImagePath,
                                                isFromDownloads: isFromDownloads,
                                              );
                                          Navigator.pop(pageContext);
                                          CustomSnackBar.showSuccess(
                                            context: context,
                                            message:
                                                '${controller.text} ${langProvider.t('create')}d.',
                                          );
                                          if (onSuccess != null) {
                                            onSuccess();
                                          }
                                        } else {
                                          CustomSnackBar.showError(
                                            context: context,
                                            message: langProvider
                                                .t('enter_list_name_warning'),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Center(
                                          child: Text(
                                            langProvider.t('create'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}
