package traits

import (
	"list"
	"guku.io/devx/v1"
)

// a component that runs containers
#Workload: v1.#Trait & {
	$metadata: traits: Workload: null

	containers: [string]: {
		image: string @guku(required)
		command: [...string]
		args: [...string]
		env: [string]: string | v1.#Secret
		mounts: [...{
			volume: _#VolumeSpec & {
				local:       string
				secret?:     _|_
				ephemeral?:  _|_
				persistent?: _|_
			} | {
				ephemeral:   string
				local?:      _|_
				secret?:     _|_
				persistent?: _|_
			} | {
				persistent: string
				ephemeral?: _|_
				local?:     _|_
				secret?:    _|_
			} | {
				secret:      v1.#Secret
				ephemeral?:  _|_
				local?:      _|_
				persistent?: _|_
			}
			path:     string
			readOnly: bool | *true
		}]
		resources: {
			requests?: {
				cpu?:    string
				memory?: string
			}
			limits?: {
				cpu?:    string
				memory?: string
			}
		}
	}
	containers: default: _
	restart: "onfail" | "never" | *"always"
}

// a component that can be horizontally scaled
#Replicable: v1.#Trait & {
	$metadata: traits: Replicable: null

	replicas: {
		min: uint | *1
		max: uint & >=min | *min
	}
}

// a component that has endpoints that can be exposed
#Exposable: v1.#Trait & {
	$metadata: traits: Exposable: null

	endpoints: [string]: {
		ports: [...{
			name?:  string
			port:   uint
			target: uint | *port
		}]
		host: string
	}
	endpoints: default: _
}

// work around ambiguous disjunctions by disallowing fields
_#VolumeSpec: {
	local:       string
	secret?:     _|_
	ephemeral?:  _|_
	persistent?: _|_
} | {
	ephemeral:   string
	local?:      _|_
	secret?:     _|_
	persistent?: _|_
} | {
	persistent: string
	ephemeral?: _|_
	local?:     _|_
	secret?:    _|_
} | {
	secret:      v1.#Secret
	ephemeral?:  _|_
	local?:      _|_
	persistent?: _|_
}

// a component that has a volume
#Volume: v1.#Trait & {
	$metadata: traits: Volume: null

	volumes: [string]: _#VolumeSpec & {
		local:       string
		secret?:     _|_
		ephemeral?:  _|_
		persistent?: _|_
	} | {
		ephemeral:   string
		local?:      _|_
		secret?:     _|_
		persistent?: _|_
	} | {
		persistent: string
		ephemeral?: _|_
		local?:     _|_
		secret?:    _|_
	} | {
		secret:      v1.#Secret
		ephemeral?:  _|_
		local?:      _|_
		persistent?: _|_
	}
}

// an automation workflow
#Workflow: v1.#Trait & {
	$metadata: traits: Workflow: null
	// the plan can be anything depending on the implementation
	// this field should be validated by transformers
	plan: _
}

// a component that has secrets
#Secret: v1.#Trait & {
	$metadata: traits: Secret: null

	secrets: [string]: v1.#Secret
}

// a network ingress for web traffic
#Gateway: v1.#Trait & {
	$metadata: traits: Gateway: null
	gateway: {
		name:   string
		public: bool
		listeners: [string]: {
			host:     string
			port:     uint & <65536
			protocol: *"HTTP" | "HTTPS" | "TCP" | "TLS"
		}
		_validate: [ for _, l in listeners {"\(l.host)/\(l.port)/\(l.protocol)"}] & list.UniqueItems()
	}
}

// an HTTP ingress route
#HTTPRoute: v1.#Trait & {
	$metadata: traits: HTTPRoute: null
	http: {
		gateway:  #Gateway
		listener: string

		hostnames: [...string]
		rules: [...{
			match: {
				path: string | *"/*"
				headers: [string]: string
				method?: string
			}
			backends: [...{
				weight?: uint
				component: {
					v1.#Component
					#Workload
					#Exposable
				}
				endpoint:                 string
				port:                     uint
				"_port not in endpoints": list.Contains(
								[ for p in component.endpoints[endpoint].ports {p.target}],
								port,
								) & true
			}]
		}]
	}

	for rule in http.rules for backend in rule.backends {
		$resources: backend.component.$resources
	}
}
