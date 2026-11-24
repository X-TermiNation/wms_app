import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../application/constants/app_colors.dart';
import 'app_status_badge.dart';

/// Banner ringkasan di atas daftar transaksi.
class SummaryBanner extends StatelessWidget {
  const SummaryBanner({super.key, required this.icon, required this.title, required this.value, this.subtitle});
  final IconData icon;
  final String title, value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.darkOrange]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 36),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800))),
        if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ])),
    ]),
  );
}

/// Chip filter status (label UI). Nilai terpilih disimpan di [selected].
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({super.key, required this.options, required this.selected});
  final List<String> options;
  final RxString selected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: Obx(() => ListView(
      scrollDirection: Axis.horizontal,
      children: options.map((s) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(
          label: Text(s, style: const TextStyle(fontSize: 11)),
          selected: selected.value == s,
          selectedColor: AppColors.softOrange,
          onSelected: (_) => selected.value = s,
        ),
      )).toList(),
    )),
  );
}

/// Kartu dokumen transaksi pada daftar.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.icon,
    required this.number,
    required this.date,
    required this.statusLabel,
    required this.statusColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.menu = const [],
    this.onMenu,
  });

  final IconData icon;
  final String number, date, statusLabel, title, subtitle, trailing;
  final Color statusColor;
  final VoidCallback onTap;
  final List<PopupMenuEntry<String>> menu;
  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.softOrange, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(date, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ])),
              AppStatusBadge(label: statusLabel, color: statusColor),
              if (menu.isNotEmpty)
                PopupMenuButton<String>(onSelected: onMenu, itemBuilder: (_) => menu)
              else
                const SizedBox(width: 10),
            ]),
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Colors.black54))),
                  const SizedBox(width: 6),
                  Text(trailing, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.charcoal)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Bottom sheet detail standar.
Future<void> showDetailSheet({required String title, Widget? badge, required List<Widget> children, List<Widget> actions = const []}) =>
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * .86),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: [
                Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(5)))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  ?badge,
                ]),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
          if (actions.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 9),
                    Expanded(child: actions[i]),
                  ],
                ]),
              ),
            ),
        ]),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );

/// Judul bagian di dalam detail.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
  );
}

/// Baris item sederhana (nama, keterangan, qty).
class ItemLine extends StatelessWidget {
  const ItemLine({super.key, required this.title, required this.subtitle, required this.trailing, this.onRemove});
  final String title, subtitle, trailing;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: EdgeInsets.fromLTRB(11, 9, onRemove == null ? 11 : 2, 9),
    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
      ])),
      const SizedBox(width: 6),
      Text(trailing, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
      if (onRemove != null)
        IconButton(visualDensity: VisualDensity.compact, onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20)),
    ]),
  );
}
