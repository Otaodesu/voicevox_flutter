//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <voicevox_flutter/voicevox_flutter_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  VoicevoxFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("VoicevoxFlutterPlugin"));
}
