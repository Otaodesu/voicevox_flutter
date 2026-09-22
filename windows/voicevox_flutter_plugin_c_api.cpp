#include "include/voicevox_flutter/voicevox_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "voicevox_flutter_plugin.h"

void VoicevoxFlutterPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
    voicevox_flutter::VoicevoxFlutterPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
