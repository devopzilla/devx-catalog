package kubernetes

import (
	"strings"
	"stakpak.dev/devx/v1"
	"stakpak.dev/devx/v1/traits"
	resources "stakpak.dev/devx/k8s/services/eso/resources"
)

#KubernetesResource: {
	$metadata: labels: {
		driver: "kubernetes"
		type:   "\(apiVersion)/\(strings.ToLower(kind))"
		...
	}
	apiVersion: string
	kind:       string
}

#AddExternalSecret: v1.#Transformer & {
	traits.#Secret
	$metadata: _
	secrets:   _

	k8s: {
		namespace: string
		...
	}

	externalSecret: {
		refreshInterval: *"1h" | string
		storeRef: {
			name: string
			kind: *"ClusterSecretStore" | "SecretStore"
		}
		decodingStrategy: *"None" | "Base64" | "Base64URL" | "Auto"
	}

	let secretObjs = {
		for _, secret in secrets {
			"\(secret.name)": {
				data: secret
				properties: {
					if secret.property != _|_ {
						"\(secret.property)": null
					}
				}
				"template": secret.template
			}
		}
	}

	$resources: {
		for secretName, obj in secretObjs {
			"\(secretName)-external-secret": resources.#ExternalSecret & {
				#KubernetesResource
				metadata: {
					name:      secretName
					namespace: k8s.namespace
				}
				spec: {
					refreshInterval: externalSecret.refreshInterval
					secretStoreRef: {
						name: externalSecret.storeRef.name
						kind: externalSecret.storeRef.kind
					}

					if obj.template == _|_ {
						if len(obj.properties) == 0 {
							data: [{
								secretKey: "value"
								remoteRef: {
									key:              secretName
									version:          obj.data.version | *"latest"
									decodingStrategy: externalSecret.decodingStrategy
								}
							}]
						}

						if len(obj.properties) > 0 {
							data: [
								for propertyName, _ in obj.properties {
									secretKey: propertyName
									remoteRef: {
										key:              secretName
										version:          obj.data.version | *"latest"
										property:         propertyName
										decodingStrategy: externalSecret.decodingStrategy
									}
								},
							]
						}
					}

					if obj.template != _|_ {
						target: template: {
							engineVersion: "v2"
							data: {
								value: obj.template.value
							}
						}
						data: [
							for propertyName, propertyObj in obj.template.properties {
								secretKey: propertyName
								remoteRef: {
									key:     propertyObj.name
									version: obj.data.version | *"latest"
									if propertyObj.property != _|_ {
										property: propertyObj.property
									}
									decodingStrategy: externalSecret.decodingStrategy
								}
							},
						]
					}
				}
			}
		}
	}
}
