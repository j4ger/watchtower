# devenv.nix
{ pkgs
, inputs
, ...
}: {
  languages.dart.enable = true;
  languages.dart.package = pkgs.flutter;

  packages = with pkgs; [ gnome.zenity yad ];

  enterShell = ''
    flutter --version
  '';
}
