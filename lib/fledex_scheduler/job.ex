# Copyright 2025-2026, Matthias Reik <fledex@reik.org>
#
# SPDX-License-Identifier: MIT
defmodule Fledex.Scheduler.Job do
  @moduledoc """
  A job that determines the behaviour of the scheduler. Instead of calling
  `Fledex.Scheduler.run_at/2`, `Fledex.Scheduler.run_in/2`, and `Fledex.Scheduler.run_every` you
  can specify your job and use `Fledex.Scheduler.run_job/2`. the `job` gives you the most power,
  since the above mentioned functions all map to a job under the hood.
  """

  alias __MODULE__
  alias Crontab.CronExpression

  @type unit ::
          :milliseconds
          | :ms
          | :seconds
          | :sec
          | :s
          | :minutes
          | :min
          | :m
          | :hours
          | :h
          | :weeks
          | :w

  @type task :: (-> any) | (DateTime.t() -> any)
  @type schedule :: CronExpression.t() | {pos_integer(), unit()}

  defstruct name: nil, func: nil, schedule: nil, context: %{}, opts: []

  @type t :: %Job{
          name: GenServer.name() | nil,
          func: task() | nil,
          schedule: schedule() | nil,
          context: map,
          opts: keyword
        }

  @doc """
  Create a new job with all aspects specified
  """
  @spec new(GenServer.name(), task(), schedule(), map, keyword) :: t()
  def new(name, func, schedule, context, opts) do
    %Job{name: name, func: func, schedule: schedule, context: context, opts: opts}
  end

  @doc """
  Create an empty job
  """
  @spec new :: t()
  def new, do: %Job{}

  @doc """
  Set the name of the job.

  If nothing is specified, then this will also be the name of the process that will execute the job
  """
  @spec set_name(t(), GenServer.name()) :: t()
  def set_name(%Job{} = job, name), do: %{job | name: name}

  @doc """
  This sets the task that should be executed when it's time to run.
  """
  @spec set_task(t(), task()) :: t()
  def set_task(%Job{} = job, func), do: %{job | func: func}

  @doc """
  This sets the schedue, i.e. the specification of when the task shoudl be executed.
  You can specify the job in two different ways
  """
  @spec set_schedule(t(), schedule()) :: t()
  def set_schedule(%Job{} = job, schedule), do: %{job | schedule: schedule}

  @doc """
  This sets the timezone

  You can use any timezone as defined in tzdata. You will have to make sure that you specify
  the optional [`:tzdata`](https://github.com/lau/tzdata) library and configure it correctly

  > #### Note {: .warning}
  > You can also specify `:utc` as timezone, because `Quantum` allowed it. It is preferred
  > that you use `Etc/UTC` instead. The use of `:utc` will be removed in a future version
  """
  # coveralls-ignore-start
  @doc deprecation:
         "Use `Etc/UTC` instead of `:utc` as timezone. This is for compatibility with Quantum only"
  @spec set_timezone(__MODULE__.t(), :utc | String.t()) :: __MODULE__.t()
  def set_timezone(job, :utc), do: set_timezone(job, "Etc/UTC")
  # coveralls-ignore-stop
  def set_timezone(%Job{opts: opts} = job, timezone),
    do: %{job | opts: Keyword.put(opts, :timezone, timezone)}

  @doc """
  This sets whether two runs should overlap or not.

  An overlap can happen if, e.g. you schedule a job to run every second, but the execution runs
  for more than 1sec (let's say 1.2 sec). If you overlap, the next run will happen immediately,
  whereas if we don't overlap, the next run will only happen at it's next interval, i.e. 0.8sec
  later.

  In general you want to avoid to run any job for that much time
  """
  @spec set_overlap(__MODULE__.t(), boolean) :: __MODULE__.t()
  def set_overlap(%Job{opts: opts} = job, overlap),
    do: %{job | opts: Keyword.put(opts, :overlap, overlap)}

  @doc """
  This sets whether the job should repeat (or only run once), You can specify an amount, like 10
  and it means that the job will run 10x.
  """
  @spec set_repeat(__MODULE__.t(), boolean | non_neg_integer()) :: __MODULE__.t()
  def set_repeat(%Job{opts: opts} = job, repeat),
    do: %{job | opts: Keyword.put(opts, :repeat, repeat)}

  @doc """
  This sets whether the job should run once during startup, even if it's not time from a scheduling
  perspective.

  This option is very convenient if you want to run something every 15min, but you don't want to
  wait for that much time for the first initialization. By settin it the task will be run once during
  startup and will then follow it's schedule.
  """
  @spec set_run_once(__MODULE__.t(), boolean) :: __MODULE__.t()
  def set_run_once(%Job{opts: opts} = job, run_once),
    do: %{job | opts: Keyword.put(opts, :run_once, run_once)}

  @doc """
  This sets teh context.

  The context nothing that the scheduler will use, but it's something that the user can set to the job.
  It's an arbirary map. During task execution you can access the context and thereby use it in your
  processing.
  """
  @spec set_context(__MODULE__.t(), map) :: __MODULE__.t()
  def set_context(%Job{} = job, context), do: %{job | context: context}

  @doc """
  This converts the arguments to a list.

  Note: the job_opts should contain at least a `:name`, but any of the other
  properties the Job can take are accepted too.
  """
  @spec to_job(Job.task(), Job.schedule() | pos_integer(), keyword) :: Job.t()
  def to_job(func, spec, job_opts) do
    spec =
      case spec do
        milliseconds when is_integer(milliseconds) -> {milliseconds, :ms}
        {_value, _unit} = delay -> delay
        %Crontab.CronExpression{} = crontab -> crontab
      end

    # we need to ensure that we run our scheduler at least
    # once, therefore we translate it to the integer version
    # except if we always want to run it
    repeat =
      case Keyword.get(job_opts, :repeat) do
        nil -> 1
        false -> 1
        true -> true
        other when is_integer(other) -> other
        _other -> raise(ArgumentError, "repeat is neither a boolean nor a positive integer")
      end

    %Job{
      name: Keyword.get(job_opts, :name, :default_name),
      func: func,
      schedule: spec,
      opts: [
        timezone: Keyword.get(job_opts, :timezone, "Etc/UTC"),
        overlap: Keyword.get(job_opts, :overlap, false),
        run_once: Keyword.get(job_opts, :run_once, false),
        repeat: repeat
      ],
      context: Keyword.get(job_opts, :context, %{})
    }
  end
end
