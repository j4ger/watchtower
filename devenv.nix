# devenv.nix
{ pkgs
, inputs
, lib
, ...
}: {
  languages.dart.enable = true;
  languages.dart.package = pkgs.flutter;

  packages = with pkgs; [ gnome.zenity yad sqlite ];

  env.LD_LIBRARY_PATH = "${lib.makeLibraryPath [ pkgs.sqlite ]}";

  enterShell = ''
    flutter --version
  '';
}
