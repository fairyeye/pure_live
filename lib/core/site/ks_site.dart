import 'dart:convert';
import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;


import '../danmaku/ks_danmaku.dart';
import '../interface/live_danmaku.dart';
import '../interface/live_site.dart';

class KsSite implements LiveSite {
  @override
  String id = 'ks';

  @override
  String name = '快手';

  @override
  LiveDanmaku getDanmaku() => KsDanmaku();

  static Future<dynamic> _getJson(String url) async {
    var resp = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
        'Host': 'live.kuaishou.com',
        // 'did': 'web_37cfaea58cd0667e3d69096825f93a8f',
        'Cookie':
            'did=web_37cfaea58cd0667e3d69096825f93a8f; kuaishou.live.bfb1s=3e261140b0cf7444a0ba411c6f227d88; clientid=3; did=web_37cfaea58cd0667e3d69096825f93a8f; client_key=65890b29; kpn=GAME_ZONE; didv=1698666042026; userId=2995070576; kuaishou.live.web_st=ChRrdWFpc2hvdS5saXZlLndlYi5zdBKgAdyZ38qVVCmtxZEbg54kLzvYOoG1ZOkFnoWJGJ6g4hVD8CGyYC5skXMb0aq4Zut7vVa8n0gJSroTUNm8a2JnuN5EJrX6pM107nSKtLpV5dIe-uikVHXRW0Dc0xzdRH886TQfgf-TNsyXHv3R55J7waCV5Mhw1FMnZkVLRJVHN_cc0QExlSiZVYMw6UVGwjn_jM047Uno-vHmzTOC7P8f3qQaEo_d-PiuxE4duU2DjxXdbB5BSiIgi8G8_htquxwM6QrSAYtTafaStZTRuvyqZV5OQ7NfUfUoBTAB; kuaishou.live.web_ph=372c927843352d5357179b4c52141dd496b6; userId=2995070576'
      },
    );
    return await jsonDecode(resp.body);
  }

  @override
  Future<Map<String, List<String>>> getLiveStream(LiveRoom room) async {
    Map<String, List<String>> links = {};
    String url = 'https://live.kuaishou.com/live_api/liveroom/livedetail?principalId=${room.roomId}';

    try {
      dynamic response = await _getJson(url);
      Map data = response['data']['liveStream'];
      for (var playUrl in data['playUrls']) {
        Map adaptationSet = playUrl['adaptationSet'];
        for (var repr in adaptationSet['representation']) {
          var qualityType = repr['qualityType'];
          List<String> uris = [];
          uris.add(repr['url']);
          if (qualityType == 'STANDARD') {
            links['标清'] = uris;
            continue;
          }
          if (qualityType == 'HIGH') {
            links['高清'] = uris;
            continue;
          }
          if (qualityType == 'SUPER') {
            links['超清'] = uris;
            continue;
          }
          if (qualityType == 'BLUE_RAY') {
            links['蓝光'] = uris;
            continue;
          }
        }
      }
    } catch (e) {
      log(e.toString(), name: 'KsApi.getRoomStreamLink');
      return links;
    }
    return links;
  }

  @override
  Future<LiveRoom> getRoomInfo(LiveRoom room) async {
    String url = 'https://live.kuaishou.com/live_api/liveroom/livedetail?principalId=${room.roomId}';
    try {
      dynamic response = await _getJson(url);
      Map data = response['data'];
      Map author = data["author"];
      Map liveStream = data["liveStream"];
      Map gameInfo = data["gameInfo"];
      room.userId = room.roomId;
      room.nick = author['name'] ?? '';
      room.title = liveStream['caption'] ?? '';
      room.avatar = author['avatar'] ?? '';
      room.cover = liveStream['poster'] ?? '';
      room.area = gameInfo['categoryName'] ?? '';
      room.watching = gameInfo['watchingCount']?.toString() ?? '';
      room.liveStatus = LiveStatus.live;
    } catch (e) {
      log(e.toString(), name: 'KsApi.getRoomInfo');
      return room;
    }
    return room;
  }

  @override
  Future<List<LiveRoom>> getRecommend({int page = 1, int size = 20}) async {
    List<LiveRoom> list = [];

    try {
      String url = "https://live.kuaishou.com/live_api/hot/list?page=$page&pageSize=$size&type=HOT";
      dynamic response = await _getJson(url);
      dynamic result = response["data"];
      List<dynamic> roomInfoList = result["list"];
      for (var roomInfo in roomInfoList) {
        var author = roomInfo["author"];
        LiveRoom room = LiveRoom(author["id"].toString());
        room.platform = 'ks';
        room.userId = room.roomId;
        room.nick = author["name"] ?? '';
        room.title = roomInfo["caption"] ?? '';
        room.cover = roomInfo["poster"] ?? '';
        room.avatar = author["avatar"] ?? '';
        room.watching = roomInfo["watchingCount"] ?? '';
        room.liveStatus = (roomInfo.containsKey("living")) ? LiveStatus.live : LiveStatus.offline;
        list.add(room);
      }
    } catch (e) {
      log(e.toString(), name: 'KsApi.getRecommend');
      return list;
    }
    return list;
  }

  @override
  Future<List<List<LiveArea>>> getAreaList() async {
    List<List<LiveArea>> areaList = [];
    String url = 'https://live.kuaishou.com/live_api/category/data?page=1&pageSize=15&type=';

    final areas = {
      '1': '热门',
      '4': '手游',
      '2': '网游',
      '3': '单机',
    };
    try {
      for (var typeId in areas.keys) {
        String typeName = areas[typeId]!;
        dynamic response = await _getJson(url + typeId.toString());
        List<LiveArea> subAreaList = [];
        List<dynamic> areaInfoList = response['data']['list'];
        for (var areaInfo in areaInfoList) {
          LiveArea area = LiveArea();
          area.platform = 'ks';
          area.areaType = areaInfo['categoryAbbr'] ?? '';
          area.typeName = typeName;
          area.areaId = areaInfo['id']?.toString() ?? '';
          area.areaName = areaInfo['name'] ?? '';
          area.areaPic = areaInfo['poster'] ?? '';
          subAreaList.add(area);
        }
        areaList.add(subAreaList);
      }
    } catch (e) {
      log(e.toString(), name: 'HuyaApi.getAreaList');
      return areaList;
    }
    return areaList;
  }

  @override
  Future<List<LiveRoom>> getAreaRooms(LiveArea area, {int page = 1, int size = 20}) async {
    List<LiveRoom> list = [];

    String url = 'https://live.kuaishou.com/cate/${area.areaType}/${area.areaId}';

    try {
      dynamic response = await http.get(Uri.parse(url));

      final document = parse(response.body);
      final wmain = document.querySelector('.info m-min-w-mai');
      final h2 = wmain?.querySelector('h2');
      final paragraphs = document.querySelectorAll('.card-info');
      for (final paragraph in paragraphs) {
          final infoMainInfo = paragraph.querySelector('.info-main-info');
          final infoUser = paragraph.querySelector('.info-user');
          final infoBg = paragraph.querySelector('.info-bg');
          final p = infoMainInfo?.querySelector('p');
          final aMainInfo = p?.querySelector('a');
          final aUserInfo = infoUser?.querySelector('a');
          String? coverString = infoBg?.attributes['style'];
          RegExp regExp = RegExp(r'url\(([^)]+)\)');
          Match? cover = regExp.firstMatch(coverString!);
          String u = aMainInfo?.attributes['href'] ?? '';
          // 使用字符串分割方法拆分URL
          List<String> parts = u.split('/');

          LiveRoom room = LiveRoom(parts[2] ?? '');
          room.platform = 'ks';
          room.userId = room.roomId;
          room.nick = aUserInfo?.attributes['title'] ?? '';
          room.title = aMainInfo?.attributes['title'] ?? '';
          room.cover = cover!.group(1)!;
          room.area = h2?.text ?? '';
          room.liveStatus = LiveStatus.live;
          list.add(room);
      }
    } catch (e) {
      log(e.toString(), name: 'HuyaApi.getAreaRooms');
      return list;
    }
    return list;
  }

  @override
  Future<List<LiveRoom>> search(String keyWords) async {
    List<LiveRoom> list = [];
    String url = "https://live.kuaishou.com/live_api/search/author?keyword=$keyWords&page=1&lssid=";
    try {
      dynamic response = await _getJson(url);

      List<dynamic> ownerList = response["data"]["list"];
      for (var ownerInfo in ownerList) {
        LiveRoom owner = LiveRoom(ownerInfo['id'].toString());
        owner.platform = "ks";
        owner.userId = ownerInfo['originUserId']?.toString() ?? '';
        owner.nick = ownerInfo["name"] ?? '';
        owner.title = ownerInfo["description"] ?? '';
        owner.cover = ownerInfo["roomSrc"] ?? '';
        owner.avatar = ownerInfo["avatar"] ?? '';
        owner.area = ownerInfo["cateName"] ?? '';
        owner.watching = ownerInfo["hn"] ?? '';
        owner.liveStatus =
            (ownerInfo.containsKey("living") && ownerInfo["living"] == true)
                ? LiveStatus.live
                : LiveStatus.offline;
        list.add(owner);
      }
    } catch (e) {
      log(e.toString(), name: 'KsApi.search');
      return list;
    }
    return list;
  }
}
