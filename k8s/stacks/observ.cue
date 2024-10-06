package stacks

import (
	"stakpak.dev/devx/v1"
	"stakpak.dev/devx/k8s/services/loki"
	"stakpak.dev/devx/k8s/services/grafana"
)

ObservabilityStack: v1.#Stack & {
	$metadata: stack: "ObservabilityStack"
	components: {
        "loki": loki.#LokiChart & {
			helm: {
				version: "2.10.2"
				release: "loki"
				values: {}
            }
        }
        "grafana": grafana.#GrafanaChart & {
			helm: {
				version: "8.5.1"
				release: "grafana"
				values: {}
            }
        }
    }
}