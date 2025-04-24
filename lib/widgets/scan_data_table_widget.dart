import 'package:flutter/material.dart';
import '../controllers/scanner_controller.dart';

class ScanDataTableWidget extends StatelessWidget {
  final ScannerController controller;

  const ScanDataTableWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Scanned Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton(
              onPressed: () => controller.downloadCsv(context),
              child: const Text('Download CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('QR Data')),
                  DataColumn(label: Text('NFC Data')),
                  DataColumn(label: Text('Action')),
                ],
                rows: [
                  if (controller.pendingRow != null)
                    DataRow(
                      color: MaterialStateProperty.all(Colors.amber.shade50),
                      cells: [
                        DataCell(Text(controller.pendingRow!.timestamp)),
                        DataCell(Text(controller.pendingRow!.qrData)),
                        DataCell(Text(controller.pendingRow!.nfcData)),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => controller.deleteRow(-1), // -1 indicates pending row
                            tooltip: 'Delete row',
                          ),
                        ),
                      ],
                    ),
                  ...List.generate(controller.scannedData.length, (index) {
                      // Get data in reverse order
                      final reversedIndex = controller.scannedData.length - 1 - index;
                      final data = controller.scannedData[reversedIndex];
                      return DataRow(
                        cells: [
                          DataCell(Text(data.timestamp)),
                          DataCell(Text(data.qrData)),
                          DataCell(Text(data.nfcData)),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => controller.deleteRow(reversedIndex),
                              tooltip: 'Delete row',
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} 