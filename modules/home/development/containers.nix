{ config, lib, pkgs, ... }:
let
  cfg = config.modules.home.development.containers;
in {
  options.modules.home.development.containers = {
    enable = lib.mkEnableOption "Container development tools";
    
    docker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker CLI tools";
      };

      enableCompose = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker Compose";
      };

      enableBuildx = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Docker Buildx";
      };
    };

    colima = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Colima for Docker runtime on macOS";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Auto-start Colima on system boot";
      };

      cpu = lib.mkOption {
        type = lib.types.int;
        default = 2;
        description = "Number of CPUs for Colima VM";
      };

      memory = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Memory in GB for Colima VM";
      };

      disk = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Disk size in GB for Colima VM";
      };
    };

    kubernetes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Kubernetes tools";
      };

      enableKubectl = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable kubectl CLI";
      };

      enableHelm = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Helm package manager";
      };

      enableK9s = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable K9s TUI for Kubernetes";
      };

      enableMinikube = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Minikube for local development";
      };
    };

    podman = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Podman as Docker alternative";
      };

      enableCompose = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Podman Compose";
      };
    };

    lazydocker = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Lazydocker TUI";
      };
    };

    dive = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Dive for exploring Docker images";
      };
    };
  };
  
  config = lib.mkIf cfg.enable {
    # Docker tools
    home.packages = with pkgs; lib.mkMerge [
      # Docker CLI and tools
      (lib.mkIf cfg.docker.enable [
        docker
        (lib.mkIf cfg.docker.enableCompose docker-compose)
        (lib.mkIf cfg.docker.enableBuildx docker-buildx)
      ])
      
      # Colima for Docker runtime on macOS
      (lib.mkIf cfg.colima.enable [
        colima
      ])
      
      # Kubernetes tools
      (lib.mkIf cfg.kubernetes.enable (lib.mkMerge [
        (lib.mkIf cfg.kubernetes.enableKubectl [ kubectl ])
        (lib.mkIf cfg.kubernetes.enableHelm [ kubernetes-helm ])
        (lib.mkIf cfg.kubernetes.enableK9s [ k9s ])
        (lib.mkIf cfg.kubernetes.enableMinikube [ minikube ])
      ]))
      
      # Podman
      (lib.mkIf cfg.podman.enable [
        podman
        (lib.mkIf cfg.podman.enableCompose podman-compose)
      ])
      
      # Container management TUIs
      (lib.mkIf cfg.lazydocker.enable [ lazydocker ])
      (lib.mkIf cfg.dive.enable [ dive ])
    ];

    # Shell aliases for container management (integrated with aliases module)
    programs.zsh.shellAliases = lib.mkMerge [
      (lib.mkIf cfg.docker.enable {
        d = "docker";
        dc = "docker-compose";
        dps = "docker ps";
        dpa = "docker ps -a";
        di = "docker images";
        dex = "docker exec -it";
        dlog = "docker logs -f";
        dstop = "docker stop $(docker ps -q)";
        drm = "docker rm $(docker ps -aq)";
        drmi = "docker rmi $(docker images -q)";
        dprune = "docker system prune -af";
      })
      
      (lib.mkIf cfg.kubernetes.enable {
        k = "kubectl";
        kgp = "kubectl get pods";
        kgs = "kubectl get services";
        kgd = "kubectl get deployments";
        kaf = "kubectl apply -f";
        kdel = "kubectl delete";
        klog = "kubectl logs -f";
        kex = "kubectl exec -it";
        kctx = "kubectl config use-context";
        kns = "kubectl config set-context --current --namespace";
      })
      
      (lib.mkIf cfg.podman.enable {
        p = "podman";
        pc = "podman-compose";
        pps = "podman ps";
        ppa = "podman ps -a";
        pi = "podman images";
      })
    ];

    # Colima configuration
    home.file = lib.mkIf cfg.colima.enable {
      ".colima/default/colima.yaml".text = ''
        cpu: ${toString cfg.colima.cpu}
        memory: ${toString cfg.colima.memory}
        disk: ${toString cfg.colima.disk}
        
        # Auto-start on system boot
        auto_activate: ${lib.boolToString cfg.colima.autoStart}
        
        # Docker runtime
        runtime: docker
        
        # Network configuration
        network:
          address: true
          
        # Volume mounts
        mounts:
          - location: ~/
            writable: true
          - location: /tmp/colima
            writable: true
            
        # Provision scripts
        provision: []
        
        # SSH configuration
        ssh:
          config: true
      '';
    };

    # Kubernetes configuration
    programs.zsh.initExtra = lib.mkIf cfg.kubernetes.enableKubectl ''
      # Kubectl completion
      if command -v kubectl >/dev/null 2>&1; then
        source <(kubectl completion zsh)
      fi
    '';

    # Docker completion
    programs.zsh.initExtra = lib.mkIf cfg.docker.enable ''
      # Docker completion
      if command -v docker >/dev/null 2>&1; then
        # Docker CLI completion is built-in for zsh
      fi
    '';

    # Environment variables
    home.sessionVariables = lib.mkMerge [
      (lib.mkIf cfg.docker.enable {
        DOCKER_BUILDKIT = "1";
        COMPOSE_DOCKER_CLI_BUILD = "1";
      })
      
      (lib.mkIf cfg.kubernetes.enable {
        KUBECONFIG = "$HOME/.kube/config";
      })
    ];
  };
}