package aws

import (
	"net"
	"list"
	"strings"
	"stakpak.dev/devx/v1"
	"stakpak.dev/devx/v1/traits"
	schema "stakpak.dev/devx/v1/transformers/terraform"
)

#AddKubernetesGatewayRoute53: v1.#Transformer & {
	traits.#Gateway
	gateway: _
	k8s: {
		service: {
			name:      string
			namespace: string
		}
	}
	apexDomainLength: uint | *2
	$resources: terraform: schema.#Terraform & {
		data: kubernetes_ingress: "\(gateway.name)": {
			metadata: {
				name:      k8s.service.name
				namespace: k8s.service.namespace
			}
		}
		let _hostnames = list.SortStrings([ for address in gateway.addresses if net.FQDN(address) {address}])
		for index, hostname in _hostnames {
			let _hostnameParts = strings.Split(hostname, ".")
			let _apexDomain = strings.Join(list.Drop(_hostnameParts, len(_hostnameParts)-apexDomainLength), ".") & net.FQDN
			let _apexDomainName = strings.Replace(_apexDomain, ".", "_", -1)

			data: aws_route53_zone: "\(_apexDomainName)": {
				name:         _apexDomain
				private_zone: !gateway.public
			}
			resource: aws_route53_record: "\(gateway.name)_\(index)": {
				zone_id: "${data.aws_route53_zone.\(_apexDomainName).zone_id}"
				name:    hostname
				type:    "A"
				alias: {
					name:                   "${aws_lb.gateway_\(gateway.name).dns_name}"
					zone_id:                "${aws_lb.gateway_\(gateway.name).zone_id}"
					evaluate_target_health: true
				}
				records: ["${data.kubernetes_ingress.\(gateway.name).status.0.load_balancer.0.ingress.0.hostname}"]
			}
		}
	}
}
