import 'package:cafe_system/core/utils/app_constants.dart';
import 'package:cafe_system/features/pos/data/cafe_order.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CafePlaceGrid extends StatelessWidget {
  const CafePlaceGrid({
    super.key,
    required this.tableCount,
    required this.orders,
    required this.onSelect,
    required this.onSelectTakeaway,
    this.placeNames = const {},
    this.placeNotes = const {},
    this.onPlaceNoteTap,
  });

  final int tableCount;
  final List<CafeOrder> orders;
  final void Function(bool isRoom, int number) onSelect;
  final VoidCallback onSelectTakeaway;
  final Map<String, String> placeNames;
  final Map<String, String> placeNotes;
  final void Function(bool isRoom, int number, bool isTakeaway)? onPlaceNoteTap;

  @override
  Widget build(BuildContext context) => GridView.builder(
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 220,
      mainAxisExtent: 150,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: tableCount + 3,
    itemBuilder: (context, index) {
      final place = _placeAt(tableCount, index, orders, placeNames, placeNotes);
      return _CafePlaceTile(
        place: place,
        onTap: place.isTakeaway
            ? onSelectTakeaway
            : () => onSelect(place.isRoom, place.number),
        onEditNote: onPlaceNoteTap == null
            ? null
            : () =>
                  onPlaceNoteTap!(place.isRoom, place.number, place.isTakeaway),
      );
    },
  );
}

class CafePlaceStrip extends StatefulWidget {
  const CafePlaceStrip({
    super.key,
    required this.tableCount,
    required this.orders,
    required this.onSelect,
    required this.onSelectTakeaway,
    this.placeNames = const {},
    this.placeNotes = const {},
    this.onPlaceNoteTap,
    this.selectedTable,
    this.selectedRoom,
    this.selectedTakeaway = false,
  });

  final int tableCount;
  final List<CafeOrder> orders;
  final int? selectedTable;
  final int? selectedRoom;
  final void Function(bool isRoom, int number) onSelect;
  final VoidCallback onSelectTakeaway;
  final bool selectedTakeaway;
  final Map<String, String> placeNames;
  final Map<String, String> placeNotes;
  final void Function(bool isRoom, int number, bool isTakeaway)? onPlaceNoteTap;

  @override
  State<CafePlaceStrip> createState() => _CafePlaceStripState();
}

