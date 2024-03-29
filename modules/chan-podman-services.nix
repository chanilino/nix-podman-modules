{ lib, pkgs, config, ... }:
{
  options = {
    services.hello = {
      enable = mkEnableOption "hello service";
      greeter = mkOption {
        type = types.str;
        default = "world";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.hello = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.hello}/bin/hello -g'Hello, ${escapeShellArg cfg.greeter}!'";
    };
  };
}
