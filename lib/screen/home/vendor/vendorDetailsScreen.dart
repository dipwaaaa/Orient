// vendor_details_screen.dart
import 'package:flutter/material.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import '../../../model/vendor_model.dart';

class VendorDetailsScreen extends StatelessWidget {
  final VendorModel vendor;

  const VendorDetailsScreen({Key? key, required this.vendor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit, color: Colors.white),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          Text("Vendor Name", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.edit, color: Colors.amber), onPressed: () {}),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(vendor.vendorName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 24),
                      _infoRow("For Category", vendor.category),
                      _infoRow("Phone", vendor.phoneNumber ?? "-"),
                      _infoRow("E-Mail", vendor.email ?? "-"),
                      _infoRow("Address", vendor.address ?? "-"),
                      _infoRow("Note", vendor.note ?? "-"),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
          Divider(color: Colors.grey.shade300),
        ],
      ),
    );
  }
}