class _CafePlaceStripState extends State<CafePlaceStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scroll(double direction) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      (_scrollController.offset + direction * 280).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 132,
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    padding: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'الترابيزات والأوض و Take Away',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              IconButton(
                tooltip: 'تمرير لليسار',
                onPressed: () => _scroll(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: MaterialScrollBehavior().copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(9),
                    itemCount: widget.tableCount + 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 7),
                    itemBuilder: (context, index) {
                      final place = _placeAt(
                        widget.tableCount,
                        index,
                        widget.orders,
                        widget.placeNames,
                        widget.placeNotes,
                      );
                      final selected = place.isTakeaway
                          ? widget.selectedTakeaway
                          : place.isRoom
                          ? widget.selectedRoom == place.number
                          : widget.selectedTable == place.number;
                      return _CafePlaceTile(
                        place: place,
                        compact: true,
                        selected: selected,
                        onTap: place.isTakeaway
                            ? widget.onSelectTakeaway
                            : () => widget.onSelect(place.isRoom, place.number),
                        onEditNote: widget.onPlaceNoteTap == null
                            ? null
                            : () => widget.onPlaceNoteTap!(
                                place.isRoom,
                                place.number,
                                place.isTakeaway,
                              ),
                      );
                    },
                  ),
                ),
              ),

              IconButton(
                tooltip: 'تمرير لليمين',
                onPressed: () => _scroll(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CafePlaceTile extends StatelessWidget {
  const _CafePlaceTile({
    required this.place,
    required this.onTap,
    this.onEditNote,
    this.compact = false,
    this.selected = false,
  });

  final _CafePlace place;
  final VoidCallback onTap;
  final VoidCallback? onEditNote;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final reserved = place.isTakeaway
        ? place.order?.items.isNotEmpty == true
        : place.order != null;
    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: place.isTakeaway
              ? 100
              : place.isRoom
              ? 106
              : 78,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green
                : reserved
                ? const Color(0xFFC62828)
                : const Color(0xFFF2F5F2),
            borderRadius: BorderRadius.circular(10),
            border: place.isRoom
                ? Border.all(
                    color: selected ? AppColors.green : const Color(0xFFE6C59F),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    place.icon,
                    size: 18,
                    color: selected || reserved
                        ? Colors.white
                        : AppColors.green,
                  ),
                  if (onEditNote != null)
                    IconButton(
                      tooltip: 'ملاحظة المكان',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onEditNote,
                      icon: const Icon(Icons.note_alt_outlined, size: 16),
                      color: AppColors.green,
                    ),
                ],
              ),
              Text(
                place.shortName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: selected || reserved ? Colors.white : AppColors.ink,
                ),
              ),
              Text(
                place.status,
                style: TextStyle(
                  fontSize: 9,
                  color: selected || reserved ? Colors.white70 : Colors.black54,
                ),
              ),
              if (place.note?.isNotEmpty == true)
                Text(
                  place.note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 8,
                    color: selected || reserved
                        ? Colors.white70
                        : AppColors.ink,
                  ),
                ),
              if (place.isRoom && place.order?.hasRoomSession == true)
                Text(
                  'بدأت ${_formatClock(place.order!.roomStartedAt!)}',
                  style: TextStyle(
                    fontSize: 9,
                    color: selected || reserved
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: reserved ? const Color(0xFFC62828) : Colors.white,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  place.icon,
                  color: reserved ? Colors.white : AppColors.green,
                ),
                if (onEditNote != null)
                  IconButton(
                    tooltip: 'ملاحظة الترابيزة',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onEditNote,
                    icon: const Icon(Icons.note_alt_outlined),
                    color: AppColors.green,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: reserved ? Colors.white : AppColors.ink,
              ),
            ),
            Text(
              place.status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: reserved ? Colors.white70 : null),
            ),
            if (place.note?.isNotEmpty == true)
              Text(
                place.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: reserved ? Colors.white70 : AppColors.green,
                ),
              ),
            if (place.isRoom && place.order?.hasRoomSession == true)
              Text(
                'بدأت ${_formatClock(place.order!.roomStartedAt!)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: reserved ? Colors.white70 : Colors.black54,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CafePlace {
  const _CafePlace({
    required this.isRoom,
    required this.number,
    this.order,
    this.isTakeaway = false,
    this.customName,
    this.note,
  });

  final bool isRoom;
  final int number;
  final CafeOrder? order;
  final bool isTakeaway;
  final String? customName;
  final String? note;

  String get name =>
      customName ??
      (isTakeaway
          ? 'Take Away'
          : isRoom
          ? 'أوضة بلايستيشن $number'
          : 'ترابيزة $number');
  String get shortName =>
      customName ??
      (isTakeaway
          ? 'Take Away'
          : isRoom
          ? 'بلايستيشن $number'
          : 'ترابيزة $number');
  IconData get icon => isTakeaway
      ? Icons.takeout_dining
      : isRoom
      ? Icons.sports_esports
      : Icons.table_restaurant;
  String get status => order == null
      ? 'فارغة'
      : order!.hasRoomSession
      ? '${_formatDuration(order!.roomDurationMinutesAt(DateTime.now()))} • ${order!.roomCharge.toStringAsFixed(0)} ج.م'
      : '${order!.total.toStringAsFixed(0)} ج.م';
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatClock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

_CafePlace _placeAt(
  int tableCount,
  int index,
  List<CafeOrder> orders,
  Map<String, String> names,
  Map<String, String> notes,
) {
  if (index == tableCount + 2) {
    final order = orders.where((item) => item.isTakeaway).firstOrNull;
    return _CafePlace(
      isRoom: false,
      number: 0,
      order: order,
      isTakeaway: true,
      note: notes['takeaway'],
    );
  }
  final isRoom = index >= tableCount;
  final number = isRoom ? index - tableCount + 1 : index + 1;
  final order = orders
      .where(
        (item) => isRoom
            ? item.roomNumber == number &&
                  (item.items.isNotEmpty || item.hasRoomSession)
            : item.tableNumber == number && item.items.isNotEmpty,
      )
      .firstOrNull;
  final kind = isRoom ? 'room' : 'table';
  return _CafePlace(
    isRoom: isRoom,
    number: number,
    order: order,
    customName: names['${kind}_$number'],
    note: notes['${isRoom ? 'room' : 'table'}_$number'],
  );
}
