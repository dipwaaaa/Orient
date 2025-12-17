import 'package:flutter/material.dart';
import '/service/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screen/login_signup_screen.dart';

class DeleteAccountDialog extends StatefulWidget {
  final AuthService authService;
  final String userEmail;
  final VoidCallback onDeleteSuccess;

  const DeleteAccountDialog({
    super.key,
    required this.authService,
    required this.userEmail,
    required this.onDeleteSuccess,
  });

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isLoading = false;
  bool _agreedToDelete = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Account?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 20),

              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This action cannot be undone!',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'We will permanently delete all information',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CheckboxListTile(
                  value: _agreedToDelete,
                  onChanged: (value) {
                    setState(() => _agreedToDelete = value ?? false);
                  },
                  title: Text(
                    'I understand this action is permanent and cannot be undone',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  activeColor: Colors.red,
                ),
              ),
              SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _agreedToDelete && !_isLoading ? _handleDelete : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        disabledBackgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _handleDelete() async {
    if (!_agreedToDelete) {
      _showErrorSnackBar('Please confirm that you understand this action');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = widget.authService.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      debugPrint(' Starting account deletion...');

      final result = await widget.authService.deleteAccount(password: '');

      if (!mounted) return;

      if (result['success'] == true) {
        debugPrint('Account deleted successfully');
        _showSuccessMessage();
        await Future.delayed(Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
          );
        }
      } else {
        setState(() => _isLoading = false);
        debugPrint(' Delete failed: ${result['error']}');
        _showErrorSnackBar(result['error'] ?? 'Failed to delete account');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      debugPrint(' Firebase Error: ${e.code} - ${e.message}');

      if (mounted) {
        _showErrorSnackBar('Account deleted. Redirecting to login...');
        await Future.delayed(Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint(' Unexpected error: $e');
      if (mounted) {
        _showErrorSnackBar('An error occurred: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Account deleted successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

