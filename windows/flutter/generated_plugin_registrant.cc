//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <isar_flutter_libs/isar_flutter_libs_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>
#include <record_windows/record_windows_plugin_c_api.h>
#include <screen_retriever/screen_retriever_plugin.h>
#include <window_manager/window_manager_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  IsarFlutterLibsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("IsarFlutterLibsPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
  RecordWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("RecordWindowsPluginCApi"));
  ScreenRetrieverPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverPlugin"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
}
