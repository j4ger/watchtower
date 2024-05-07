//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import bluetooth_low_energy_darwin
import path_provider_foundation
import shared_preferences_foundation
import sqflite
import sqlite3_flutter_libs

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  BluetoothLowEnergyDarwin.register(with: registry.registrar(forPlugin: "BluetoothLowEnergyDarwin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
  Sqlite3FlutterLibsPlugin.register(with: registry.registrar(forPlugin: "Sqlite3FlutterLibsPlugin"))
}
