import 'dart:async';

Function debounce(Function func, Duration dur) {
  Timer? timer;
  return ([List<dynamic>? args]) {
    if (timer != null) {
      timer!.cancel();
    }
    timer = Timer(dur, () {
      Function.apply(func, args);
    });
  };
}
