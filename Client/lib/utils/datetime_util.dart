DateTime getZeroOclockOfDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

String padLeft(int num, [int length = 2, String fill = '0']) {
  return num.toString().padLeft(length, '0');
}

String getChineseStringByDatetime(DateTime dateTime, [DateTime? now]) {
  now ??= DateTime.now();
  if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
    // 同一天
    int min = now.hour * 60 + now.minute - dateTime.hour * 60 - dateTime.minute;
    if (min <= 1) return '刚刚';
    if (min < 60) return '$min分钟前';
    return '${now.hour - dateTime.hour}小时前';
  }
  // 不同天
  int day = getZeroOclockOfDay(now).difference(getZeroOclockOfDay(dateTime)).inDays;
  if (day <= 0) return '未来(请检查本机系统时间)';
  if (day == 1) return '昨天${padLeft(dateTime.hour)}:${padLeft(dateTime.minute)}';
  if (day == 2) return '前天';
  if (day <= 7) {
    return '$day天前';
  }
  // if (dateTime.year == now.year) {
  //   return '${padLeft(dateTime.month)}-${padLeft(dateTime.day)}';
  // }
  return '${dateTime.year}-${padLeft(dateTime.month)}-${padLeft(dateTime.day)}';
}
