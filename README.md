<!-- 
Copyright 2025-2026, Matthias Reik <fledex@reik.org>
Modified version of : https://github.com/SchedEx/SchedEx

SPDX-License-Identifier: MIT
-->

# Fledex Scheduler
[![Hex.pm](https://img.shields.io/hexpm/l/fledex_scheduler "License")](https://github.com/a-maze-d/fledex_scheduler/blob/main/LICENSES/MIT.txt)
[![Hex version](https://img.shields.io/hexpm/v/fledex_scheduler.svg?color=0000ff "Hex version")](https://hex.pm/packages/fledex_scheduler)
[![API docs](https://img.shields.io/hexpm/v/fledex_scheduler.svg?label=hexdocs&color=0000ff "API docs")](https://hexdocs.pm/fledex_scheduler)
[![ElixirCI](https://github.com/a-maze-d/fledex_scheduler/actions/workflows/elixir.yml/badge.svg "ElixirCI")](https://github.com/a-maze-d/fledex_scheduler/actions/workflows/elixir.yml)
[![REUSE status](https://api.reuse.software/badge/github.com/a-maze-d/fledex_scheduler)](https://api.reuse.software/info/github.com/a-maze-d/fledex_schedulef)
[![Coverage Status](https://coveralls.io/repos/github/a-maze-d/fledex_scheduler/badge.svg?branch=main)](https://coveralls.io/github/a-maze-d/fledex_scheduler?branch=main)
[![Downloads](https://img.shields.io/hexpm/dt/fledex_scheduler.svg)](https://hex.pm/packages/fledex_scheduler)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/a-maze-d/fledex_scheduler/badge)](https://scorecard.dev/viewer/?uri=github.com/a-maze-d/fledex_scheduler)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/10474/badge)](https://www.bestpractices.dev/projects/10474)
[![Last Updated](https://img.shields.io/github/last-commit/a-maze-d/fledex_scheduler.svg)](https://github.com/a-maze-d/fledex_scheduler/commits/main)


> #### [!IMPORTANT] {: .warning}
> 
> This repository is based on [SchedEx](https://github.com/SchedEx/SchedEx), but got 
> heavily modified to fit the needs of [Fledex](https://github.com/a-maze-d/fledex). I tried
> to keep the interface still the same, so you should be able to use it as a drop-in
> replacement as well.
>
> If you don't see a need for the additional features (like definig jobs) you probably want
> to use SchedEx instead. This `README.md` only describes the parts that differ from `SchedEx`.
> For the other parts, look at the `SchedEx` documentation.
>
> Not everything has been adjusted to the new home and therefore you will still find a lot
> of references to SchedEx (that might, or might not be accurate).

`Fledex_Scheduler` is a simple yet deceptively powerful scheduling library for Elixir. Though it is almost trivially simple by design, it enables a number of very powerful use cases to be accomplished with very little effort.

Fledex_Scheduler is a fork of SchedEx that is written by [Mat Trudel](http://github.com/mtrudel), and development is generously supported by the fine folks
at [FunnelCloud](http://funnelcloud.io). It has been adapted to easily integrate into [FLedex](https://github.com/a-maze-d/fledex)

For usage details, please refer to the [documentation](https://hexdocs.pm/fledex_scheduler) and look at the original [`SchedEx` library documentation](https://hexdocs.pm/sched_ex/readme.html).

## Basic Usage

In most contexts `Fledex.Scheduler.run_job/2` is the function most commonly used. You first define a `Fledex.Scheduler.Job` before you schedule the job. Thus, you code will look something like the following:

```elixir
alias Fledex.Scheduler
alias Fledex.Scheduler.Job

job =
  Job.new()
  |> Job.set_name(:test_job)
  |> Job.set_schedule(crontab)
  |> Job.set_task(fn -> 
    # do something useful
    :ok
  end)
  |> Job.set_repeat(true)
  |> Job.set_run_once(false)
  |> Job.set_timezone("Etc/UTC")
  |> Job.set_overlap(false)
  |> Job.set_nonexistent_time_strategy(:adjust)
  |> Job.set_context(%{strip_name: :test_strip, job: :test_job})

{:ok, pid} = Scheduler.run_job(job)
```

If more control over the schedule process is required (for example by integrating it into a supervision tree) it's also possible to use the Runner (`Fledex.Scheduler.Runner`) directly.
The `Fledex.Scheduler.run_job/2` maps directly to the `Fledex.Scheduler.Runner.run/3` or `Fledex.Scheduler.Runner.start_link/3` with additional server options.

## Differences vs SchedEx
`SchedEx` was the base for this library and the core implementation hasn't changed. A [`Job`](`Fledex.Scheduler.Job`)
definition has been added. This `Job` is not only used in the [`run_job`](`Fledex.Scheduler.run_job/2`) but also under the hood in all the other interface functions, i.e. [`run_every`](`Fledex.Scheduler.run_every/3`), [`run_at`](`Fledex.Scheduler.run_at/3`), and [`run_in`](`Fledex.Scheduler.run_in/3`). An attempt was
made to keep the same semantics in the interface so it can act as a drop-in replacement for SchedEx. Still, no guarantee can be given that this is true in all cases.

The scheduling can happen in various forms:
* delay based (in milliseconds)
* delay based with a unit (as a tuple [`{unit, amount}`](c:Fledex.Scheduler.Job.unit/0))
* crontab based, either as a `Crontab.CronExpression` or as a string (that will be parsed)

In addition a clearer definition was introduced between the different type of options (`job_opts`, `test_opts`, and `server_opts`), 100% test, `@spec` and `@doc` coverage, and
a lot of automatisms in the CI pipeline.

## Copyright and License
Copyright (c) 2025-2026, Matthias Reik <fledex@reik.org>

Copyright (c) 2018 Mat Trudel on behalf of FunnelCloud Inc.

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
