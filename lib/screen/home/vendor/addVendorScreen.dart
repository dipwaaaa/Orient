// add_vendor_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widget/Animated_Gradient_Background.dart';
import '../../../model/vendor_model.dart';

class AddVendorScreen extends StatefulWidget {
  final String eventId;
  final String listName;

  const AddVendorScreen({Key? key, required this.eventId, required this.listName}) : super(key: key);

  @override
  State<AddVendorScreen> createState() => _AddVendorScreenState();
}

class _AddVendorScreenState extends State<AddVendorScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String phone = '';
  String email = '';
  String address = '';
  String selectedCategory = 'Unassigned';
  String selectedStatus = 'Not Contacted';

  final categories = [
    'Unassigned', 'Attire & Accessories', 'Food And Beverages', 'Music & Show',
    'Flowers & Decor', 'Photo & Video', 'Transportation', 'Accomodation'
  ];

  final statuses = ['Not Contacted', 'Contacted', 'Reserved', 'Rejected'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Add a Vendor",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        _buildTextField("Name", (v) => name = v!),
                        const SizedBox(height: 16),
                        _buildTextField("Phone", (v) => phone = v!, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        _buildTextField("E-Mail", (v) => email = v!, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField("Address", (v) => address = v!, maxLines: 3),

                        const SizedBox(height: 24),
                        const Text("Category", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories.map((cat) {
                            return ChoiceChip(
                              label: Text(cat),
                              selected: selectedCategory == cat,
                              onSelected: (_) => setState(() => selectedCategory = cat),
                              selectedColor: Colors.amber,
                              backgroundColor: Colors.grey.shade200,
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),
                        const Text("Status", style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          children: statuses.map((status) {
                            return ChoiceChip(
                              label: Text(status),
                              selected: selectedStatus == status,
                              onSelected: (_) => setState(() => selectedStatus = status),
                              selectedColor: Colors.amber,
                              backgroundColor: Colors.grey.shade200,
                              avatar: status == 'Rejected'
                                  ? const Icon(Icons.close, size: 18)
                                  : null,
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 32),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          onPressed: () async {
                            if (name.isNotEmpty) {
                              final vendor = VendorModel(
                                vendorId: FirebaseFirestore.instance.collection('temp').doc().id,
                                eventId: widget.eventId,
                                vendorName: name,
                                category: selectedCategory,
                                phoneNumber: phone.isEmpty ? null : phone,
                                email: email.isEmpty ? null : email,
                                address: address.isEmpty ? null : address,
                                totalCost: 0.0,
                                paidAmount: 0.0,
                                pendingAmount: 0.0,
                                agreementStatus: selectedStatus,
                                addToBudget: false,
                                payments: [],
                                listName: widget.listName,
                                createdBy: "current_user_id", // replace with auth user
                                createdAt: DateTime.now(),
                                lastUpdated: DateTime.now(),
                              );

                              await FirebaseFirestore.instance
                                  .collection('events')
                                  .doc(widget.eventId)
                                  .collection('vendors')
                                  .doc(vendor.vendorId)
                                  .set(vendor.toMap());

                              Navigator.pop(context);
                            }
                          },
                          child: const Text("Save Vendor", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
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

  Widget _buildTextField(String label, FormFieldSetter<String> onSaved, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      onSaved: onSaved,
      onChanged: onSaved,
    );
  }
}