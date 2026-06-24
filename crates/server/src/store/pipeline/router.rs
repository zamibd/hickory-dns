// Copyright 2026 RAHMAT AL ZAMI
//
// Licensed under the Apache License, Version 2.0, <LICENSE-APACHE or
// https://apache.org/licenses/LICENSE-2.0> or the MIT license <LICENSE-MIT or
// https://opensource.org/licenses/MIT>, at your option.

//! Query-type router with embedded forwarders (RouteDNS `router`).

use serde::Deserialize;
use tracing::debug;

use crate::{
    net::runtime::TokioRuntimeProvider,
    proto::rr::{LowerName, Name, RecordType},
    server::RequestInfo,
    store::forwarder::{ForwardConfig, ForwardZoneHandler},
    zone_handler::{
        AuthLookup, AxfrPolicy, LookupControlFlow, LookupOptions, ZoneHandler, ZoneType,
    },
};

/// A single routing rule.
#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RouteConfig {
    /// Record types that match this route (empty = wildcard).
    #[serde(default, rename = "types")]
    pub record_types: Vec<String>,
    /// Embedded forwarder configuration for this route.
    pub forward: ForwardConfig,
}

/// Router configuration — first matching route wins.
#[derive(Clone, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RouterConfig {
    /// Ordered list of routes.
    pub routes: Vec<RouteConfig>,
}

struct Route {
    types: Vec<RecordType>,
    handler: ForwardZoneHandler<TokioRuntimeProvider>,
}

/// Routes queries to different upstream forwarders based on QTYPE.
pub struct RouterZoneHandler {
    origin: LowerName,
    routes: Vec<Route>,
}

impl RouterZoneHandler {
    /// Build a router from configuration.
    pub fn try_from_config(origin: Name, config: RouterConfig) -> Result<Self, String> {
        let mut routes = Vec::with_capacity(config.routes.len());
        for route in config.routes {
            let types = route
                .record_types
                .iter()
                .map(|t| t.parse::<RecordType>())
                .collect::<Result<Vec<_>, _>>()
                .map_err(|e| format!("invalid record type in router route: {e}"))?;

            let handler = ForwardZoneHandler::builder_tokio(route.forward)
                .with_origin(origin.clone())
                .build()?;

            routes.push(Route { types, handler });
        }

        Ok(Self {
            origin: origin.into(),
            routes,
        })
    }

    fn matching_route<'a>(&'a self, rtype: RecordType) -> Option<&'a Route> {
        for route in &self.routes {
            if route.types.is_empty() || route.types.contains(&rtype) {
                return Some(route);
            }
        }
        None
    }
}

#[async_trait::async_trait]
impl ZoneHandler for RouterZoneHandler {
    fn zone_type(&self) -> ZoneType {
        ZoneType::External
    }

    fn axfr_policy(&self) -> AxfrPolicy {
        AxfrPolicy::Deny
    }

    fn origin(&self) -> &LowerName {
        &self.origin
    }

    async fn lookup(
        &self,
        name: &LowerName,
        rtype: RecordType,
        request_info: Option<&RequestInfo<'_>>,
        lookup_options: LookupOptions,
    ) -> LookupControlFlow<AuthLookup> {
        let Some(route) = self.matching_route(rtype) else {
            debug!(%rtype, "no router match, passing to next handler");
            return LookupControlFlow::Skip;
        };

        route
            .handler
            .lookup(name, rtype, request_info, lookup_options)
            .await
    }

    fn metrics_label(&self) -> &'static str {
        "router"
    }

    async fn nsec_records(
        &self,
        name: &LowerName,
        lookup_options: LookupOptions,
    ) -> LookupControlFlow<AuthLookup> {
        super::common::unimplemented_nsec(name, lookup_options).await
    }

    #[cfg(feature = "__dnssec")]
    async fn nsec3_records(
        &self,
        info: crate::zone_handler::Nsec3QueryInfo<'_>,
        lookup_options: LookupOptions,
    ) -> LookupControlFlow<AuthLookup> {
        super::common::unimplemented_nsec3(info, lookup_options).await
    }

    #[cfg(feature = "__dnssec")]
    fn nx_proof_kind(&self) -> Option<&crate::dnssec::NxProofKind> {
        None
    }
}
