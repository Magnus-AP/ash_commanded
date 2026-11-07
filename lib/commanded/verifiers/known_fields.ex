defmodule AshCommanded.Commanded.Verifiers.KnownFields do
  @moduledoc false
  # The fields a command or event may declare: the resource's attributes,
  # plus the arguments of the Ash action the command runs. A command often
  # carries data its action takes as arguments rather than storing as
  # attributes (an amount, a reference, an account), and its event records
  # the same data.

  alias Spark.Dsl.Verifier

  @doc "Attribute names plus the arguments of the action `command` runs."
  @spec for_command(map(), struct()) :: [atom()]
  def for_command(dsl_state, command) do
    attributes(dsl_state) ++ arguments(dsl_state, command.action || command.name)
  end

  @doc """
  Attribute names plus the arguments of the action run by the command the
  event answers (the command with the event's name), if there is one.
  """
  @spec for_event(map(), struct()) :: [atom()]
  def for_event(dsl_state, event) do
    commands = Verifier.get_entities(dsl_state, [:commanded, :commands])

    case Enum.find(commands, &(&1.name == event.name)) do
      nil -> attributes(dsl_state)
      command -> for_command(dsl_state, command)
    end
  end

  defp attributes(dsl_state) do
    dsl_state
    |> Verifier.get_entities([:attributes])
    |> Enum.map(& &1.name)
  end

  defp arguments(dsl_state, action_name) do
    dsl_state
    |> Verifier.get_entities([:actions])
    |> Enum.find(&(&1.name == action_name))
    |> case do
      nil -> []
      action -> Enum.map(Map.get(action, :arguments, []), & &1.name)
    end
  end
end
