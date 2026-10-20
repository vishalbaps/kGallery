import 'dart:convert';

/// JavaScript that enforces the caption state in a youtube_player_flutter
/// WebView, whose IFrame player is the global `player`.
///
/// `cc_load_policy` (`YoutubePlayerFlags.enableCaption`) only stops the player
/// from forcing captions on; YouTube still shows them when the uploader set a
/// default track or the WebView holds a sticky caption preference. The state is
/// therefore applied through the IFrame API. Off clears the `track` option and
/// calls `unloadModule('captions')`: the module stays listed after an unload, so
/// the unload alone can leave captions showing. On loads the module and selects
/// the preferred language.
///
/// The captions module loads only after playback starts, so applying the state
/// on ready alone can be a no-op. The first run in a WebView installs listeners
/// that re-apply it on the first "playing" state and whenever the module loads
/// (`onApiChange`). That bookkeeping lives on `window`, so it is per WebView: a
/// fullscreen enter/exit swaps in a fresh page and the next run installs it
/// again. Later runs in the same WebView only update and apply the state, so the
/// script is safe to evaluate repeatedly.
String youtubeCaptionsScript({
  required bool enabled,
  required String languageCode,
}) {
  return '$_script(${enabled ? 'true' : 'false'}, ${jsonEncode(languageCode)});';
}

// ES5 only: older Android System WebViews run this too.
const String _script = r'''
(function (on, lang) {
  var kg = window.kGalleryCaptions;
  if (!kg) {
    kg = window.kGalleryCaptions = {
      hooked: false, played: false, loaded: false, applying: false, reloads: 0
    };

    kg.ready = function () {
      return typeof player !== 'undefined' && player !== null &&
          typeof player.getOptions === 'function';
    };

    // Name of the loaded captions module, or null while it isn't loaded.
    kg.module = function () {
      var opts = [];
      try { opts = player.getOptions() || []; } catch (e) {}
      if (opts.indexOf('captions') >= 0) return 'captions';
      if (opts.indexOf('cc') >= 0) return 'cc';
      return null;
    };

    kg.tracks = function (m) {
      try { return player.getOption(m, 'tracklist') || []; } catch (e) { return []; }
    };

    // Exact language first ('en-GB'), then the base language ('en').
    kg.pick = function (list) {
      var want = String(kg.lang).toLowerCase();
      var base = want.split('-')[0];
      var i;
      for (i = 0; i < list.length; i++) {
        if (String(list[i].languageCode).toLowerCase() === want) return list[i];
      }
      for (i = 0; i < list.length; i++) {
        if (String(list[i].languageCode).toLowerCase().split('-')[0] === base) {
          return list[i];
        }
      }
      return null;
    };

    // Selects the preferred language. The track list leaves out
    // auto-generated tracks, and asking for a language the video lacks shows
    // nothing, so without a listed match the module is reloaded instead: that
    // makes YouTube select its own default track, auto-generated included.
    // At most one reload per state change, so onApiChange can't loop on it.
    kg.show = function (m) {
      var track = kg.pick(kg.tracks(m));
      if (track) {
        player.setOption(m, 'track', track);
      } else if (kg.reloads < 1) {
        kg.reloads++;
        player.unloadModule(m);
        player.loadModule(m);
      }
    };

    kg.apply = function () {
      // onApiChange can fire synchronously inside load/unloadModule below.
      if (kg.applying || !kg.ready()) return;
      kg.applying = true;
      try {
        if (kg.on) {
          if (!kg.module()) player.loadModule('captions');
          // If the module loads asynchronously, onApiChange shows the track.
          var m = kg.module();
          if (m) kg.show(m);
        } else {
          var cur = kg.module();
          if (cur) player.setOption(cur, 'track', {});
          player.unloadModule(cur || 'captions');
        }
      } catch (e) {}
      kg.applying = false;
      kg.loaded = kg.module() !== null;
    };

    kg.hook = function (attempt) {
      if (kg.hooked) return;
      if (!kg.ready()) {
        if (attempt < 50) setTimeout(function () { kg.hook(attempt + 1); }, 200);
        return;
      }
      kg.hooked = true;
      // Re-applies only when the module goes from unloaded to loaded, so the
      // module changes made by apply() itself can't loop.
      player.addEventListener('onApiChange', function () {
        var was = kg.loaded;
        kg.loaded = kg.module() !== null;
        if (kg.loaded && !was) kg.apply();
      });
      player.addEventListener('onStateChange', function (e) {
        if (e && e.data === 1 && !kg.played) {
          kg.played = true;
          kg.reloads = 0;
          kg.apply();
        }
      });
      kg.apply();
    };
  }
  kg.on = on;
  kg.lang = lang;
  kg.reloads = 0;
  if (kg.hooked) kg.apply(); else kg.hook(0);
  // WKWebView reports an undefined completion value as an error.
  return '';
})''';
