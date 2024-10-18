{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.virtualisation.docker-podman-compose-rootless;
  composeOptions =
    { ... }: {
      options = {
        source = mkOption {
          type = types.path;
          default = null;
          description = lib.mdDoc "Path to source docker-compose file to run.";
          example = "$";
        };
        #environmentFiles = mkOption {
        #  type = with types; listOf path;
        #  default = [];
        #  description = lib.mdDoc "Environment files for this compose.";
        #  example = literalExpression ''
        #    [
        #      /path/to/.env
        #      /path/to/.env.secret
        #    ]
        #'';
        #};
        abortOnContainerExit = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            When enabled, the compose add --abort-on-container-exit option to docker-compose.
          '';
        };
        pullOnUp = mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc ''
            When enabled, the compose add --pull option to docker-compose.
          '';
        };
        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = lib.mdDoc ''
            When enabled, the compose is automatically started on boot.
            If this option is set to false, the compose has to be started on-demand via its service.
          '';
        };
        dependsOn = mkOption {
          type = with types; listOf str;
          default = [];
          description = lib.mdDoc ''
            Define which other containers this one depends on. They will be added to both After and Requires for the unit.

            Use the name of systemd service.
          '';

      };
    };
  };

  #isValidLogin = login: login.username != null && login.passwordFile != null && login.registry != null;
  podmanComposePath = name : ".config/podman-compose/${name}/docker-compose.yml" ;
  #podmanComposeDir = name : ".config/podman-compose/${name}" ;
  #podmanComposeEnvPath = name : ".config/podman-compose/${name}/.env" ;

  mkService = name: compose: let
    dependsOn = map (x: "podman-${x}.service") compose.dependsOn;
    escapedName = escapeShellArg name;
    env_path = lib.makeBinPath ( with pkgs; [
      coreutils findutils gnugrep gnused systemd util-linux podman docker-compose 
    ]) + ":/run/current-system/sw/bin";
    abortOnContainerExit = mkIf(compose.abortOnContainerExit) "--abort-on-container-exit";
   pullOnUp = mkIf (compose.pullOnUp) "--pull";
  in {
    Unit = {
      Description = "podman-compose systemd service: ${name}";
      Documentation=[ "man:podman-generate-systemd(1)" ];
      Wants = [ "network-online.target" "podman.socket" ] ++ dependsOn;
      After = [ "network-online.target" "podman.socket" ] ++ dependsOn;
      RequiresMountsFor=[ "%t/containers" ];
      Requires = dependsOn;
    };
    Install = {
      WantedBy = [] ++ optional (compose.autoStart) "default.target";
    };
    Service = {
      Environment= [ 
        "PODMAN_SYSTEMD_UNIT=podman-${escapedName}.service"
        "DOCKER_HOST=unix://%t/podman/podman.sock"
        "\"PATH=${env_path}\""
      ];
      #WorkingDirectory= "%h/${podmanComposeDir(escapedName)}";
      
      TimeoutStartSec = 300;
      TimeoutStopSec = 30;
      Restart = "on-failure";
      
      ExecStart = concatStringsSep " \\\n  " ([
        "/bin/sh --login -c '"
     	    "docker-compose -f $HOME/${podmanComposePath(escapedName)}  --project-name ${escapedName} up ${pullOnUp} ${abortOnContainerExit}  --remove-orphans" 
        "'" 
      ]);
      ExecStop = concatStringsSep " \\\n  " ([
        "/bin/sh --login -c '"
     	    "docker-compose -f $HOME/${podmanComposePath(escapedName)} --project-name ${escapedName} down -t 10 --remove-orphans" 
        "'" 
      ]);
      Type="simple";
    };        

  };

in {

  options.virtualisation.docker-podman-compose-rootless = {
    composes = mkOption {
      default = {};
      type = types.attrsOf (types.submodule composeOptions);
      description = lib.mdDoc "Docker-compose to run as systemd services.";
    };
  };

  config = lib.mkIf (cfg.composes != {}) (lib.mkMerge [
    {

      home.file = mapAttrs' (n: v: nameValuePair (podmanComposePath(n)) ({source = v.source;})) cfg.composes;
      # home.file = mapAttrs' (n: v: nameValuePair ".config/podman-compose/docker-compose-${n}.yml" ({source = v.source;})) cfg.composes;
      # We need conmon to monitor containers
      systemd.user.services = mapAttrs' (n: v: nameValuePair "compose-${n}" (mkService n v)) cfg.composes;

    }
  ]);

}
