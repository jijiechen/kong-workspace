
# The Goal

Kong Gateway is the world's leading API gateway based on NGINX and OpenResty. This code base is the enterprise version of Kong Gateway.

You need to write a conprehensive engineering design document for a new feature.

This feature involve changes in "plugin <plugin_name>"

## Requirement headlines

> <problem statement>

> <my prefered solution>


## Details of the <plugin_name> plugin

1. Documents for users of Kong Gateway: https://developer.konghq.com/plugins/<plugin_name>/
1. Guides: https://developer.konghq.com/how-to/?kong_plugins=<plugin_name>
1. Source code under this repository: kong/plugins/<plugin_name>/  (handler.lua is usually the entrypoint, config schema is also worth reading)

Make sure you checkout all files under the source directory fully understand how it works.

This document should contain these sections:

1. Executive summary
2. Problem statement
3. Scopes (in scope and out of scope items)
4. Porposed solution
  i. Porposed option and reason
  ii. Possible options
5. Solution details
  i. Overview (a detailed introduction to the solution, use text, diagrams and code snippets if needed)
  ii. Configuration Schema changes (Lua schema changes; NGINX header configuration; Other configuration requirements? Prerequisites? )
  iii. Feature description (with the new feature comes in, how Kong Gateway behaves? Explain the major logic blocks that deliver the value that the PRD asks.)
  iv. Assumption or impact on other systems (For example, HTTP client request expectation and upstream changes; setup steps need to be completed ahead of time on a dependency)
  v. Obserability design: Metrics, logging, tracing and profiling?
  vi. Security (Are there any risk? Potential threat model? How do we handle?)
  vii. Performance (caching? impact to the exsiting features?)
6. Testing 
  i. How to test? (Workflow, expectations?)
  ii. Typical scenarios?

You may also change this structure if necessary, for example, add other sections as needed.

Put the document under the root of the project.

# The PRD

<PRD Content>

