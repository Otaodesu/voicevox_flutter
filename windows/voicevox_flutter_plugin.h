#ifndef FLUTTER_PLUGIN_VOICEVOX_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_VOICEVOX_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace voicevox_flutter {

class VoicevoxFlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  VoicevoxFlutterPlugin();

  virtual ~VoicevoxFlutterPlugin();

  // Disallow copy and assign.
  VoicevoxFlutterPlugin(const VoicevoxFlutterPlugin&) = delete;
  VoicevoxFlutterPlugin& operator=(const VoicevoxFlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace voicevox_flutter

#endif  // FLUTTER_PLUGIN_VOICEVOX_FLUTTER_PLUGIN_H_
