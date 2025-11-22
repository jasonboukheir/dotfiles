{
  lib,
  config,
  ...
}: {
  options = {
    allowUnfreePackageNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        A list of package names (as strings) that are allowed to be unfree.
        Packages matching these names will bypass the `allowUnfree` restriction.
      '';
    };
  };

  config = {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) config.allowUnfreePackageNames;

    nixpkgs.overlays = [
      (_: prev: {
            pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              (_: python-prev: {
                langchain-community = python-prev.langchain-community.overridePythonAttrs (oldAttrs: {
                  disabledTestPaths = (oldAttrs.disabledTestPaths or [ ]) ++ [
                    "tests/unit_tests/agents/test_openai_assistant.py"
                    "tests/unit_tests/agents/test_react.py"
                    "tests/unit_tests/agents/test_sql.py"
                    "tests/unit_tests/agents/test_tools.py"
                    "tests/unit_tests/callbacks/test_callback_manager.py"
                    "tests/unit_tests/callbacks/tracers/test_comet.py"
                    "tests/unit_tests/chains/test_api.py"
                    "tests/unit_tests/chains/test_graph_qa.py"
                    "tests/unit_tests/chains/test_llm.py"
                    "tests/unit_tests/chains/test_natbot.py"
                    "tests/unit_tests/chains/test_pebblo_retrieval.py"
                    "tests/unit_tests/chat_models/test_cloudflare_workersai.py"
                    "tests/unit_tests/chat_models/test_mlflow.py"
                    "tests/unit_tests/evaluation/test_loading.py"
                    "tests/unit_tests/imports/test_langchain_proxy_imports.py"
                    "tests/unit_tests/load/test_dump.py"
                    "tests/unit_tests/retrievers/document_compressors/test_cohere_rerank.py"
                    "tests/unit_tests/retrievers/document_compressors/test_cross_encoder_reranker.py"
                    "tests/unit_tests/retrievers/test_base.py"
                    "tests/unit_tests/retrievers/test_ensemble.py"
                    "tests/unit_tests/retrievers/test_web_research.py"
                    "tests/unit_tests/storage/test_sql.py"
                    "tests/unit_tests/test_cache.py"
                    "tests/unit_tests/tools/test_exported.py"
                    "tests/unit_tests/utilities/test_openapi.py"
                  ];
                });
              })
            ];
          })
    ];
  };
}
