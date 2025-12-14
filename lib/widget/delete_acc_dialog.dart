import 'package:flutter/material.dart';
import 'package:untitled/service/auth_service.dart';

class DeleteAccountDialog extends StatefulWidget {
  final AuthService authService;
  final bool hasPassword;
  final String userEmail;
  final VoidCallback onDeleteSuccess;

  const DeleteAccountDialog({
    Key? key,
    required this.authService,
    required this.hasPassword,
    required this.userEmail,
    required this.onDeleteSuccess,
  }) : super(key: key);

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _agreedToDelete = false;
  bool _obscurePassword = true;
  int _step = 0; // 0: Warning, 1: Confirmation, 2: Password

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _proceedWithDeletion() async {
    if (!widget.hasPassword) {
      // Google-only account, proceed directly
      await _performDeletion('');
      return;
    }

    // Password-protected account, validate password
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar('Please enter your password');
      return;
    }

    await _performDeletion(_passwordController.text);
  }

  Future<void> _performDeletion(String password) async {
    setState(() => _isLoading = true);

    try {
      final result = await widget.authService.deleteAccount(
        password: password,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccessMessage();
        // Small delay to show success message before navigation
        await Future.delayed(Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog
          widget.onDeleteSuccess();
        }
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(result['error'] ?? 'Failed to delete account');
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
              // Header
              Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _step == 0
                          ? 'Delete Account?'
                          : _step == 1
                          ? 'Confirm Deletion'
                          : 'Verify Your Password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (_step == 0)
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                ],
              ),
              SizedBox(height: 20),

              // Content based on step
              if (_step == 0) ...[
                _buildWarningContent(),
              ] else if (_step == 1) ...[
                _buildConfirmationContent(),
              ] else ...[
                _buildPasswordContent(),
              ],

              SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _step--),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_step > 0) SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleNextOrDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _step == 2 ? Colors.red : Colors.orange,
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
                          valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Text(
                        _step == 2
                            ? 'Delete Permanently'
                            : _step == 1
                            ? 'Continue'
                            : 'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_step == 0)
                SizedBox(height: 12),
              if (_step == 0)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action cannot be undone!',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'We will permanently delete:',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              _buildWarningItem('Your account and profile'),
              _buildWarningItem('All events you created'),
              _buildWarningItem('All messages and chats'),
              _buildWarningItem('Profile pictures and data'),
              _buildWarningItem('All personal information'),
            ],
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Email: ${widget.userEmail}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(Icons.close, color: Colors.red.shade700, size: 16),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Are you absolutely sure?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Please confirm that you want to permanently delete your account and all associated data. This cannot be reversed.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
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
              'I understand that this action is permanent',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For security reasons, please verify your password:',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 18,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
      ],
    );
  }

  void _handleNextOrDelete() {
    if (_step == 0) {
      setState(() => _step = 1);
    } else if (_step == 1) {
      if (!_agreedToDelete) {
        _showErrorSnackBar('Please confirm that you understand this action');
        return;
      }
      setState(() => _step = 2);
    } else if (_step == 2) {
      _proceedWithDeletion();
    }
  }
}