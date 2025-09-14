import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xbt_client/main.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/debounce.dart';
import 'package:xbt_client/utils/dio.dart';
import 'package:xbt_client/utils/local_json.dart';

class ConfPage extends StatefulWidget {
  const ConfPage({super.key});
  @override
  State<ConfPage> createState() => _ConfPageState();
}

class _ConfPageState extends State<ConfPage> with RouteAware {
  List<Map<String, dynamic>> allCourses = [];
  late var setCourseSelectStateDebounced =
      debounce(setCourseSelectState, const Duration(milliseconds: 222));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MyApp.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    refreshPage();
  }

  @override
  void dispose() {
    MyApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void initState() {
    refreshPage();
    super.initState();
  }

  Future<void> refreshPage({sync = false}) async {
    if (!sync) {
      var localCourses = await LocalJson.getItem("localCourses");
      if (localCourses != null && localCourses.length > 0) {
        allCourses = List<Map<String, dynamic>>.from(localCourses);
        allCourses.sort((a, b) {
          if (a["isSelected"] == b["isSelected"]) {
            return a["name"].compareTo(b["name"]);
          }
          if (a["isSelected"]) {
            return -1;
          }
          return 1;
        });
        setState(() {
          allCourses = allCourses;
        });
        return;
      }
      var token = await prefs.getString('token');
      if (token != null && token.isNotEmpty)
        SmartDialog.showLoading(msg: '加载中');
    }
    var resp = await dio.post('$baseURL/getAllCourse', data: {
      'sync': sync,
    });
    allCourses.clear();
    resp.data["data"].forEach((course) {
      allCourses.add({
        "name": course["name"],
        "teacher": course["teacher"],
        "icon": course["icon"],
        "isSelected": course["isSelected"] == 1,
        "courseId": course["courseId"],
        "classId": course["classId"],
      });
    });
    await LocalJson.setItem("localCourses", allCourses);
    allCourses.sort((a, b) {
      if (a["isSelected"] == b["isSelected"]) {
        return a["name"].compareTo(b["name"]);
      }
      if (a["isSelected"]) {
        return -1;
      }
      return 1;
    });
    setState(() {
      allCourses = allCourses;
    });
    SmartDialog.dismiss();
    SmartDialog.showToast('三端数据同步成功');
  }

  void setCourseSelectState() async {
    await dio.post("$baseURL/setCourseSelectState", data: {
      "courses": allCourses,
    });
    await LocalJson.setItem("localCourses", allCourses);
  }

  void onCourseTap(int index) {
    allCourses[index]["isSelected"] = !allCourses[index]["isSelected"];
    setState(() {
      allCourses = allCourses;
    });
    setCourseSelectStateDebounced();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("配置"),
        elevation: 3,
        shadowColor: Theme.of(context).colorScheme.shadow,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await refreshPage(sync: true);
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "选择需要代签课程:",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, height: 3),
                  ),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < allCourses.length; i++) ...[
                          ListTile(
                            title: Text(
                              allCourses[i]["name"],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              allCourses[i]["teacher"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: ExtendedImage.network(
                              cache: true,
                              allCourses[i]["icon"],
                              headers: IMAGEHEADER,
                              width: 42,
                              height: 42,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(8),
                              fit: BoxFit.cover,
                              loadStateChanged: (state) {
                                return loadStateChangedfunc(state);
                              },
                            ),
                            trailing: Switch(
                              onChanged: (v) {
                                onCourseTap(i);
                              },
                              value: allCourses[i]["isSelected"],
                            ),
                            onTap: () {
                              onCourseTap(i);
                            },
                          )
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
