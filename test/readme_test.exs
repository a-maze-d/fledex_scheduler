defmodule ExampleTest do
  use ExUnit.Case, async: false

  defmodule AgentHelper do
    def set(agent, value) do
      Agent.update(agent, fn _ -> value end)
    end

    def get(agent) do
      Agent.get(agent, & &1)
    end
  end

  defmodule TestTimeScale do
    def now(_) do
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

    SchedEx.run_every(AgentHelper, :set, [context.agent, :sched_ex_scheduled_time],
      "* 10 * * *",
      time_scale: TestTimeScale
    )

    # Let SchedEx run through a day's worth of scheduling time
    Process.sleep(1000)

    expected_time =
      %{DateTime.utc_now() | hour: 0, minute: 0, second: 0, microsecond: {0, 0}}
      |> DateTime.shift(hour: 34)

    assert DateTime.diff(AgentHelper.get(context.agent), expected_time) == 0
  end
end
