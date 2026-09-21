{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.llama-server;
in
{
  options.services.llama-server = {
    enable = lib.mkEnableOption "llama.cpp server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-cpp;
      defaultText = lib.literalExpression "pkgs.llama-cpp";
      description = "The llama-cpp package to use.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "IP address to bind to. Default is localhost-only.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on.";
    };

    modelPath = lib.mkOption {
      type = lib.types.str;
      description = ''
        Path to the GGUF model file. This should be an absolute path to a
        local model file for reproducibility. Use ~/.cache/huggingface/hub/
        for models downloaded via Hugging Face.
      '';
      example = "/Users/username/.cache/huggingface/hub/models--ggml-org--Qwen3.8-27B-GGUF/blobs/aab65c67...";
    };

    alias = lib.mkOption {
      type = lib.types.str;
      description = "Model name alias to expose via the API.";
      example = "ggml-org/Qwen3.8-27B-GGUF:Q8_0";
    };

    contextSize = lib.mkOption {
      type = lib.types.int;
      default = 65536;
      description = "Size of the prompt context. 0 = loaded from model.";
    };

    flashAttention = lib.mkOption {
      type = lib.types.enum [
        "on"
        "off"
        "auto"
      ];
      default = "auto";
      description = "Flash Attention setting.";
    };

    cacheTypeK = lib.mkOption {
      type = lib.types.str;
      default = "q8_0";
      description = "KV cache data type for K.";
    };

    cacheTypeV = lib.mkOption {
      type = lib.types.str;
      default = "q8_0";
      description = "KV cache data type for V.";
    };

    threadsBatch = lib.mkOption {
      type = lib.types.int;
      default = 12;
      description = "Number of threads to use during batch and prompt processing.";
    };

    gpuLayers = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Number of layers to offload to GPU. Use "all" to offload all layers,
        or a specific number. null disables this flag.
      '';
      example = "all";
    };

    logDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Logs/llama-server";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/Library/Logs/llama-server"'';
      description = "Directory for llama-server logs.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Install llama-cpp package
    home.packages = [ cfg.package ];

    # Create log directory on activation
    home.activation.createLlamaServerLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "${cfg.logDirectory}"
    '';

    # Configure launchd agent
    launchd.agents.llama-server = {
      enable = true;
      config = {
        ProgramArguments = [
          "${cfg.package}/bin/llama-server"
          "--host"
          cfg.host
          "--port"
          (toString cfg.port)
          "--model"
          cfg.modelPath
          "--alias"
          cfg.alias
          "--ctx-size"
          (toString cfg.contextSize)
          "--flash-attn"
          cfg.flashAttention
          "--cache-type-k"
          cfg.cacheTypeK
          "--cache-type-v"
          cfg.cacheTypeV
          "--threads-batch"
          (toString cfg.threadsBatch)
        ]
        ++ (lib.optionals (cfg.gpuLayers != null) [
          "--n-gpu-layers"
          cfg.gpuLayers
        ]);

        # Manual start/stop - do not auto-start on login or boot
        RunAtLoad = false;
        KeepAlive = false;

        # Logging
        StandardOutPath = "${cfg.logDirectory}/stdout.log";
        StandardErrorPath = "${cfg.logDirectory}/stderr.log";

        # Environment
        # NOTE: Do NOT put secrets like HF_TOKEN here. Secrets should be
        # injected via runtime mechanisms outside the Nix store.
        EnvironmentVariables = {
          # Ensure model cache uses user's HF cache
          HF_HOME = "${config.home.homeDirectory}/.cache/huggingface";
        };

        # Working directory
        WorkingDirectory = config.home.homeDirectory;

        # Resource limits - allow process to use available resources
        ProcessType = "Interactive";
      };
    };
  };
}
