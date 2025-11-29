defmodule Job do
  @moduledoc """
  A job that determines the behaviour of scheduler. Instead of calling
  `SchedEx.run_at/2`, `SchedEx.run_in/2`, and `SchedEx.run_every` you
  can specify youru job and use `SchedEx.run_job/2`
  """

  # This is what we have in fledex:
  # def create_job(job, job_config, _strip_name) do
  #   new_job([])
  #   |> Job.set_name(job)
  #   |> Job.set_schedule(job_config.pattern)
  #   |> Job.set_task(job_config.func)
  #   |> Job.set_timezone(Keyword.get(job_config.options, :timezone, :utc))
  #   |> Job.set_overlap(Keyword.get(job_config.options, :overlap, false))
  # end

  defstruct name: nil, func: nil, schedule: nil, context: %{}, opts: []

  def new(name, func, schedule, context, opts) do
    %__MODULE__{name: name, func: func, schedule: schedule, context: context, opts: opts}
  end

  def new(), do: %__MODULE__{}
  def set_name(%Job{} = job, name), do: %{job | name: name}
  def set_task(%Job{} = job, func), do: %{job | func: func}
  def set_schedule(%Job{} = job, schedule), do: %{job | schedule: schedule}

   # coveralls-ignore-start
  @doc deprecation:  "Use `Etc/UTC` instead of `:utc` as timezone. This is for compatibility with Quantum only"
  def set_timezone(job, :utc), do: set_timezone(job, "Etc/UTC")
  # coveralls-ignore-stop
  def set_timezone(%Job{opts: opts} = job, timezone),
    do: %{job | opts: Keyword.put(opts, :timezone, timezone)}

  def set_overlap(%Job{opts: opts} = job, overlap),
    do: %{job | opts: Keyword.put(opts, :overlap, overlap)}

  def set_repeat(%Job{opts: opts} = job, repeat),
    do: %{job | opts: Keyword.put(opts, :repeat, repeat)}

  def set_context(%Job{} = job, context), do: %{job | context: context}

  # def dummy() do
  #   Job.new()
  #   |> Job.set_name(:test)
  #   |> Job.set_task(fn -> :ok end)
  #   |> Job.set_schedule({1000, :ms})
  #   |> Job.set_timezone("Etc/UTC")
  #   |> Job.set_overlap(true)
  #   |> Job.set_context(%{strip_name: :john, job: :repeater})
  # end

  # def dummy2() do
  #   import Crontab.CronExpression

  #   Job.new()
  #   |> Job.set_name(:test)
  #   |> Job.set_task(fn -> IO.puts(".") end)
  #   |> Job.set_schedule(~e[* * * * * * *]e)
  #   |> Job.set_timezone("Etc/UTC")
  #   |> Job.set_overlap(true)
  #   |> Job.set_context(%{strip_name: :john, job: :repeater})
  # end
end
