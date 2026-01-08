import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';

// Note: Documents might be stored in various doctypes in ERPNext
// Common options: Employee Document, File, or custom doctype
// This is a placeholder that can be extended based on your ERPNext setup

final documentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // Placeholder - implement based on your ERPNext document doctype
  // Example: If using Employee Document doctype
  try {
    final client = await ref.watch(frappeClientProvider.future);
    final employeeId = await ref.watch(employeeIdProvider.future);
    
    // Try to fetch from Employee Document doctype
    final res = await client.dio.get(
      '/api/resource/Employee Document',
      queryParameters: {
        'fields': '["name","employee","document_name","document_type","valid_from","valid_until","file_url"]',
        'filters': '[["employee","=","$employeeId"]]',
        'order_by': 'valid_from desc',
        'limit_page_length': 50,
      },
    );
    final data = (res.data is Map) ? (res.data['data'] as List?) : null;
    if (data != null && data.isNotEmpty) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  } catch (e) {
    // If Employee Document doctype doesn't exist or isn't accessible, return empty
    return [];
  }
});

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final documents = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.documents),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(documentsProvider.future),
        child: documents.when(
          data: (items) => items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No documents found', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text(
                        'Documents will appear here once configured in ERPNext',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: items.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => _DocumentCard(document: items[index]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading documents', style: TextStyle(color: Colors.red[700])),
                const SizedBox(height: 8),
                Text(
                  'Note: Documents feature requires Employee Document doctype in ERPNext',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.refresh(documentsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document});

  final Map<String, dynamic> document;

  @override
  Widget build(BuildContext context) {
    final docName = document['document_name'] as String? ?? 'Document';
    final docType = document['document_type'] as String?;
    final validFrom = document['valid_from'] as String?;
    final validUntil = document['valid_until'] as String?;
    final fileUrl = document['file_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1C4CA5).withOpacity(0.1),
          child: const Icon(Icons.description_rounded, color: Color(0xFF1C4CA5)),
        ),
        title: Text(
          docName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (docType != null) Text('Type: $docType'),
            if (validFrom != null) Text('Valid from: ${_formatDate(validFrom)}'),
            if (validUntil != null) Text('Valid until: ${_formatDate(validUntil)}'),
          ],
        ),
        trailing: fileUrl != null
            ? IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: () {
                  // TODO: Implement document download
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download feature coming soon')),
                  );
                },
              )
            : null,
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

