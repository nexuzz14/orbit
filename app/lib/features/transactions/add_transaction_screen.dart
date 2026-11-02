import 'package:flutter/material.dart';
import 'package:orbit_app/core/widgets/transaction_form_sheet.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
      ),
      body: const SafeArea(
        child: TransactionFormSheet(),
      ),
    );
  }
}
