import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/network/employee_provider.dart';
import '../../core/network/providers.dart';
import '../../l10n/app_texts.dart';
import 'profile_repository.dart';

final employeeProfileProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = await ref.watch(frappeClientProvider.future);
  final employeeId = await ref.watch(employeeIdProvider.future);
  
  // Watch locale changes to refresh when language changes
  final locale = ref.watch(appLocaleProvider);
  final preferEnglish = locale.languageCode == 'en';
  
  final empRepo = EmployeeRepository(client);
  return empRepo.getEmployeeProfile(employeeId, preferEnglish: preferEnglish);
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.texts(ref);
    final profile = ref.watch(employeeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profile),
      ),
      body: profile.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF1C4CA5),
                      child: data['image'] != null
                          ? ClipOval(
                              child: Image.network(
                                data['image'] as String,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data['employee_name'] as String? ?? '—',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (data['designation'] != null)
                      Text(
                        data['designation'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Personal Information
              _SectionHeader(title: t.personalInformation),
              _InfoCard(
                icon: Icons.badge_rounded,
                label: t.employeeId,
                value: data['name'] as String? ?? '—',
              ),
              _InfoCard(
                icon: Icons.business_rounded,
                label: t.department,
                value: data['department'] as String? ?? '—',
              ),
              _InfoCard(
                icon: Icons.apartment_rounded,
                label: t.company,
                value: data['company'] as String? ?? '—',
              ),
              if (data['gender'] != null)
                _InfoCard(
                  icon: Icons.person_rounded,
                  label: t.gender,
                  value: data['gender'] as String,
                ),
              if (data['date_of_joining'] != null)
                _InfoCard(
                  icon: Icons.calendar_today_rounded,
                  label: t.dateOfJoining,
                  value: _formatDate(data['date_of_joining'] as String, t),
                ),

              const SizedBox(height: 24),

              // Contact Information
              _SectionHeader(title: t.contactInformation),
              if (data['cell_number'] != null)
                _InfoCard(
                  icon: Icons.phone_rounded,
                  label: t.phone,
                  value: data['cell_number'] as String,
                ),
              if (data['personal_email'] != null)
                _InfoCard(
                  icon: Icons.email_rounded,
                  label: t.email,
                  value: data['personal_email'] as String,
                ),
              if (data['emergency_phone_number'] != null)
                _InfoCard(
                  icon: Icons.emergency_rounded,
                  label: t.emergencyContact,
                  value: data['emergency_phone_number'] as String,
                ),

              const SizedBox(height: 24),

              // Address
              if (data['current_address'] != null || data['permanent_address'] != null)
                _SectionHeader(title: t.address),
              if (data['current_address'] != null)
                _InfoCard(
                  icon: Icons.home_rounded,
                  label: t.currentAddress,
                  value: data['current_address'] as String,
                ),
              if (data['permanent_address'] != null)
                _InfoCard(
                  icon: Icons.location_city_rounded,
                  label: t.permanentAddress,
                  value: data['permanent_address'] as String,
                ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(t.errorLoadingProfile, style: TextStyle(color: Colors.red[700])),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(employeeProfileProvider),
                child: Text(t.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr, AppTexts t) {
    try {
      final date = DateTime.parse(dateStr);
      // Use locale-aware date formatting
      final locale = t.isAr ? 'ar' : 'en';
      return DateFormat(t.isAr ? 'd MMM yyyy' : 'MMM d, yyyy', locale).format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1C4CA5)),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

