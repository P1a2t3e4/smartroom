import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';

class RoommateAgreementForm extends StatefulWidget {
  const RoommateAgreementForm({super.key});

  @override
  _RoommateAgreementFormState createState() => _RoommateAgreementFormState();
}

class _RoommateAgreementFormState extends State<RoommateAgreementForm> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Controllers for user input
  final TextEditingController roommatesController = TextEditingController();
  final TextEditingController roomLocationController = TextEditingController();
  final TextEditingController roomNumberController = TextEditingController();
  final TextEditingController studyStartController = TextEditingController();
  final TextEditingController studyEndController = TextEditingController();
  final TextEditingController sleepStartController = TextEditingController();
  final TextEditingController sleepEndController = TextEditingController();
  final TextEditingController additionalRulesController = TextEditingController();

  // Cleaning schedule options
  final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Map<String, bool> selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  // Time picker helpers
  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2196F3),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  // Form submission handler
  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isSubmitting = true;
        });

        // Get selected cleaning days
        final List<String> cleaningDays = selectedDays.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();

        if (cleaningDays.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select at least one cleaning day')),
          );
          setState(() {
            _isSubmitting = false;
          });
          return;
        }

        // Get current user details
        String? userId = FirebaseAuth.instance.currentUser?.uid;
        String? userEmail = FirebaseAuth.instance.currentUser?.email;
        if (userId == null) throw Exception("User not logged in!");

        // Generate PDF bytes
        final pdfBytes = await _generatePdfBytes(cleaningDays);

        // Save to Firestore with all necessary information
        DocumentReference docRef = await FirebaseFirestore.instance.collection("roommate_agreements").add({
          "userId": userId,
          "userEmail": userEmail,
          "roommatesNames": roommatesController.text,
          "roomLocation": roomLocationController.text,
          "roomNumber": roomNumberController.text,
          "studyStartTime": studyStartController.text,
          "studyEndTime": studyEndController.text,
          "sleepStartTime": sleepStartController.text,
          "sleepEndTime": sleepEndController.text,
          "cleaningDays": cleaningDays,
          "additionalRules": additionalRulesController.text,
          "timestamp": FieldValue.serverTimestamp(),
          "status": "pending", // Add status for RA to track
          "viewed": false, // Track if RA has viewed the agreement
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agreement submitted successfully! Your RA will be notified.')),
        );

        // Show dialog with options to download PDF or return to dashboard
        setState(() {
          _isSubmitting = false;
        });
        _showSuccessDialog(docRef.id, pdfBytes);

      } catch (error) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  // Show dialog after successful submission
  void _showSuccessDialog(String agreementId, Uint8List pdfBytes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Agreement Submitted'),
          content: const Text(
              'Your roommate agreement has been successfully submitted to your RA. '
                  'Would you like to download a copy for your records?'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Return to previous screen
              },
              child: const Text('RETURN TO DASHBOARD'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _viewPdf(pdfBytes, agreementId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              child: const Text('VIEW & DOWNLOAD PDF'),
            ),
          ],
        );
      },
    );
  }

  // Generate PDF bytes
  Future<Uint8List> _generatePdfBytes(List<String> cleaningDays) async {
    final pdf = pw.Document();

    pdf.addPage(
        pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(30),
            build: (pw.Context context) {
              return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Center(
                        child: pw.Text('ROOMMATE AGREEMENT',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)
                        )
                    ),
                    pw.SizedBox(height: 15),

                    pw.Divider(),
                    pw.SizedBox(height: 10),

                    pw.Text('Date created: ${DateTime.now().toString().split(' ')[0]}',
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)
                    ),
                    pw.SizedBox(height: 15),

                    _buildPdfSection('ROOMMATES', roommatesController.text),

                    _buildPdfSection('ROOM DETAILS',
                        'Location: ${roomLocationController.text}\nRoom Number: ${roomNumberController.text}'
                    ),

                    _buildPdfSection('QUIET HOURS',
                        'Study Hours: ${studyStartController.text} - ${studyEndController.text}\n'
                            'Sleep Hours: ${sleepStartController.text} - ${sleepEndController.text}'
                    ),

                    _buildPdfSection('CLEANING SCHEDULE',
                        'Cleaning Days: ${cleaningDays.join(", ")}'
                    ),

                    _buildPdfSection('ADDITIONAL RULES & AGREEMENTS', additionalRulesController.text),

                    pw.SizedBox(height: 30),

                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('________________________'),
                                pw.Text('Student Signature'),
                                pw.SizedBox(height: 10),
                                pw.Text('Date: ___________________'),
                              ]
                          ),
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('________________________'),
                                pw.Text('RA Signature'),
                                pw.SizedBox(height: 10),
                                pw.Text('Date: ___________________'),
                              ]
                          ),
                        ]
                    )
                  ]
              );
            }
        )
    );

    return pdf.save();
  }

  // View and download PDF
  void _viewPdf(Uint8List pdfBytes, String agreementId) {
    Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'roommate_agreement_$agreementId.pdf',
    );
  }

  // Helper for PDF sections
  pw.Widget _buildPdfSection(String title, String content) {
    return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 3),
          pw.Text(content),
          pw.SizedBox(height: 15),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),
        ]
    );
  }

  // Check if current step is valid
  bool _validateCurrentStep() {
    // For the first step
    if (_currentStep == 0) {
      return roommatesController.text.isNotEmpty &&
          roomLocationController.text.isNotEmpty &&
          roomNumberController.text.isNotEmpty;
    }
    // For the second step
    else if (_currentStep == 1) {
      return studyStartController.text.isNotEmpty &&
          studyEndController.text.isNotEmpty &&
          sleepStartController.text.isNotEmpty &&
          sleepEndController.text.isNotEmpty;
    }
    // For the third step, at least one cleaning day must be selected
    else if (_currentStep == 2) {
      return selectedDays.values.contains(true) &&
          additionalRulesController.text.isNotEmpty;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF2196F3);
    final secondaryColor = Color(0xFF64B5F6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roommate Agreement', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primaryColor.withOpacity(0.05), Colors.white],
              ),
            ),
            child: Form(
              key: _formKey,
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                elevation: 0,
                physics: const ClampingScrollPhysics(),
                controlsBuilder: (context, details) {
                  return Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _currentStep == 2 ? 'SUBMIT' : 'NEXT',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (_currentStep > 0) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSubmitting ? null : details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('BACK'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                onStepContinue: () {
                  setState(() {
                    if (_validateCurrentStep()) {
                      if (_currentStep < 2) {
                        _currentStep += 1;
                      } else {
                        _submitForm();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all required fields')),
                      );
                    }
                  });
                },
                onStepCancel: () {
                  setState(() {
                    if (_currentStep > 0) {
                      _currentStep -= 1;
                    }
                  });
                },
                steps: [
                  Step(
                    title: Text("Room Details", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    content: _buildRoomDetailsStep(),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text("Quiet Hours", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    content: _buildQuietHoursStep(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: Text("Cleaning & Rules", style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                    content: _buildCleaningAndRulesStep(),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  // Step 1: Room Details
  Widget _buildRoomDetailsStep() {
    return Column(
      children: [
        _buildInputField(
          controller: roommatesController,
          label: "Names of All Roommates",
          hint: "Enter full names separated by commas",
          icon: Icons.people,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: roomLocationController,
          label: "Room Location",
          hint: "e.g., North Hall, Building A",
          icon: Icons.location_on,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: roomNumberController,
          label: "Room Number",
          hint: "e.g., 302",
          icon: Icons.room,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  // Step 2: Quiet Hours
  Widget _buildQuietHoursStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Study Hours",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2196F3)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInput(
                      controller: studyStartController,
                      label: "Start Time",
                      icon: Icons.access_time,
                      onTap: () => _selectTime(context, studyStartController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeInput(
                      controller: studyEndController,
                      label: "End Time",
                      icon: Icons.access_time,
                      onTap: () => _selectTime(context, studyEndController),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sleep Hours",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF3F51B5)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInput(
                      controller: sleepStartController,
                      label: "Start Time",
                      icon: Icons.nightlight_round,
                      onTap: () => _selectTime(context, sleepStartController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeInput(
                      controller: sleepEndController,
                      label: "End Time",
                      icon: Icons.wb_sunny,
                      onTap: () => _selectTime(context, sleepEndController),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3: Cleaning Schedule and Rules
  Widget _buildCleaningAndRulesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select Cleaning Days",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2196F3)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: weekdays.map((day) {
              return CheckboxListTile(
                title: Text(day),
                value: selectedDays[day],
                activeColor: Color(0xFF2196F3),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (bool? value) {
                  setState(() {
                    selectedDays[day] = value ?? false;
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _buildInputField(
          controller: additionalRulesController,
          label: "Additional Rules and Agreements",
          hint: "Any additional rules, guest policies, etc.",
          icon: Icons.rule,
          maxLines: 5,
        ),
      ],
    );
  }

  // Helper UI Components
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      validator: (value) => value!.isEmpty ? 'This field is required' : null,
    );
  }

  Widget _buildTimeInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF2196F3)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      readOnly: true,
      onTap: onTap,
      validator: (value) => value!.isEmpty ? 'Required' : null,
    );
  }
}