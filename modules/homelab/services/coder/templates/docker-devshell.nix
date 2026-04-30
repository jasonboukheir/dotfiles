{
  podmanSocket,
  litellmBaseUrl,
  workspaceImage,
}: {
  terraform.required_providers = {
    coder = {
      source = "coder/coder";
    };
    docker = {
      source = "kreuzwerker/docker";
    };
  };

  provider.docker = {
    host = "unix://${podmanSocket}";
  };

  variable.litellm_api_key = {
    type = "string";
    description = "LiteLLM virtual key exposed to workspaces as OPENAI_API_KEY.";
    default = "";
    sensitive = true;
  };

  data.coder_workspace.me = {};
  data.coder_workspace_owner.me = {};

  resource.coder_agent.main = {
    arch = "amd64";
    os = "linux";
    auth = "token";
    startup_script_behavior = "blocking";
    startup_script = ''
      #!/usr/bin/env bash
      set -eu
      mkdir -p ~/.config
      if command -v code-server >/dev/null 2>&1; then
        code-server --auth none --bind-addr 0.0.0.0:13337 >/tmp/code-server.log 2>&1 &
      fi
    '';
    env = {
      OPENAI_API_BASE = litellmBaseUrl;
      OPENAI_BASE_URL = litellmBaseUrl;
      OPENAI_API_KEY = "\${var.litellm_api_key}";
    };
    metadata = [
      {
        key = "cpu";
        display_name = "CPU usage";
        interval = 10;
        timeout = 1;
        script = "coder stat cpu";
      }
      {
        key = "memory";
        display_name = "Memory usage";
        interval = 10;
        timeout = 1;
        script = "coder stat mem";
      }
    ];
  };

  resource.coder_app.code-server = {
    agent_id = "\${coder_agent.main.id}";
    slug = "code-server";
    display_name = "code-server";
    url = "http://localhost:13337";
    icon = "/icon/code.svg";
    subdomain = true;
    share = "owner";
    healthcheck = {
      url = "http://localhost:13337/healthz";
      interval = 5;
      threshold = 6;
    };
  };

  resource.docker_volume.home = {
    name = "coder-\${data.coder_workspace.me.id}-home";
    lifecycle = {
      ignore_changes = ["name"];
    };
  };

  resource.docker_image.workspace = {
    name = workspaceImage;
    keep_locally = true;
  };

  resource.docker_container.workspace = {
    count = "\${data.coder_workspace.me.start_count}";
    image = "\${docker_image.workspace.image_id}";
    name = "coder-\${data.coder_workspace_owner.me.name}-\${data.coder_workspace.me.name}";
    hostname = "\${data.coder_workspace.me.name}";
    entrypoint = ["sh" "-c" "\${coder_agent.main.init_script}"];
    env = [
      "CODER_AGENT_TOKEN=\${coder_agent.main.token}"
    ];
    volumes = [
      {
        container_path = "/home/coder";
        volume_name = "\${docker_volume.home.name}";
        read_only = false;
      }
    ];
  };
}
