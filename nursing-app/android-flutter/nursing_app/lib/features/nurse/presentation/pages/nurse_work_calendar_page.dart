import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';

class NurseWorkCalendarPage extends ConsumerStatefulWidget {
  const NurseWorkCalendarPage({super.key});

  @override
  ConsumerState<NurseWorkCalendarPage> createState() =>
      _NurseWorkCalendarPageState();
}

class _NurseWorkCalendarPageState extends ConsumerState<NurseWorkCalendarPage> {
  final Map<int, List<String>> _slots = {
    1: ['09:00-12:00', '14:00-18:00'],
    2: ['09:00-12:00', '14:00-18:00'],
    3: ['09:00-12:00', '14:00-18:00'],
    4: ['09:00-12:00', '14:00-18:00'],
    5: ['09:00-12:00', '14:00-18:00'],
    6: [],
    7: [],
  };

  bool _isSaving = false;

  static const Map<int, String> _weekText = {
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  @override
  void initState() {
    super.initState();
    _loadFromStorage();
  }

  int get _userId => ref.read(authProvider).user?.id ?? 0;

  String get _storageKey => 'nurse_work_calendar_$_userId';

  void _applySlotsFromRaw(dynamic raw) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day == null || !_slots.containsKey(day)) continue;
      final values = entry.value;
      if (values is List) {
        _slots[day] = values.map((e) => e.toString()).toList();
      }
    }
  }

  void _loadFromStorage() {
    final rawByUser = StorageService.instance.getCache(_storageKey);
    final latestRaw = StorageService.instance.getCache(
      'nurse_work_calendar_latest',
    );

    setState(() {
      _applySlotsFromRaw(rawByUser);
      if (latestRaw is Map) {
        _applySlotsFromRaw(latestRaw['slots']);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final normalizedSlots = <String, List<String>>{};
      for (final entry in _slots.entries) {
        normalizedSlots[entry.key.toString()] = entry.value;
      }

      await StorageService.instance.saveCache(_storageKey, normalizedSlots);
      await StorageService.instance.saveCache('nurse_work_calendar_latest', {
        'updatedAt': DateTime.now().toIso8601String(),
        'userId': _userId,
        'slots': normalizedSlots,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('可接单时段已保存')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickTimeRange(int day) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (start == null || !mounted) return;

    final int suggestedEndHour = start.hour >= 22 ? 23 : start.hour + 2;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: suggestedEndHour, minute: start.minute),
    );
    if (end == null || !mounted) return;

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间需晚于开始时间')));
      return;
    }

    final range =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}-${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

    setState(() {
      final current = [...?_slots[day]];
      if (!current.contains(range)) {
        current.add(range);
        current.sort();
      }
      _slots[day] = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('护士工作日历')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '请设置每周可接单时段，用户预约时将优先匹配该时间窗口。',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textSecondaryColor,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ..._weekText.entries.map((entry) {
            final day = entry.key;
            final slots = _slots[day] ?? [];
            return Card(
              margin: EdgeInsets.only(bottom: 10.h),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _pickTimeRange(day),
                          icon: const Icon(Icons.add_alarm_rounded),
                          label: const Text('新增时段'),
                        ),
                      ],
                    ),
                    if (slots.isEmpty)
                      Text(
                        '未设置可接单时段',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textHintColor,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: slots
                            .map(
                              (slot) => InputChip(
                                label: Text(slot),
                                onDeleted: () {
                                  setState(() {
                                    _slots[day] = slots
                                        .where((e) => e != slot)
                                        .toList();
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_isSaving ? '保存中...' : '保存时段'),
            style: ElevatedButton.styleFrom(minimumSize: Size.fromHeight(46.h)),
          ),
        ),
      ),
    );
  }
}
