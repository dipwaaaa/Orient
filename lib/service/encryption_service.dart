import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class EncryptionService {
  static encrypt_lib.Key _generateKeyFromChatId(String chatId) {
    final bytes = utf8.encode(chatId);
    final digest = sha256.convert(bytes);
    return encrypt_lib.Key(Uint8List.fromList(digest.bytes));
  }

  static encrypt_lib.IV _generateIV() {
    return encrypt_lib.IV.fromSecureRandom(16);
  }

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

  static String encryptLastMessage(String plainText, String chatId) {
    try {
      final encrypted = encryptMessage(plainText, chatId);
      return '${encrypted['encryptedMessage']}:${encrypted['iv']}';
    } catch (e) {
      return plainText;
    }
  }


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