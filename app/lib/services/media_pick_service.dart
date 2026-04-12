import 'package:image_picker/image_picker.dart';

/// 相册选图 / 相机拍照，返回本地文件路径。
class MediaPickService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.path;
  }

  Future<String?> takePhoto() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.camera);
    return file?.path;
  }
}
