import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class EncryptionService {
  // Generate a key from chat ID (deterministic untuk kedua user)
  static encrypt_lib.Key _generateKeyFromChatId(String chatId) {
    final bytes = utf8.encode(chatId);
    final digest = sha256.convert(bytes);
    // Gunakan 32 bytes pertama dari hash untuk AES-256
    return encrypt_lib.Key(Uint8List.fromList(digest.bytes));
  }

  static encrypt_lib.IV _generateIV() {
    // Generate IV acak untuk setiap pesan
    return encrypt_lib.IV.fromSecureRandom(16);
  }

  /// Enkripsi pesan menggunakan chat ID sebagai key
  static Map<String, String> encryptMessage(String plainText, String chatId) {
    try {
      final key = _generateKeyFromChatId(chatId);
      final iv = _generateIV();

      final encrypter = encrypt_lib.Encrypter(
          encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc)
      );

      final encrypted = encrypter.encrypt(plainText, iv: iv);

      return {
        'encryptedMessage': encrypted.base64,
        'iv': iv.base64,
      };
    } catch (e) {
      print('Encryption error: $e');
      rethrow;
    }
  }

  /// Dekripsi pesan menggunakan chat ID sebagai key
  static String decryptMessage(
      String encryptedMessage,
      String ivString,
      String chatId
      ) {
    try {
      final key = _generateKeyFromChatId(chatId);
      final iv = encrypt_lib.IV.fromBase64(ivString);

      final encrypter = encrypt_lib.Encrypter(
          encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc)
      );

      final decrypted = encrypter.decrypt64(encryptedMessage, iv: iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return '[Pesan tidak dapat didekripsi]';
    }
  }

  /// Enkripsi pesan terakhir untuk preview (tanpa IV karena tidak perlu terlalu aman)
  static String encryptLastMessage(String plainText, String chatId) {
    try {
      final encrypted = encryptMessage(plainText, chatId);
      return '${encrypted['encryptedMessage']}:${encrypted['iv']}';
    } catch (e) {
      return plainText; // Fallback jika gagal
    }
  }

  /// Dekripsi pesan terakhir dari preview
  static String decryptLastMessage(String encryptedData, String chatId) {
    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return encryptedData;

      return decryptMessage(parts[0], parts[1], chatId);
    } catch (e) {
      return '[Encrypted]';
    }
  }
}