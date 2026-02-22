<!--
Copyright 2025-2026, Matthias Reik <fledex@reik.org>

SPDX-License-Identifier: MIT
-->

# Changelog for Fledex v0.3.0
* Replacing the `Stats` with `:telemetry`
* Changed the implementation of `run_at/5` so we have the same behavior as for `run_in/5`. We convert the `m, f, a` to a an anonymous function.
* Added a `:fledex_scheduler_scheduled_time` parameter that can be used in `m,f,a`s (still keeping the `:sched_ex_scheduled_time` option for BC)

# Changelog for Fledex v0.2.0

* Consistently setting MIT as license (removing all Apache-2.0)
* Creating github actions
* Setting up ex_check pipline (with sobelow, doctor, coveralls, xref, reuse)
* ensuring everything is green
* Adding documentation
* Adding type specs (and correcting some)
* Ensuring 100% code coverage
* Updating README.md

# Previous versions
The Changelog of previous versions can be found [here](https://github.com/a-maze-d/fledex_scheduler/releases) 