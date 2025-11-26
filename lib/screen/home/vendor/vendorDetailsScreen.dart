// File: vendorDetailsScreen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ← ADD THIS IMPORT
import '../../../widget/Animated_Gradient_Background.dart';
import '../../../model/vendor_model.dart';

class VendorDetailsScreen extends StatefulWidget {
  final String vendorId;
  final String eventId;

  const VendorDetailsScreen({
    super.key,
    required this.vendorId,
    required this.eventId,
  });

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  late Future<VendorModel?> _vendorFuture;
  bool _isEditMode = false;

  // Controllers will be initialized after data loads
  TextEditingController? _vendorNameController;
  TextEditingController? _phoneController;
  TextEditingController? _emailController;
  TextEditingController? _addressController;
  TextEditingController? _noteController;

  @override
  void initState() {
    super.initState();
    _vendorFuture = _loadVendor();
  }

  Future<VendorModel?> _loadVendor() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('vendors')
          .doc(widget.vendorId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      data['vendorId'] = doc.id; // Important: add ID to map
      return VendorModel.fromMap(data);
    } catch (e) {
      debugPrint('Error loading vendor: $e');
      return null;
    }
  }

  void _initializeControllers(VendorModel vendor) {
    _vendorNameController = TextEditingController(text: vendor.vendorName);
    _phoneController = TextEditingController(text: vendor.phoneNumber ?? "-");
    _emailController = TextEditingController(text: vendor.email ?? "-");
    _addressController = TextEditingController(text: vendor.address ?? "-");
    _noteController = TextEditingController(text: vendor.note ?? "-");
  }

  @override
  void dispose() {
    _vendorNameController?.dispose();
    _phoneController?.dispose();
    _emailController?.dispose();
    _addressController?.dispose();
    _noteController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedGradientBackground()),

          Column(
            children: [
              // Top bar: Close + Edit
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 24),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _isEditMode = !_isEditMode),
                        child: Container(
                          width: 31,
                          height: 31,
                          decoration: const ShapeDecoration(color: Color(0xFFFFE100), shape: OvalBorder()),
                          child: Icon(_isEditMode ? Icons.check : Icons.edit, size: 18, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Image.asset('assets/image/bored.png', height: 180, fit: BoxFit.contain),
              const SizedBox(height: 15),

              // Main content
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                  ),
                  child: FutureBuilder<VendorModel?>(
                    future: _vendorFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFFE100)),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Center(child: Text("Vendor not found"));
                      }

                      final vendor = snapshot.data!;
                      // Initialize controllers only once
                      if (_vendorNameController == null) {
                        _initializeControllers(vendor);
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(45, 43, 45, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor.vendorName,
                              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, fontFamily: 'SF Pro'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              vendor.category,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontFamily: 'SF Pro'),
                            ),
                            const SizedBox(height: 30),

                            _buildField("Vendor Name", _vendorNameController!),
                            const SizedBox(height: 20),
                            _buildField("Phone", _phoneController!),
                            const SizedBox(height: 20),
                            _buildField("E-Mail", _emailController!),
                            const SizedBox(height: 20),
                            _buildField("Address", _addressController!),
                            const SizedBox(height: 20),
                            _buildField("Note", _noteController!, maxLines: 4),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF616161), fontFamily: 'SF Pro'),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 2, color: Color(0xFFFFE100)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextField(
            controller: controller,
            enabled: _isEditMode,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'SF Pro'),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}