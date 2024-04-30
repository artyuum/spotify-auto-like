import 'dart:io';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

void main() async {
  final credentials = SpotifyApiCredentials('1679eb43d88c4c4c82e2c5d5c002de97', null);
  final grant = SpotifyApi.authorizationCodeGrant(credentials);
  final scopes = [AuthorizationScope.library.read, AuthorizationScope.library.modify];

  final authUri = grant.getAuthorizationUrl(
    Uri.parse('http://localhost:8080'),
    scopes: scopes,
  );

  print(authUri);

  final server = await HttpServer.bind(InternetAddress.anyIPv6, 8080);
  await server.forEach((HttpRequest request) async {
    final code = request.uri.queryParameters['code'];

    if (code == null) {
      final message = 'Authorization code is missing.';

      request.response.statusCode = 400;
      request.response.write(message);
      request.response.close();

      return;
    }

    request.response.headers.contentType = ContentType.html;
    request.response.write('<script>window.close();</script>');
    request.response.close();

    server.close();

    final spotify = SpotifyApi.fromAuthCodeGrant(grant, request.uri.toString());

    print('Fetching the currently saved tracks...');

    final savedTracks = await spotify.tracks.me.saved.all();

    print('Found ${savedTracks.length} saved tracks.');

    final savedTrackIds = [];

    // builds a list of saved tracks IDs
    for (var item in savedTracks) {
      savedTrackIds.add(item.track!.id);
    }

    print('Fetching the currently saved albums...');

    final savedAlbums = await spotify.me.savedAlbums().all();
    final trackIdsToAdd = <String>[];

    print('Looping through ${savedAlbums.length} saved albums tracks...');

    // loops through all saved albums and check if there are some tracks missing from the saved tracks playlist
    for (var item in savedAlbums) {
      final tracks = await spotify.albums.getTracks(item.id!).all();

      for (var item in await tracks) {
        // skips already saved tracks
        if (savedTrackIds.contains(item.id!)) {
          continue;
        }

        trackIdsToAdd.add(item.id!);
      }
    }

    if (trackIdsToAdd.isEmpty) {
      print('No tracks to save');
    } else {
      print('${trackIdsToAdd.length} tracks to save.');

      // the API only supports up-to 50 IDs in one request so we partition the list into chunks of 50 IDs
      final chunks = trackIdsToAdd.slices(50);

      for (var ids in chunks) {
        await spotify.tracks.me.save(ids);
      }
    }
  });
}
