

Kong Gateway is the world's leading API gateway based on NGINX and OpenResty. This code base is the enterprise version of Kong Gateway.

Please make changes in the codebase directly and implement the feature or fix:

> <problem statement>

> <my prefered solution>


## Engineering practices

You should follow this order to implement the features:

1. Make sure you are at the correct place: we fix issues on master first and then backport to old branches. So we should be either on a branch that is created from master or we should create a new branch from master. When a new branch needs to be created, we pull the latest.

2. Create clean binaries of Kong before doing local development (this can take about 10 mins)

Usually this is not done by you the assistant (but by me, the user of you), but if you encounter any critical/weird issues (like Kong fails to run because of a C stack trace), you can try it:

```sh
make clean 
make dev
```

To prevent incomplete builds, when a `make dev` run fails, make sure run `make clean` before next trial.

3. Learn existing design and make a plan

We learn the existing design of involved plugin or compoent to make a good plan for the implemention, make a list of the implementation to make sure we are always on the write direction. Share your implementation to me before you make code changes. Don't need to wait for my agreement to proceed.

4. Based on the implementation plan, write failing test cases (so, it's TDD way).

Unit tests for plguins can locate in one of these positions:
* spec/03-plugins/<plugin_name>
* spec-ee/03-plugins/<plugin_name>

How to decide which place we should place a new test case? We find where are the exsiting cases, then we write new cases into the same file or create a new file next to existing files.

If it's not a plugin, find the existing test cases under `spec` or `spec-ee` using the same methodology.

5. Run the test cases:

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

6. Implement the feature using Lua:

Try pure lua solutions first without importing new external modules. If an external module is not avoidable, please stop immediately and output the reasons. Let me make the decision on how to move on.

Pass the test cases using the Lua implementation.

7. Debugging

Use these ways:
  1. Check busted outputs
  1. add `print()` directives into test code: for example `print("my-debug-label", my_var)`, and `print("my-debug-label", require("pl.pretty").write(my_var))` if more structurale output needed. These outputs can be read directly from the test runner output
  1. add `print()` directives into production code. These outputs can be read from Kong/nginx output. Usually it's under `servroot/logs/error.log` or `servroot2/logs/error.log` or `servroot_dp/logs/error.log` or `servroot_cp/logs/error.log` depending on the prefix parameter used to `start_kong`.

8. Linting

Try to run this lua lint after your code changes:

```sh
luacheck **/*.lua --no-default-config --config .luacheckrc --exclude-files ./distribution/
```