//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_sound/flutter_sound_plugin.h>
#include <voicevox_flutter/voicevox_flutter_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) flutter_sound_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterSoundPlugin");
  flutter_sound_plugin_register_with_registrar(flutter_sound_registrar);
  g_autoptr(FlPluginRegistrar) voicevox_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VoicevoxFlutterPlugin");
  voicevox_flutter_plugin_register_with_registrar(voicevox_flutter_registrar);
}
