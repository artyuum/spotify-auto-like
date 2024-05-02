import 'dart:io';
import 'package:cli_spin/cli_spin.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';

CliSpin showSpinner(String message) {
  final spinner = CliSpin();

  return spinner.start(message);
}

void main() async {
  final credentials = SpotifyApiCredentials('1679eb43d88c4c4c82e2c5d5c002de97', null);
  final grant = SpotifyApi.authorizationCodeGrant(credentials);
  final scopes = [AuthorizationScope.library.read, AuthorizationScope.library.modify];

  final server = await HttpServer.bind(InternetAddress.anyIPv6, 8080);

  final authUri = grant.getAuthorizationUrl(
    Uri.parse('http://localhost:${server.port}'),
    scopes: scopes,
  );

  print('Please click on the authorization link below to allow access to your Spotify library: ');
  print(authUri);

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

    var spinner = showSpinner('Fetching all saved tracks...');

    final savedTracks = await spotify.tracks.me.saved.all();

    final savedTrackIds = [];

    // builds a list of saved tracks IDs
    for (var item in savedTracks) {
      savedTrackIds.add(item.track!.id);
    }

    spinner.success('Found ${savedTrackIds.length} saved tracks.');

    spinner = showSpinner('Fetching all saved albums...');

    final savedAlbums = await spotify.me.savedAlbums().all();
    final trackIdsToAdd = <String>[];

    spinner.success('Found ${savedAlbums.length} saved albums.');

    spinner = showSpinner('Fetching the albums tracks...');

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
      spinner.success('No tracks to save.');
      return;
    }

    spinner.success('Found ${trackIdsToAdd.length} tracks to save.');

    // the API only supports up-to 50 IDs in one request so we partition the list into chunks of 50 IDs
    final chunks = trackIdsToAdd.slices(50);

    spinner = showSpinner('Saving the tracks...');

    for (var ids in chunks) {
      await spotify.tracks.me.save(ids);
    }

    spinner.success('${trackIdsToAdd.length} tracks successfully saved!');
  });
}
