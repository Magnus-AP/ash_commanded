defmodule AshCommanded.Commanded.Verifiers.ValidateEventFields do
  @moduledoc """
  Verifies that all fields declared in events exist as attributes in the resource
  or as arguments of the action the command runs.

  This ensures that events don't reference non-existent fields, which would lead to
  runtime errors.
  """

  use Spark.Dsl.Verifier

  alias AshCommanded.Commanded.Verifiers.KnownFields
  alias Spark.Dsl.Verifier
  alias Spark.Error.DslError

  @impl true
  def verify(dsl_state) do
    resource_module = Verifier.get_persisted(dsl_state, :module)
    events = Verifier.get_entities(dsl_state, [:commanded, :events])
    events_with_invalid_fields =
      events
      |> Enum.map(fn event -> {event.name, event.fields -- KnownFields.for_event(dsl_state, event)} end)
      |> Enum.reject(fn {_name, invalid_fields} -> invalid_fields == [] end)

    case events_with_invalid_fields do
      [] ->
        :ok

      invalid_events ->
        message = build_error_message(resource_module, invalid_events)
        {:error, DslError.exception(message: message, path: [:commanded, :events])}
    end
  end

  defp build_error_message(resource_module, invalid_events) do
    events_with_errors =
      invalid_events
      |> Enum.map(fn {event_name, invalid_fields} ->
        "  - Event `#{event_name}` has unknown fields: #{inspect(invalid_fields)}"
      end)
      |> Enum.join("\n")

    """
    The following events in #{inspect(resource_module)} reference fields that are neither attributes nor arguments of the command's action:

    #{events_with_errors}

    All event fields must be resource attributes or arguments of the command's action.
    """
  end
end
