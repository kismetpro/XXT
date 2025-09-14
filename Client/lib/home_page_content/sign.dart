import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:rounded_expansion_tile/rounded_expansion_tile.dart';
import 'package:xbt_client/main.dart';
import 'package:xbt_client/pages/sign_conf_page.dart';
import 'package:xbt_client/pages/sign_page.dart';
import 'package:xbt_client/utils/constants.dart';
import 'package:xbt_client/utils/datetime_util.dart';
import 'package:badges/badges.dart' as badges;
import 'package:xbt_client/utils/dio.dart';
import 'package:xbt_client/utils/local_json.dart';

class Sign extends StatefulWidget {
  const Sign({super.key});

  @override
  State<Sign> createState() => _SignState();
}

class _SignState extends State<Sign> with RouteAware {
  List<Map<String, dynamic>> selectedClasses = [];
  bool isLoading = false;

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

  void refreshPage() async {
    var localCourses = await LocalJson.getItem("localSelectedClasses");
    // 请求比较慢，先给个本地缓存看着
    if (localCourses != null &&
        localCourses.length > 0 &&
        selectedClasses.isEmpty) {
      selectedClasses = List<Map<String, dynamic>>.from(localCourses);
      setState(() {
        selectedClasses = selectedClasses;
      });
    }
    setState(() {
      isLoading = true;
    });
    var resp =
        await dio.post('$baseURL/getSelectedCourseAndActivityList', data: {});
    if (!resp.data['suc']) {
      SmartDialog.showNotify(
          msg: resp.data['msg'], notifyType: NotifyType.error);
      return;
    }
    selectedClasses = List<Map<String, dynamic>>.from(resp.data['data']);
    for (int i = 0; i < selectedClasses.length; i++) {
      selectedClasses[i]['triggeredLimit'] = false;
      if (selectedClasses[i]['actives'].length > activesLimit) {
        selectedClasses[i]['actives'] =
            selectedClasses[i]['actives'].sublist(0, activesLimit);
        selectedClasses[i]['triggeredLimit'] = true;
      }
      var badgeCount = 0;
      for (int j = 0; j < selectedClasses[i]['actives'].length; j++) {
        selectedClasses[i]['actives'][j]['classId'] =
            selectedClasses[i]['classId'];
        selectedClasses[i]['actives'][j]['courseId'] =
            selectedClasses[i]['courseId'];
        Map record = selectedClasses[i]['actives'][j]['signRecord'];

        var isActive = selectedClasses[i]['actives'][j]['endTime'] >
            DateTime.now().millisecondsSinceEpoch;
        String prefix = isActive
            ? (selectedClasses[i]['actives'][j]['endTime'] == 64060559999000
                ? "进行中(手动结束)"
                : '进行中')
            : "已结束";
        if (record['source'] == 'none') {
          selectedClasses[i]['actives'][j]['subtitle'] = prefix;
        } else if (record['source'] == 'self') {
          selectedClasses[i]['actives'][j]['subtitle'] = '$prefix(本人签到)';
        } else if (record['source'] == 'xxt') {
          selectedClasses[i]['actives'][j]['subtitle'] = '$prefix(学习通)';
        } else if (record['source'] == 'agent') {
          selectedClasses[i]['actives'][j]['subtitle'] =
              '$prefix(${record['sourceName']}代签)';
        }
        selectedClasses[i]['actives'][j]['isActive'] = isActive;
        bool isBadge = (record['source'] == 'none' && isActive);
        selectedClasses[i]['actives'][j]['badge'] = isBadge;
        if (isBadge) badgeCount++;
      }
      selectedClasses[i]['badgeCount'] = badgeCount;
    }
    setState(() {
      isLoading = false;
      selectedClasses = selectedClasses;
    });
    await LocalJson.setItem("localSelectedClasses", selectedClasses);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("签到"),
        elevation: 3,
        shadowColor: Theme.of(context).colorScheme.shadow,
        actions: [
          IconButton(
            icon: const Icon(Icons.rule_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) {
                  return const ConfPage();
                }),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshPage();
        },
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        "课程列表:    ",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 3),
                      ),
                      if (isLoading)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ))
                    ],
                  ),
                  if (selectedClasses.isEmpty)
                    const Text(
                        "暂无课程，请先点击 右上角 图标按钮选择需要开启代签的课程\n选课越少，加载越快，请确保仅选择上课可能会签到的课程！"),
                  for (int i = 0; i < selectedClasses.length; i++)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: RoundedExpansionTile(
                        noTrailing: true,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        leading: badges.Badge(
                          showBadge: selectedClasses[i]['badgeCount'] > 0,
                          badgeContent: Text(
                            selectedClasses[i]['badgeCount'].toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          child: ExtendedImage.network(
                              cache: true,
                              selectedClasses[i]['icon'],
                              headers: IMAGEHEADER,
                              width: 50,
                              height: 50,
                              shape: BoxShape.rectangle,
                              borderRadius: BorderRadius.circular(8),
                              fit: BoxFit.cover, loadStateChanged: (state) {
                            return loadStateChangedfunc(state);
                          }),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                selectedClasses[i]["name"],
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Text(
                              selectedClasses[i]['actives'].length == 0
                                  ? ''
                                  : getChineseStringByDatetime(
                                      DateTime.fromMillisecondsSinceEpoch(
                                          selectedClasses[i]["actives"][0]
                                              ["startTime"])),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        subtitle: Text(
                          selectedClasses[i]["teacher"],
                          style: const TextStyle(fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.grey[300],
                              ),
                              if (selectedClasses[i]['actives'].length == 0)
                                const Text("暂无签到活动"),
                              for (int j = 0;
                                  j < selectedClasses[i]['actives'].length;
                                  j++) ...[
                                ListTile(
                                  selected: selectedClasses[i]['actives'][j]
                                      ['isActive'],
                                  leading: badges.Badge(
                                    showBadge: selectedClasses[i]['actives'][j]
                                        ['badge'],
                                    child: Icon(
                                      SignType.fromId(selectedClasses[i]
                                              ['actives'][j]['signType'])
                                          .icon,
                                      color: selectedClasses[i]['actives'][j]
                                              ['isActive']
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .secondary,
                                    ),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                          child: Text(
                                        SignType.fromId(selectedClasses[i]
                                                ['actives'][j]['signType'])
                                            .name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      )),
                                      Text(
                                        getChineseStringByDatetime(
                                            DateTime.fromMillisecondsSinceEpoch(
                                                selectedClasses[i]['actives'][j]
                                                    ['startTime'])),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    selectedClasses[i]['actives'][j]
                                        ['subtitle'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) {
                                        return SignPage(
                                          courseData: selectedClasses[i],
                                          signData: selectedClasses[i]
                                              ['actives'][j],
                                        );
                                      }),
                                    );
                                  },
                                ),
                                Container(
                                  width: double.infinity,
                                  height: 1,
                                  color: Colors.grey[200],
                                ),
                              ],
                              if (selectedClasses[i]['triggeredLimit'])
                                const Text(
                                  "仅展示最近5条签到活动",
                                  style:
                                      TextStyle(color: Colors.grey, height: 2),
                                ),
                            ],
                          ),
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
