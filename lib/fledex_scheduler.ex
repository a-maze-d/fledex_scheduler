# Copyright 2025-2026, Matthias Reik <fledex@reik.org>
# Modified version of : https://github.com/SchedEx/SchedEx
#
# SPDX-License-Identifier: MIT
defmodule Fledex.Scheduler do
  @moduledoc """
  `Fledex.Scheduler` schedules jobs (either an m,f,a or a function) to run in the future.
  These jobs are run in isolated processes, and are unsurpervised.

  For even more control, you can use `Fledex.Scheduler.Runner` directly that even allwos
  you to provide your own process names, and to attach it to a supervision tree.
  """

  alias Crontab.CronExpression
  alias Crontab.CronExpression.Parser
  alias Fledex.Scheduler.Job
  alias Fledex.Scheduler.Runner

  @doc """
  Runs the given module, function and argument at the given time
  """
  @spec run_at(module(), atom(), list(), DateTime.t(), keyword) :: GenServer.on_start()
  def run_at(m, f, a, %DateTime{} = time, opts \\ [])
      when is_atom(m) and is_atom(f) and is_list(a) do
    run_at(fn -> apply(m, f, a) end, time, opts)
  end

  @doc """
  Runs the given function at the given time
  """
  @spec run_at(Job.task(), DateTime.t(), keyword) :: GenServer.on_start()
  def run_at(func, %DateTime{} = time, opts \\ []) when is_function(func) do
    delay = DateTime.diff(time, DateTime.utc_now(), :millisecond)
    run_in(func, delay, opts)
  end

  @doc """
  Runs the given module, function and argument in given number of units (this
  corresponds to milliseconds unless a custom `time_scale` is specified). Any
  values in the arguments array which are equal to the magic symbol `:sched_ex_scheduled_time`
  are replaced with the scheduled execution time for each invocation

  Supports the following options:

  * `repeat`: Whether or not this job should be recurring
  * `start_time`: A `DateTime` to use as the basis to offset from
  * `time_scale`: A module that implements the `Fledex.Scheduler.TimeScale` behaviour, by
  default is set to `Fledex.Scheduler.IdentityTimeScale`. Can be used to speed up time
  (often used for speeding up test runs)
  * `name`: To attach a name to the process. Useful for adding a name to Registry
  to lookup later. ie. {:via, Registry, {YourRegistryName, "scheduled-task-1"}}
  """
  @spec run_in(module, atom(), list(), pos_integer, keyword) :: GenServer.on_start()
  def run_in(m, f, a, delay, opts \\ []) when is_atom(m) and is_atom(f) and is_list(a) do
    run_in(mfa_to_fn(m, f, a), delay, opts)
  end

  @doc """
  Runs the given function in given number of units (this corresponds to milliseconds
  unless a custom `time_scale` is specified). If func is of arity 1, the scheduled
  execution time will be passed for each invocation

  Takes the same options as `run_in/5`
  """
  @spec run_in(Job.task(), Job.schedule() | pos_integer, keyword) :: GenServer.on_start()
  def run_in(func, delay, opts \\ [])

  def run_in(func, {amount, unit} = delay, opts)
      when is_function(func) and is_integer(amount) and is_atom(unit) do
    {job_opts, opts} =
      Keyword.split(opts, [
        :name,
        :nonexistent_time_strategy,
        :repeat,
        :timezone,
        :overlap,
        :context,
        :run_once
      ])

    job_opts = Keyword.put_new(job_opts, :repeat, 1)

    job = Job.to_job(func, delay, job_opts)

    Runner.run(job, opts, [])
  end

  @spec run_in(Job.task(), pos_integer, keyword) :: GenServer.on_start()
  def run_in(func, delay, opts) when is_function(func) and is_integer(delay) do
    {job_opts, opts} =
      Keyword.split(opts, [
        :name,
        :nonexistent_time_strategy,
        :repeat,
        :timezone,
        :overlap,
        :context,
        :run_once
      ])

    job_opts = Keyword.put_new(job_opts, :repeat, 1)

    job = Job.to_job(func, delay, job_opts)

    Runner.run(job, opts, [])
  end

  @doc """
  Runs the given module, function and argument on every occurrence of the given crontab. Any
  values in the arguments array which are equal to the magic symbol `:sched_ex_scheduled_time`
  are replaced with the scheduled execution time for each invocation

  Supports the following options:

  * `timezone`: A string timezone identifier (`America/Chicago`) specifying the timezone within which
  the crontab should be interpreted. If not specified, defaults to `UTC`
  * `time_scale`: A module that implements the `Fledex.Scheduler.TimeScale` behaviour, by
  default is set to `Fledex.Scheduler.IdentityTimeScale`. Can be used to speed up time
  (often used for speeding up test runs)
  * `name`: To attach a name to the process. Useful for adding a name to Registry
  to lookup later. ie. {:via, Registry, {YourRegistryName, "scheduled-task-1"}}
  * `nonexistent_time_strategy`: How to handle scheduled runs within a DST forward boundary when evaluated within the
  timezone specified by the `timezone` option. Valid values are `:skip` (the default) and `:adjust`. By way of example,
  for a job which is scheduled to happen daily at 2:30am in the `America/Chicago` timezone, on days where a forward DST
  transition happens (such as 10 March 2019) `:skip` will skip this invocation and next run the job at 2:30 CDT 11 March
  2019, while `:adjust` will run the job the same amount of time into the day as it would normally run (2.5 hours after
    midnight, which will be at 3:30 CDT 10 March 2019).

  """
  @spec run_every(module(), atom(), list(), String.t() | CronExpression.t(), keyword) ::
          GenServer.on_start()
  def run_every(m, f, a, crontab, opts \\ []) when is_atom(m) and is_atom(f) and is_list(a) do
    opts = Keyword.put_new(opts, :repeat, true)
    run_every(mfa_to_fn(m, f, a), crontab, opts)
  end

  @doc """
  Runs the given function on every occurrence of the given crontab. If func is of arity 1, the
  scheduled execution time will be passed for each invocation

  Takes the same options as `run_every/5`
  """
  @spec run_every(Job.task(), String.t() | CronExpression.t(), keyword) ::
          GenServer.on_start() | {:error, any}
  def run_every(func, crontab, opts \\ []) when is_function(func) do
    case as_crontab(crontab) do
      {:ok, expression} ->
        opts = Keyword.put_new(opts, :repeat, true)

        {job_opts, opts} =
          Keyword.split(opts, [
            :name,
            :nonexistent_time_strategy,
            :repeat,
            :timezone,
            :overlap,
            :context,
            :run_once
          ])

        job = Job.to_job(func, expression, job_opts)

        Runner.run(job, opts, [])

      {:error, _msg} = error ->
        error
    end
  end

  @doc """
  You can run a `Fledex.Scheduler.Job` by calling this function.

  All the other `run_*` functions actually map to a job under the hood and therefore this function provides
  you with the most flexibility and power.

  The additionl `test_opts` (keyword list) is for passing some extra settings that are mainly interesting for
  testing.
  """
  @spec run_job(Job.t(), keyword) :: GenServer.on_start()
  def run_job(job, test_opts \\ []) do
    test_opts = Keyword.put_new(test_opts, :repeat, true)
    Runner.run(job, test_opts, [])
  end

  @doc """
  You can update the job (for example change your scheduling) by calling
  this function

  If you used `run_job/2` your process will get the name of the job nad throuh
  this the job will be identified.
  """
  @spec update_job(Job.t(), keyword) :: :ok
  def update_job(%Job{name: name} = job, test_opts \\ []) do
    test_opts = Keyword.put_new(test_opts, :repeat, true)
    Runner.change_config(name, job, test_opts)
  end

  @doc """
  Cancels the given scheduled job
  """
  @spec cancel(GenServer.server()) :: :ok
  def cancel(server) do
    Runner.cancel(server)
  end

  defp mfa_to_fn(m, f, args) do
    fn time ->
      substituted_args =
        args
        |> Enum.map(fn
          :sched_ex_scheduled_time -> time
          arg -> arg
        end)

      apply(m, f, substituted_args)
    end
  end

  defp as_crontab(%Crontab.CronExpression{} = crontab), do: {:ok, crontab}

  defp as_crontab(crontab) do
    extended = length(String.split(crontab)) > 5
    Parser.parse(crontab, extended)
  end
end
