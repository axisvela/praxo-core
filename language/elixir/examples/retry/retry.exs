defmodule RetryExample do
  def run(failures, max_attempts \\ 3) do
    Enum.reduce_while(1..max_attempts, nil, fn attempt, _ ->
      cond do
        attempt > failures ->
          {:halt, {:ok, "status: green", attempt}}

        attempt == max_attempts ->
          {:halt, {:error, "MODEL_UNAVAILABLE", attempt}}

        true ->
          {:cont, nil}
      end
    end)
  end
end

{:ok, "status: green", 3} = RetryExample.run(2)
{:error, "MODEL_UNAVAILABLE", 3} = RetryExample.run(3)
IO.puts("Elixir retry example passed")
