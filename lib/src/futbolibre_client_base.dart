import 'dart:convert';

import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:dio/dio.dart';

final String baseUrl = "https://futbollibre.futbol";

class VideoServer{
  String name;
  String url;
  String quality;
  VideoServer(this.name, this.url, this.quality);
  @override
  String toString() {
    return "$name ($quality)";
  }
}

class SportEvent {
  String name;
  DateTime? date;
  List<VideoServer> videoServers;
  SportEvent(this.name, this.videoServers, this.date);
  @override
  String toString() {
    return "$name ${videoServers.join(", ")}";
  }
}
class DirectLink {
  String url;
  Map<String, String> headers;
  DirectLink(this.url, this.headers);
}
class FutbolibreClient {

  String ? _testForClappr(String data, String url){
    var regex = RegExp("Clappr.Player\\s*\\(\\s*{\\s*source\\s*:\\s*(['\"])(([^'\"]+))\\1", multiLine: true);
    var match = regex.firstMatch(data);
    if (match == null) {
      return null;
    }
    var source = match.group(2)!;
    return source;
  }

  String? _testForGolazo(String data, String url){
    var uri = Uri.parse(url);
    var id = uri.queryParameters['id'];
    if (id == null) {
      return null;
    }
    String ?source;
    var regex = RegExp("id\\s*==\\s*(['\"])$id\\1[wW]*url\\s*=\\s*(['\"])(([^'\"]+))\\2", multiLine: true);
    var match = regex.firstMatch(data);
    if (match == null) {
      regex = RegExp("id\\s*==\\s*(['\"])$id\\1[wW]*url\\s*=\\s*atob\\((['\"])(([^'\"]+))\\2", multiLine: true);
      match = regex.firstMatch(data);
      if (match == null) {
        return null;
      }
      else{
        String encoded = match.group(3)!;
        source = utf8.decode(base64Decode(encoded));
        //TODO: add drm keys to source
      }

    }
    else{
      source = match.group(2)!;
    }
    return source;
  }

  Future<DirectLink> getDirectLink(String url) async {
    var dio = Dio();
    var response = await dio.get(url);
    var data = response.data;
    var testers = <String? Function(String, String)>[
      _testForClappr,
      _testForGolazo
    ];
    String? source;
    for (var tester in testers) {
      source = tester(data, url);
      if (source != null) {
        break;
      }
    }
    if (source == null) {
      throw Exception("Could not find source");
    }
    return DirectLink(source, {});
  }

  Future<List<SportEvent>> getSportEvents() async {
    var dio = Dio();
    var response = await dio.get(baseUrl);
    var data = response.data;
    var regex = RegExp("<iframe [^>]*src\\s*=\\s*(['\"])(([^'\"]+))\\1[^>]*>", multiLine: true);
    var match = regex.firstMatch(data);
    if (match == null) {
      throw Exception("Could not find iframe");
    }
    var scheduleUrl = match.group(2)!;
    var uri = Uri.parse(scheduleUrl);
    response = await dio.get(scheduleUrl);
    var soup = BeautifulSoup(response.data);
    var events = soup.findAll("", selector: ".menu > li");
    var sportEvents = <SportEvent>[];

    for (var event in events) {
      var name = event.a?.nodes[0].text?.trim() ?? "Unknown";
      var servers = event.findAll("", selector: "li.subitem1");
      var videoServers = <VideoServer>[];
      for (var server in servers) {
        var title = server.a?.nodes[0].text?.trim() ?? "Unknown";
        var quality = server.a?.nodes[1].text?.trim() ?? "Unknown";
        var url = server.a?.attributes["href"]!.trim();
        var tempUrl = uri.resolve(url!);
        late String realUrl;
        if (tempUrl.queryParameters["embed"] != null) {
          realUrl =  utf8.decode(base64Decode(tempUrl.queryParameters["embed"]!));
        } else if (tempUrl.queryParameters["r"] != null) {
          realUrl =  utf8.decode(base64Decode(tempUrl.queryParameters["r"]!));
        }
        else{
          continue;
        }
        var videoServer = VideoServer(title, realUrl.toString(), quality);
        videoServers.add(videoServer);
      }
      sportEvents.add(SportEvent(name, videoServers, null));
    }
    return sportEvents;
  }
}