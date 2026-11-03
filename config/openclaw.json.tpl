{
  "models": {
    "providers": {
      "inference": {
        "baseUrl": "__INFERENCE_BASE_URL__",
        "apiKey": "${OPENAI_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "__INFERENCE_MODEL__",
            "name": "__INFERENCE_MODEL__",
            "reasoning": true,
            "input": ["text", "image"],
            "contextWindow": 200000,
            "maxTokens": 64000,
            "compat": { "supportsStore": false }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "inference/__INFERENCE_MODEL__",
        "fallbacks": []
      },
      "modelPolicy": {
        "allow": ["inference/__INFERENCE_MODEL__"]
      },
      "workspace": "/sandbox/workspace",
      "skipBootstrap": true
    },
    "entries": {
      "main": {}
    }
  },
  "tools": {
    "deny": ["gateway", "cron", "openclaw", "browser", "nodes"],
    "fs": { "workspaceOnly": true }
  },
  "plugins": {
    "deny": ["workboard", "admin-http-rpc"],
    "allow": ["mlflow-openclaw", "memory-core"],
    "entries": {
      "diagnostics-otel": {
        "enabled": false
      },
      "mlflow-openclaw": {
        "enabled": true,
        "config": {
          "trackingUri": "https://mlflow.redhat-ods-applications.svc.cluster.local:8443/mlflow",
          "experimentId": "__MLFLOW_EXPERIMENT_ID__"
        },
        "hooks": {
          "allowConversationAccess": true
        }
      }
    }
  },
  "diagnostics": {
    "enabled": false
  },
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": {
      "mode": "password",
      "password": "__OPENCLAW_GATEWAY_PASSWORD__"
    },
    "controlUi": {
      "allowedOrigins": [
        "https://__UI_HOST__"
      ]
    },
    "trustedProxies": [
      "127.0.0.1/32",
      "::1/128"
    ],
    "reload": {
      "mode": "off"
    },
    "http": {
      "endpoints": {
        "chatCompletions": { "enabled": false }
      }
    }
  }
}
