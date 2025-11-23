defmodule SchedEx.Runner do
  @moduledoc false

  use GenServer

  @doc """
  Main point of entry into this module. Starts and returns a process which will
  run the given function per the specified delay definition (can be an integer
  unit as derived from a TimeScale, or a CronExpression)
  """
  def run(func, spec, opts) when is_function(func) do
    GenServer.start_link(__MODULE__, {func, spec, opts}, Keyword.take(opts, [:name]))
  end
  @doc """
  Similar to `run/3` but with a job encapsulating most things instead of a `func` and a `spec`
  """
  def run(%Job{} = spec, opts) do
    GenServer.start_link(__MODULE__, {spec, opts}, Keyword.take(opts, [:name]))
  end

  @doc """
  Returns stats for the given process.
  """
  def stats(pid) when is_pid(pid) do
    GenServer.call(pid, :stats)
  end

  def stats(_token) do
    {:error, "Not a statable token"}
  end

  @doc """
  Cancels future invocation of the given process. If it has already been invoked, does nothing.
  """
  def cancel(pid) when is_pid(pid) do
    :shutdown = send(pid, :shutdown)
    :ok
  end

  def cancel(_token) do
    {:error, "Not a cancellable token"}
  end

  # Server API
  def init({func, spec, opts}) do
    Process.flag(:trap_exit, true)
    start_time = Keyword.get(opts, :start_time, DateTime.utc_now())

    case schedule_next(start_time, spec, opts) do
      {%DateTime{} = next_time, quantized_next_time, timer_ref} ->
        stats = %SchedEx.Stats{}

        {:ok,
         %{
           func: func,
           spec: spec,
           scheduled_at: next_time,
           quantized_scheduled_at: quantized_next_time,
           timer_ref: timer_ref,
           stats: stats,
           opts: opts
         }}

      {:error, _} ->
        :ignore
    end
  end
  def init({%Job{schedule: _schedule, func: _func, context: _context} = spec, opts}) do
    Process.flag(:trap_exit, true)

    start_time = Keyword.get(opts, :start_time, DateTime.utc_now())

    case schedule_next(start_time, spec, opts) do
      {%DateTime{} = next_time, quantized_next_time, timer_ref} ->
        stats = %SchedEx.Stats{}

        {:ok,
         %{
           spec: spec,
           timer_ref: timer_ref,
           quantized_scheduled_at: quantized_next_time,
           scheduled_at: next_time,
           stats: stats,
           opts: opts
         }}

      {:error, _} ->
        :ignore
    end

  end

  def handle_call(:stats, _from, %{stats: stats} = state) do
    {:reply, stats, state}
  end

  def handle_info(
        :run,
        %{
          spec: spec,
          scheduled_at: this_time,
          quantized_scheduled_at: quantized_this_time,
          stats: stats,
          opts: opts
        } = state
      ) do
    start_time = DateTime.utc_now()

    run_func(this_time, state)

    end_time = DateTime.utc_now()
    stats = SchedEx.Stats.update(stats, this_time, quantized_this_time, start_time, end_time)

    if Keyword.get(opts, :repeat, false) do
      case schedule_next(this_time, spec, opts) do
        {%DateTime{} = next_time, quantized_next_time, timer_ref} ->
          {:noreply,
           %{
             state
             | scheduled_at: next_time,
               quantized_scheduled_at: quantized_next_time,
               timer_ref: timer_ref,
               stats: stats
           }}

        _ ->
          {:stop, :normal, %{state | stats: stats}}
      end
    else
      {:stop, :normal, %{state | stats: stats}}
    end
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  def handle_info({:EXIT, _pid, :normal}, state) do
    {:noreply, state}
  end

  defp run_func(this_time, %{func: func} = _state) do
    if is_function(func, 1) do
      func.(this_time)
    else
      func.()
    end
  end
  defp run_func(this_time, %{spec: %Job{func: func}} = _state) do
    if is_function(func, 1) do
      func.(this_time)
    else
      func.()
    end
  end

  defp schedule_next(%DateTime{} = from, spec, opts) do
    # IO.puts("schedule_next: #{inspect {from, spec, opts}}")
    case get_next_and_delay(from, spec, opts) do
      {:error, _} = error ->
        error
      {next_time, next_delay} ->
        timer_ref = Process.send_after(self(), :run, next_delay)
        {next_time, DateTime.shift(DateTime.utc_now(), microsecond: {next_delay * 1000, 6}), timer_ref}
      end
  end

  defp get_next_and_delay(from, %Job{schedule: schedule} = _spec, opts) when is_struct(schedule, Crontab.CronExpression) do
    get_next_and_delay(from, schedule, opts)
  end
  defp get_next_and_delay(from, spec, opts) when is_integer(spec) or is_struct(spec, Job) do
    time_scale = Keyword.get(opts, :time_scale, SchedEx.IdentityTimeScale)

    delay = get_delay(spec)
    delay = round(delay / time_scale.speedup())

    next = DateTime.shift(from, microsecond: {delay * 1000, 6})
    new_delay = max(DateTime.diff(next, from, :millisecond), 0)

    {next, new_delay}
  end
  defp get_next_and_delay(
         %DateTime{} = _from,
         %Crontab.CronExpression{} = crontab,
         opts
       ) do
    time_scale = Keyword.get(opts, :time_scale, SchedEx.IdentityTimeScale)
    timezone = Keyword.get(opts, :timezone, "Etc/UTC")
    from = time_scale.now(timezone)

    naive_from = from |> DateTime.to_naive()

    case Crontab.Scheduler.get_next_run_date(crontab, naive_from) do
      {:ok, naive_next} ->
        next = convert_naive_to_timezone(naive_next, crontab, timezone, opts)
        delay = max(DateTime.diff(next, from, :millisecond), 0)
        delay = round(delay / time_scale.speedup())
        {next, delay}

      {:error, _} = error ->
        error
    end
  end

  defp get_delay(spec) when is_integer(spec), do: spec
  defp get_delay(%Job{schedule: {value, unit}} = _spec) do
    to_millis(value, unit)
  end

  defp to_millis(value, :milliseconds), do: value
  defp to_millis(value, :ms), do: value

  defp to_millis(value, :seconds), do: to_millis(value, :s)
  defp to_millis(value, :sec), do: to_millis(value, :s)
  defp to_millis(value, :s), do: to_millis(value, :ms) * 1000

  defp to_millis(value, :mminutes), do: to_millis(value, :m)
  defp to_millis(value, :min), do: to_millis(value, :m)
  defp to_millis(value, :m), do: to_millis(value, :s) * 60

  defp to_millis(value, :hours), do: to_millis(value, :h)
  defp to_millis(value, :h), do: to_millis(value, :m) * 60

  defp to_millis(value, :days), do: to_millis(value, :d)
  defp to_millis(value, :d), do: to_millis(value, :h) * 24

  defp to_millis(value, :weeks), do: to_millis(value, :d)
  defp to_millis(value, :w), do: to_millis(value, :d) * 7

  defp convert_naive_to_timezone(naive_next, crontab, timezone, opts) do
    next = DateTime.from_naive(naive_next, timezone)
    case next do
      {:gap, _just_before, just_after} ->
        opts
        |> Keyword.get(:nonexistent_time_strategy, :skip)
        |> case do
          :skip ->
            get_next_and_delay(just_after, crontab, opts)
            |> elem(0)

          :adjust ->
            adjust_non_existent_time(naive_next, timezone)
        end

      {:ambiguous, _first_dt, second_dt} ->
        second_dt

      {:ok, dt} ->
        dt
    end
  end

  defp adjust_non_existent_time(
         %NaiveDateTime{} = naive_date,
         timezone
       ) do
    # Assume that midnight of the non-existent day is in a valid period
    naive_start_of_day = NaiveDateTime.beginning_of_day(naive_date)
    difference_from_midnight = NaiveDateTime.diff(naive_date, naive_start_of_day)

    naive_start_of_day
      |> DateTime.from_naive!(timezone)
      |> DateTime.shift(second: difference_from_midnight)


  end
end
