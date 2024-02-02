{
  description = "Modules for podman services";
  inputs = {
  };


  outputs = { self  }: 
     # replace 'joes-desktop' with your hostname here.
       #let 
       # pkgs = import nixpkgs { system = "x86_64-linux";}; 
       #in 
       {
       nixosModules.home-podman-rootless = import ./home-modules/podman-rootless-containers.nix;
       nixosModules.default = self.home-podman-rootless;

   };
 }
