//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_sound/flutter_sound_plugin_c_api.h>
#include <voicevox_flutter/voicevox_flutter_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterSoundPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSoundPluginCApi"));
  VoicevoxFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("VoicevoxFlutterPlugin"));
}
