
# Implement features for Kong Gateway

Kong Gateway is the world's leading API gateway based on NGINX and OpenResty. This code base is the enterprise version of Kong Gateway.

Please make changes in the codebase directly and implement the feature or fix:

## Goal definition

(todo: replace this part with your real goal)

> <problem statement>

> <my prefered solution>

Don't do anything if this part is meaningless and tell me that I may have forgotten to fill the goal part.

## Engineering practices

IMPORTANT: Your implementation should not break existing users of Kong Gateway except explicitly allowed by me. This means existing users of old versions without the feature being added should work without a manual config migration.

You should follow this order to implement the features:

### 1. Switch to a branch or create a branch

Make sure you are at the correct place: we implement features and fixes on a feature branch first and they will be backported to old branches after the PR is merged on GitHub. So on the local development env, we should be either on a branch that is created from `master` or we should create a new branch from `master`. When a new branch needs to be created, please pull the latest code from remote `master`.

### 2. Prepare Kong/Nginx/OpenResty binaries

Usually this is not done by you the assistant (but by me, the user of you), but if you encounter any critical/weird issues (like Kong fails to run because of a C stack trace), you can try it:

```sh
make clean 
make dev
```

By running these commands, you can create clean binaries required by Kong before doing local development (this can take about 10 mins).

To prevent incomplete builds, when a `make dev` run fails, make sure run `make clean` before next trial.

### 3. Learn existing design and make a plan

If we are making changes to an existing Kong Gateway plugin, you MUST learn the feature of the existing plugin by fetching the document at https://developer.konghq.com/plugins/(plugin_name)/ (for example https://developer.konghq.com/plugins/openid-connect/).  You MUST learn the design of involved plugin or compoent to make a good plan for the implemention, make a todo-list of the implementation to make sure you are always on the write direction. 

Share your implementation to me before you make code changes. Don't need to wait for my agreement to proceed.

### 4. Write failing test cases

Based on the implementation plan, write failing test cases (so, it's TDD way).

Unit tests for plugins can locate in one of these positions:

* spec/03-plugins/<plugin_name>
* spec-ee/03-plugins/<plugin_name>

How to decide which place we should place a new test case? We find where are the exsiting cases, then we write new cases into the same file or create a new file next to existing files.

If it's not a plugin, find the existing test cases under `spec` or `spec-ee` using the same methodology.

### 5. Run the test cases

Some tests does not have component dependencies, and most test cases rely on the postgre database. 

To run a unit test that relies on the postgre database, execute the following command with repalced "relative/path/to/spec.lua":

```sh
source bazel-bin/build/kong-dev-venv.sh && start_services && KONG_TEST_PG_PORT=$(docker port kong-ee-kong-dev-postgres-1 5432 | cut -d: -f2) ./bin/busted
  --helper=spec/busted-ci-helper.lua -o hjtest --exclude-tags="flaky,ipv6,ce" "relative/path/to/spec.lua"
```

Some test cases may rely on other components, like Redis, Solace, Kafka etc. You add `-a` to `start_services`, you may also need to export other environment variables before running the busted command, explore the kong-dev-venv.sh to know how:


```sh
source bazel-bin/build/kong-dev-venv.sh && start_services -a && KONG_TEST_PG_PORT=$(docker port kong-ee-kong-dev-postgres-1 5432 | cut -d: -f2) ./bin/busted
  --helper=spec/busted-ci-helper.lua -o hjtest --exclude-tags="flaky,ipv6,ce" "relative/path/to/spec.lua"
```

To test config schema changes and plugin logic, a real Kong instance is usually involved. This is quite normal and they are still called "unit tests".

To speed up running, you can add "#tag_name" to name of cases and then add `-t tag_name` into the busted command to focus on that particular test case. Remember to remove unnecessary tags from test cases after the feature implementation is finished.

### 6. Implement the feature using Lua

Try pure lua solutions first without importing new external modules. If an external module is not avoidable, please stop immediately and output the reasons. Let me make the decision on how to move on.

Pass the test cases using the Lua implementation.


### 7. Schema changes

If the new feature you are working needs to add/remove or change fields in configuration schemas it may cause compatibility issues since Kong Gateway is a DP-CP architecture software. Interestingly, the DP and CP load the same set of schema. Now, here is the problem: when a 3.14 or an older DP is connecting to a CP that is running 3.15 which is newer, the CP can push a config to the DP with the newly added field to the older DP:  this will cause a configuration failure on the DP, because it does not recognize that field. 

To fix this compatibility issue, we need to mark the newly added fields as removed when an older DP is connecting to this new version CP, so that the CP will remove this field when sending to this DP. To do that, newly added fields need to be marked as removed in the file kong/clustering/compat/removed_fields.lua. Changed fields need to be marked in kong/clustering/compat/checkers.lua 

We also need to add some unit tests to test this scenario, tests are in spec-ee/02-integration/14-hybrid_mode/04-config-compat_spec.lua

Learn the pattern from the the mentioned files above to know how to declare these removals and changes. As an example removal is: `module.3014000000.openid_connect` has an element "token_exchange", meaning the field "token_exchange" should be removed from configs of the openid_connect plugin for DPs older than 3.14. 

run `ls -1 | grep rockspec` on the project root dir to know the next release version number.

### 8. Debugging

Use these ways:
  1. Check busted outputs
  1. add `print()` directives into test code: for example `print("my-debug-label", my_var)`, and `print("my-debug-label", require("pl.pretty").write(my_var))` if more structurale output needed. These outputs can be read directly from the test runner output
  1. add `print()` directives into production code. These outputs can be read from Kong/nginx output. Usually it's under `servroot/logs/error.log` or `servroot2/logs/error.log` or `servroot_dp/logs/error.log` or `servroot_cp/logs/error.log` depending on the prefix parameter used to `start_kong`.

Remember to remove all debugging directives before you finish your work.

### 9. Linting

Try to run this lua lint after your code changes:

```sh
luacheck **/*.lua --no-default-config --config .luacheckrc --exclude-files ./distribution/
```

### 10. Change log

A changelog file needs to be created under `changelog/unreleased/kong-ee`. More on how to write this file please refer to existing change log files of exsiting versions at changelog/<version>/kong-ee/*.yml.