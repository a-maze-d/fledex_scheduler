defmodule SchedEx.Runner do
  @moduledoc false

  use GenServer

  @doc """
  Main point of entry into this module. Starts and returns a process which will
  run the given function per the specified `job` definition
  """
  def run(%Job{name: name} = job, opts) do
    GenServer.start_link(__MODULE__, {job, opts}, [name: name])
  end

  def update(%Job{name: name} = job, opts) do
    GenServer.call(name, {:update, job, opts})
  end

  def next_schedule(%Job{name: name} = _job) do
    GenServer.call(name, :next_schedule)
  end
  def next_schedule(name) do
    GenServer.call(name, :next_schedule)
  end

  @doc """
  Returns stats for the given process.
  """
  def stats(pid) when is_pid(pid) do
    GenServer.call(pid, :stats)
  end

  def stats(_pid) do
    {:error, "Not a statable pid"}
  end

  @doc """
  Cancels future invocation of the given process. If it has already been invoked, does nothing.
  """
  def cancel(pid) when is_pid(pid) do
    :shutdown = send(pid, :shutdown)
    :ok
  end

  def cancel(_pid) do
    {:error, "Not a cancellable pid"}
  end

  # MARK: Server API
  def init({%Job{schedule: _schedule, func: _func, context: _context} = job, opts}) do
    Process.flag(:trap_exit, true)

    start_time = Keyword.get(opts, :start_time, DateTime.utc_now())

    {
      :ok,
      %{
        job: nil,
        timer_ref: nil,
        quantized_scheduled_at: nil,
        scheduled_at: nil,
        delay: nil,
        stats: %SchedEx.Stats{},
        opts: nil
      },
      {:continue, {start_time, job, opts}}
    }
  end

  def to_job(func, spec, job_opts) do
    spec =
      case spec do
        milliseconds when is_integer(milliseconds) -> {milliseconds, :ms}
        {_value, _unit} = delay -> delay
        %Crontab.CronExpression{} = crontab -> crontab
      end

    %Job{
      name: Keyword.get(job_opts, :name, :default_name),
      func: func,
      schedule: spec,
      opts: [
        timezone: Keyword.get(job_opts, :timezone, "Etc/UTC"),
        overlap: Keyword.get(job_opts, :overlap, false),
        run_once: Keyword.get(job_opts, :run_once, false),
        repeat: Keyword.get(job_opts, :repeat, false)
      ],
      context: Keyword.get(job_opts, :context, %{})
    }
  end

  def handle_continue({start_time, job, opts}, state) do
    # IO.puts("handle_continue...")
    case schedule_next(start_time, job, opts) do
      {%DateTime{} = next_time, quantized_next_time, next_delay, timer_ref} ->
        stats = %SchedEx.Stats{}

        {:noreply,
         %{
           job: job,
           timer_ref: timer_ref,
           quantized_scheduled_at: quantized_next_time,
           scheduled_at: next_time,
           delay: next_delay,
           stats: stats,
           opts: opts
         }}

      {:error, _} ->
        # IO.puts("stopping...")
        # adjusting to do the same as the normal operation (see handle_info)
        # add the job and opts to the state to support debugging.
        {:stop, :normal, %{state | job: job, opts: opts}}
        # :ignore
    end
  end

  def handle_call(
        :next_schedule,
        _from,
        %{
          scheduled_at: scheduled_at,
          quantized_scheduled_at: quantized_next_time,
          delay: delay
        } = state
      ) do
    {:reply, {scheduled_at, quantized_next_time, delay}, state}
  end

  def handle_call(:stats, _from, %{stats: stats} = state) do
    {:reply, stats, state}
  end

  def handle_call(
        {:update, %Job{} = job, opts},
        _from,
        %{
          timer_ref: timer_ref,
          stats: stats
        } = _state
      ) do
    _ignore = Process.cancel_timer(timer_ref)
    start_time = Keyword.get(opts, :start_time, DateTime.utc_now())

    # IO.puts("handle_call...")
    new_state = case schedule_next(start_time, job, opts) do
      {%DateTime{} = next_time, quantized_next_time, next_delay, timer_ref} ->
        %{
          job: job,
          timer_ref: timer_ref,
          quantized_scheduled_at: quantized_next_time,
          scheduled_at: next_time,
          delay: next_delay,
          stats: stats,
          opts: opts
        }

      {:error, _} ->
        :shutdown = send(self(), :shutdown)
        %{
          job: job,
          timer_ref: nil,
          quantized_scheduled_at: nil,
          scheduled_at: nil,
          delay: nil,
          stats: stats,
          opts: opts
        }
    end
    {:reply, :ok, new_state}

  end

  def handle_info(
        :run,
        %{
          job: job,
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

    if Keyword.get(job.opts, :repeat, false) do
      # IO.puts("handle_info...")
      case schedule_next(this_time, job, opts) do
        {%DateTime{} = next_time, quantized_next_time, next_delay, timer_ref} ->
          {:noreply,
           %{
             state
             | scheduled_at: next_time,
               quantized_scheduled_at: quantized_next_time,
               delay: next_delay,
               timer_ref: timer_ref,
               stats: stats
           }}

        _ ->
          # IO.puts("stopping...")
          # Why is this considered as a normal stop? Isn't this an error?
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

  defp run_func(this_time, %{job: %Job{func: func}} = _state) do
    if is_function(func, 1) do
      func.(this_time)
    else
      func.()
    end
  end

  defp schedule_next(%DateTime{} = from, job, opts) do
    case get_next_and_delay(from, job, opts) do
      {:error, _} = error ->
        error

      {next_time, next_delay} ->
        # IO.puts("scheduling next: #{inspect {next_time, next_delay}}")
        timer_ref = Process.send_after(self(), :run, next_delay)

        {
          next_time,
          DateTime.shift(DateTime.utc_now(), microsecond: {next_delay * 1000, 6}),
          next_delay,
          timer_ref
        }
    end
  end

  defp get_next_and_delay(from, %Job{schedule: {value, unit}} = _job, opts) do
    time_scale = Keyword.get(opts, :time_scale, SchedEx.IdentityTimeScale)

    delay = to_millis(value, unit)
    delay = round(delay / time_scale.speedup())

    next = DateTime.shift(from, microsecond: {delay * 1000, 6})
    new_delay = max(DateTime.diff(next, from, :millisecond), 0)

    {next, new_delay}
  end

  defp get_next_and_delay(
         %DateTime{} = _from,
         %Job{
           schedule: crontab,
           opts: job_opts
         } = job,
         opts
       ) do
    time_scale = Keyword.get(opts, :time_scale, SchedEx.IdentityTimeScale)
    timezone = Keyword.get(job_opts, :timezone, "Etc/UTC")
    from = time_scale.now(timezone)

    naive_from = from |> DateTime.to_naive()

    case Crontab.Scheduler.get_next_run_date(crontab, naive_from) do
      {:ok, naive_next} ->
        next = convert_naive_to_timezone(naive_next, job, timezone, opts)
        delay = max(DateTime.diff(next, from, :millisecond), 0)
        delay = round(delay / time_scale.speedup())
        {next, delay}

      {:error, _} = error ->
        error
    end
  end

  defp to_millis(value, :milliseconds), do: value
  defp to_millis(value, :ms), do: value

  defp to_millis(value, :seconds), do: to_millis(value, :s)
  defp to_millis(value, :sec), do: to_millis(value, :s)
  defp to_millis(value, :s), do: to_millis(value, :ms) * 1000

  defp to_millis(value, :minutes), do: to_millis(value, :m)
  defp to_millis(value, :min), do: to_millis(value, :m)
  defp to_millis(value, :m), do: to_millis(value, :s) * 60

  defp to_millis(value, :hours), do: to_millis(value, :h)
  defp to_millis(value, :h), do: to_millis(value, :m) * 60

  defp to_millis(value, :days), do: to_millis(value, :d)
  defp to_millis(value, :d), do: to_millis(value, :h) * 24

  defp to_millis(value, :weeks), do: to_millis(value, :w)
  defp to_millis(value, :w), do: to_millis(value, :d) * 7

  defp convert_naive_to_timezone(naive_next, job, timezone, opts) do
    next = DateTime.from_naive(naive_next, timezone)

    case next do
      {:gap, _just_before, just_after} ->
        opts
        |> Keyword.get(:nonexistent_time_strategy, :skip)
        |> case do
          :skip ->
            get_next_and_delay(just_after, job, opts)
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
