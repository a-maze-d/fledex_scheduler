# Copyright 2025-2026, Matthias Reik <fledex@reik.org>
# Modified version of : https://github.com/SchedEx/SchedEx
#
# SPDX-License-Identifier: MIT
defmodule Fledex.Scheduler.ExampleTest do
  use ExUnit.Case, async: false

  alias Fledex.Scheduler

  defmodule AgentHelper do
    def set(agent, value) do
      Agent.update(agent, fn _someval -> value end)
    end

    def get(agent) do
      Agent.get(agent, & &1)
    end
  end

  defmodule TestTimeScale do
    def now(_sometimezone) do
      DateTime.utc_now()
    end

    def speedup do
      86_400
    end
  end

  setup do
    {:ok, agent} = start_supervised({Agent, fn -> nil end})
    {:ok, agent: agent}
  end

  test "updates the agent at 10am every morning", context do
    Scheduler.run_every(
      AgentHelper,
      :set,
      [context.agent, :sched_ex_scheduled_time],
      "* 10 * * *",
      time_scale: TestTimeScale
    )

    # Let `Fledex.Scheduler` run through a day's worth of scheduling time
    Process.sleep(1000)

    expected_time =
      %{DateTime.utc_now() | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
      |> DateTime.shift(hour: 34)

    assert DateTime.diff(AgentHelper.get(context.agent), expected_time) == 0
  end
end
