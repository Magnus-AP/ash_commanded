defmodule AshCommanded.Commanded.Verifiers.ValidateCommandFields do
  @moduledoc """
  Verifies that all fields declared in commands exist as attributes in the resource
  or as arguments of the action the command runs.

  This ensures that commands don't reference non-existent fields, which would lead to
  runtime errors.
  """

  use Spark.Dsl.Verifier

  alias AshCommanded.Commanded.Verifiers.KnownFields
  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    commands = Verifier.get_entities(dsl_state, [:commanded, :commands])
    commands_with_invalid_fields =
      commands
      |> Enum.map(fn command -> {command.name, command.fields -- KnownFields.for_command(dsl_state, command)} end)
      |> Enum.reject(fn {_name, invalid_fields} -> invalid_fields == [] end)

    case commands_with_invalid_fields do
      [] ->
        :ok

      invalid_commands ->
        message = build_error_message(resource_module, invalid_commands)
        {:error, DslError.exception(message: message, path: [:commanded, :commands])}
    end
  end

  defp build_error_message(resource_module, invalid_commands) do
    commands_with_errors =
      invalid_commands
      |> Enum.map(fn {command_name, invalid_fields} ->
        "  - Command `#{command_name}` has unknown fields: #{inspect(invalid_fields)}"
      end)
      |> Enum.join("\n")

    """
    The following commands in #{inspect(resource_module)} reference fields that are neither attributes nor arguments of the command's action:

    #{commands_with_errors}

    All command fields must be resource attributes or arguments of the command's action.
    """
  end
end
