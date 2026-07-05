{
  description = "Portable terminal environment via home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    shared = {
      url = "github:atomic-235/shared";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, shared, ... }:
    let
      system = "x86_64-linux";
      # local.nix is gitignored — import if it exists
      # Use --impure flag: builtins.pathExists reads the real filesystem
      # Put work configs, model names, SECRETS_DIR, custom functions there
      localModules =
        if builtins.pathExists ./local.nix
        then [ (import ./local.nix) ]
        else [];
    in
    {
      # Expose home-manager binary from flake lock — avoids GitHub API calls
      # Usage: nix run .#hm -- switch --flake .#user --impure -b backup
      apps.${system}.hm = {
        type = "app";
        program = "${home-manager.packages.${system}.home-manager}/bin/home-manager";
      };

      homeConfigurations.user = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ shared.defaultOverlay ];
        };
        extraSpecialArgs = {
          inherit shared;
          nvimRelativePath = "portable/submodules/shared/nvim";
        };
        modules = [
          {
            home.username = builtins.getEnv "USER";
            home.homeDirectory = builtins.getEnv "HOME";
            home.stateVersion = "26.05";
            programs.home-manager.enable = true;
            xdg.enable = true;
            home.sessionVariables = {
              LANG = "C.UTF-8";
              LC_ALL = "C.UTF-8";
              SESSIONIZER_AI_CMD = "opencode";
              SESSIONIZER_AI_CMD_WORK = "opencode";
            };
          }
          shared.homeManagerModules.btop
          shared.homeManagerModules.starship
          shared.homeManagerModules.shell-tools
          shared.homeManagerModules.neovim
          shared.homeManagerModules.lazygit
          shared.homeManagerModules.opencode
          shared.homeManagerModules.bash
          shared.homeManagerModules.yazi
          shared.homeManagerModules.delta
          shared.homeManagerModules.packages
          shared.homeManagerModules.tmux
        ] ++ localModules;
      };
    };
}
