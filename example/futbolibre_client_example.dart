
import 'package:futbolibre_client/src/futbolibre_client_base.dart';

void main() async{
  var client = FutbolibreClient();
  var events = await client.getSportEvents();
  for (var event in events) {
    for (var server in event.videoServers) {
      print("${event.name} ${server.url}");
      var directLink = await client.getDirectLink(server.url);
      print(directLink.url);
    }
  }
}
