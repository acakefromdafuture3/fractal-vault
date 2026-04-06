//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <shamir_secret_plg/shamir_secret_plg_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) shamir_secret_plg_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "ShamirSecretPlgPlugin");
  shamir_secret_plg_plugin_register_with_registrar(shamir_secret_plg_registrar);
}
