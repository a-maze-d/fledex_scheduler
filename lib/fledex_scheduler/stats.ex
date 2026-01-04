# Copyright 2025-2026, Matthias Reik <fledex@reik.org>
# Modified version of : https://github.com/SchedEx/SchedEx
#
# SPDX-License-Identifier: MIT
defmodule Fledex.Scheduler.Stats do
  @moduledoc """
  Some stats.

  > #### Caution {: .warning}
  > This is likely to be removed and replaced with telemetry
  """

  alias Fledex.Scheduler.Stats.Value

  defstruct scheduling_delay: %Value{}, quantization_error: %Value{}, execution_time: %Value{}

  @type t :: %__MODULE__{
          scheduling_delay: Value.t(),
          quantization_error: Value.t(),
          execution_time: Value.t()
        }

  @doc """
  Update the stats with some new measurement
  """
  @spec update(t(), DateTime.t(), DateTime.t(), DateTime.t(), DateTime.t()) :: t()
  def update(
        %__MODULE__{
          scheduling_delay: %Value{} = scheduling_delay,
          quantization_error: %Value{} = quantization_error,
          execution_time: %Value{} = execution_time
        },
        %DateTime{} = scheduled_start,
        %DateTime{} = quantized_scheduled_start,
        %DateTime{} = actual_start,
        %DateTime{} = actual_end
      ) do
    %__MODULE__{
      scheduling_delay:
        scheduling_delay
        |> Value.update(DateTime.diff(actual_start, quantized_scheduled_start, :microsecond)),
      quantization_error:
        quantization_error
        |> Value.update(
          abs(DateTime.diff(quantized_scheduled_start, scheduled_start, :microsecond))
        ),
      execution_time:
        execution_time
        |> Value.update(DateTime.diff(actual_end, actual_start, :microsecond))
    }
  end
end
