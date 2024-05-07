# devenv.nix
{ inputs, pkgs, lib, config, ... }:
let
  nixpkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.system;
  };

  android-nixpkgs = import inputs.android-nixpkgs {
    channel = "stable";
  };

  android-sdk = android-nixpkgs.sdk (sdkPkgs: with sdkPkgs; [
    cmdline-tools-latest
    build-tools-30-0-3
    platform-tools
    platforms-android-33
    platforms-android-34
  ]);
in {
  languages.dart.enable = true;
  languages.dart.package = pkgs.flutter;

  env.ANDROID_HOME = "${android-sdk}/share/android-sdk";
  env.ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk";

  languages.java = {
    enable = true;
    gradle.enable = true;
    jdk.package = pkgs.jdk11;
  };

  packages = with pkgs; [ gnome.zenity yad sqlite jdk android-sdk android-tools ];

  env.LD_LIBRARY_PATH = "${lib.makeLibraryPath [ pkgs.sqlite ]}";

  enterShell = ''
    set -e

    ANDROID_USER_HOME=$(pwd)/.android
    ANDROID_AVD_HOME=$(pwd)/.android/avd

    export PATH="${android-sdk}/bin:$PATH"

    export ANDROID_USER_HOME
    export ANDROID_AVD_HOME

    test -e "$ANDROID_USER_HOME" || mkdir -p "$ANDROID_USER_HOME"
    test -e "$ANDROID_AVD_HOME" || mkdir -p "$ANDROID_AVD_HOME"

    set +e

    flutter --version
  '';
}
