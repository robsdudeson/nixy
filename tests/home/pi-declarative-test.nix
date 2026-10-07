# Test for the declarative pi-coding-agent home module.
# Run with: nix eval --file ./pi-declarative-test.nix
{
  pkgs ? import <nixpkgs> { },
}:
let
  lib = pkgs.lib;

  evalModule =
    {
      enable ? false,
      package ? pkgs.hello,
      reconcilePackagesOnLogin ? false,
      agentInstructionsFile ? null,
      settings ? { },
      models ? null,
      authBase ? null,
    }:
    let
      evaluated = lib.evalModules {
        modules = [
          ../../modules/home/pi-declarative.nix
          {
            options = {
              assertions = lib.mkOption {
                type = lib.types.listOf lib.types.attrs;
                default = [ ];
              };
              home = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    packages = lib.mkOption {
                      type = lib.types.listOf lib.types.package;
                      default = [ ];
                    };
                    file = lib.mkOption {
                      type = lib.types.attrs;
                      default = { };
                    };
                  };
                };
                default = { };
              };
              systemd.user.services = lib.mkOption {
                type = lib.types.attrs;
                default = { };
              };
            };
            config._module.args = { inherit pkgs; };
          }
          {
            programs.pi-declarative = {
              inherit
                enable
                package
                settings
                reconcilePackagesOnLogin
                ;
            }
            // lib.optionalAttrs (agentInstructionsFile != null) {
              inherit agentInstructionsFile;
            }
            // lib.optionalAttrs (models != null) {
              inherit models;
            }
            // lib.optionalAttrs (authBase != null) {
              inherit authBase;
            };
          }
        ];
      };
    in
    evaluated.config;

  decodedSettings = config: builtins.fromJSON config.home.file.".pi/agent/settings.json".text;
  decodedModels = config: builtins.fromJSON config.home.file.".pi/agent/models.json".text;
  decodedAuthBase = config: builtins.fromJSON config.home.file.".pi/agent/auth.base.json".text;
  authMergeScript =
    config: builtins.readFile config.systemd.user.services.pi-auth-merge.Service.ExecStart;

  tests = {
    test_disabled_writes_nothing = {
      expr =
        let
          config = evalModule { };
        in
        {
          packages = config.home.packages;
          files = config.home.file;
          services = config.systemd.user.services;
        };
      expected = {
        packages = [ ];
        files = { };
        services = { };
      };
    };

    test_enabled_with_null_auth_base_writes_only_settings = {
      expr =
        let
          config = evalModule {
            enable = true;
            settings = {
              defaultProvider = "example-provider";
              packages = [ "npm:example-package" ];
            };
          };
          settings = decodedSettings config;
        in
        {
          packageCount = builtins.length config.home.packages;
          settings = settings;
          settingsForce = config.home.file.".pi/agent/settings.json".force;
          hasModels = builtins.hasAttr ".pi/agent/models.json" config.home.file;
          hasAuthBase = builtins.hasAttr ".pi/agent/auth.base.json" config.home.file;
          hasAgents = builtins.hasAttr ".pi/agent/AGENTS.md" config.home.file;
          services = config.systemd.user.services;
        };
      expected = {
        packageCount = 1;
        settings = {
          defaultProvider = "example-provider";
          packages = [ "npm:example-package" ];
        };
        settingsForce = true;
        hasModels = false;
        hasAuthBase = false;
        hasAgents = false;
        services = { };
      };
    };

    test_optional_models_file = {
      expr =
        let
          config = evalModule {
            enable = true;
            models.providers.local = {
              api = "openai-completions";
              "apiKey" = "fake-placeholder";
              baseUrl = "https://example.invalid/v1";
              models = [ { id = "example-model"; } ];
            };
          };
          models = decodedModels config;
        in
        {
          localModels = models.providers.local.models;
          force = config.home.file.".pi/agent/models.json".force;
        };
      expected = {
        localModels = [ { id = "example-model"; } ];
        force = true;
      };
    };

    test_optional_agents_file = {
      expr =
        let
          config = evalModule {
            enable = true;
            agentInstructionsFile = ./pi-declarative-test.nix;
          };
        in
        {
          hasAgents = builtins.hasAttr ".pi/agent/AGENTS.md" config.home.file;
          force = config.home.file.".pi/agent/AGENTS.md".force;
        };
      expected = {
        hasAgents = true;
        force = true;
      };
    };

    test_auth_base_writes_base_file_and_merge_service = {
      expr =
        let
          config = evalModule {
            enable = true;
            authBase.example = {
              type = "api_key";
              key = "!printf fake-key";
            };
          };
          authBase = decodedAuthBase config;
          service = config.systemd.user.services.pi-auth-merge;
        in
        {
          type = authBase.example.type;
          keyPrefix = builtins.substring 0 1 authBase.example.key;
          writesAuthJson = builtins.hasAttr ".pi/agent/auth.json" config.home.file;
          authBaseForce = config.home.file.".pi/agent/auth.base.json".force;
          serviceType = service.Service.Type;
          wantedBy = service.Install.WantedBy;
          condition = service.Unit.ConditionPathExists;
        };
      expected = {
        type = "api_key";
        keyPrefix = "!";
        writesAuthJson = false;
        authBaseForce = true;
        serviceType = "oneshot";
        wantedBy = [ "default.target" ];
        condition = "%h/.pi/agent/auth.base.json";
      };
    };

    test_auth_merge_script_resolves_command_backed_api_keys = {
      expr =
        let
          config = evalModule {
            enable = true;
            authBase = {
              commandBacked = {
                type = "api_key";
                key = "!printf fake-key";
              };
              literal = {
                type = "api_key";
                key = "literal-fake-key";
              };
            };
          };
          script = authMergeScript config;
        in
        {
          selectsCommandBackedApiKeys = lib.hasInfix ''(.value | type) == "object" and .value.type == "api_key"'' script;
          checksBangPrefix = lib.hasInfix ''startswith("!")'' script;
          stripsBangPrefix = lib.hasInfix ''ltrimstr("!")'' script;
          executesWithoutCommandLogging = lib.hasInfix ''bash -c "$command" 2>/dev/null'' script;
          trimsResolvedOutput = lib.hasInfix ''sub("^\\s+"; "") | sub("\\s+$"; "")'' script;
          rejectsEmptyOutput = lib.hasInfix "was empty" script;
          replacesKeyWithResolvedValue = lib.hasInfix ".[$name].key = $key" script;
          movesMergedAuthAtomically = lib.hasInfix ''mv "$tmp" "$target"'' script;
        };
      expected = {
        selectsCommandBackedApiKeys = true;
        checksBangPrefix = true;
        stripsBangPrefix = true;
        executesWithoutCommandLogging = true;
        trimsResolvedOutput = true;
        rejectsEmptyOutput = true;
        replacesKeyWithResolvedValue = true;
        movesMergedAuthAtomically = true;
      };
    };

    test_reconcile_service_when_enabled = {
      expr =
        let
          config = evalModule {
            enable = true;
            reconcilePackagesOnLogin = true;
          };
          service = config.systemd.user.services.pi-package-reconcile;
        in
        {
          type = service.Service.Type;
          execStart = service.Service.ExecStart;
          wantedBy = service.Install.WantedBy;
          after = service.Unit.After;
          condition = service.Unit.ConditionPathExists;
        };
      expected = {
        type = "oneshot";
        execStart = "${pkgs.hello}/bin/pi update --extensions";
        wantedBy = [ "default.target" ];
        after = [ "network-online.target" ];
        condition = "%h/.pi/agent/settings.json";
      };
    };

    test_enabled_has_package_assertion = {
      expr =
        let
          config = evalModule { enable = true; };
          assertion = builtins.head config.assertions;
        in
        {
          passes = assertion.assertion;
          hasMessage = builtins.isString assertion.message;
        };
      expected = {
        passes = true;
        hasMessage = true;
      };
    };
  };

  results = lib.mapAttrs (
    name: test:
    let
      passed = test.expr == test.expected;
    in
    {
      inherit passed;
      inherit (test) expected;
      actual = test.expr;
      message =
        if passed then
          "PASS"
        else
          "FAIL: expected ${builtins.toJSON test.expected}, got ${builtins.toJSON test.expr}";
    }
  ) tests;

  allPassed = lib.all (r: r.passed) (lib.attrValues results);

  summary = {
    inherit results allPassed;
    total = lib.length (lib.attrNames tests);
    passed = lib.length (lib.filter (r: r.passed) (lib.attrValues results));
  };
in
if allPassed then
  {
    success = true;
    message = "All ${toString summary.total} tests passed!";
    inherit (summary) results;
  }
else
  {
    success = false;
    message = "Tests failed: ${toString (summary.total - summary.passed)}/${toString summary.total}";
    inherit (summary) results;
  }
