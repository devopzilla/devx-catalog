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
		addresses: [...string]
		listeners: [string]: {
			hostname?: string
			port:      uint & <65536
			protocol:  *"HTTP" | "HTTPS" | "TCP" | "TLS"

			if protocol == "TLS" || protocol == "HTTPS" {
				tls: {
					mode: *"TERMINATE" | "PASSTHROUGH"
					options: [string]: string
				}
			}
		}
		_validate: [ for _, l in listeners {"\(l.port)/\(l.protocol)"}] & list.UniqueItems()
	}
}

// an HTTP ingress route
#HTTPRoute: v1.#Trait & {
	$metadata: traits: HTTPRoute: null
	http: {
		gateway: #Gateway & ({
			gateway: listeners: "\(listener)": protocol: "HTTP"
		} | {
			gateway: listeners: "\(listener)": {
				protocol: "HTTPS"
				tls: mode: "TERMINATE"
			}
		})
		listener: string

		hostnames: [...string]
		rules: [...{
			match: {
				path: string | *"/*"
				headers: [string]: string
				method?: string
			}
			redirect?: {
				scheme?:                                 "http" | "https"
				hostname?:                               string
				path?:                                   string
				port?:                                   uint & <65536
				statusCode:                              301 | *302
				pathPrefixOnly:                          bool | *false
				"_at least one parameter should be set": (scheme != _|_ || hostname != _|_ || path != _|_ || port != _|_) & true
			}
			backends: [...{
				weight?: uint
				component: {
					v1.#Component
					#Workload
					#Exposable
				}
				endpoint: string
				port:     uint
				_ports: [
					for p in component.endpoints[endpoint].ports {p.port},
					for p in component.endpoints[endpoint].ports {p.target},
				]
				"_port not in endpoints": list.Contains(_ports, port) & true
			}]
		}]
	}
}

// a TCP ingress route
#TCPRoute: v1.#Trait & {
	$metadata: traits: TCPRoute: null
	http: {
		gateway: #Gateway & ({
			gateway: listeners: "\(listener)": protocol: "TCP"
		} | {
			gateway: listeners: "\(listener)": {
				protocol: "TLS"
				tls: mode: "TERMINATE"
			}
		})
		listener: string

		rules: [...{
			backends: [...{
				component: {
					v1.#Component
					#Workload
					#Exposable
				}
				endpoint: string
				port:     uint
				_ports: [
					for p in component.endpoints[endpoint].ports {p.port},
					for p in component.endpoints[endpoint].ports {p.target},
				]
				"_port not in endpoints": list.Contains(_ports, port) & true
			}]
		}]
	}
}

// a TLS ingress route
#TLSRoute: v1.#Trait & {
	$metadata: traits: TLSRoute: null
	http: {
		gateway: #Gateway & {
			gateway: listeners: "\(listener)": protocol: "HTTPS" | "TLS"
		}
		listener: string

		hostnames: [...string]
		rules: [...{
			backends: [...{
				component: {
					v1.#Component
					#Workload
					#Exposable
				}
				endpoint: string
				port:     uint
				_ports: [
					for p in component.endpoints[endpoint].ports {p.port},
					for p in component.endpoints[endpoint].ports {p.target},
				]
				"_port not in endpoints": list.Contains(_ports, port) & true
			}]
		}]
	}
}
