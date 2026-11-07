defmodule AshCommanded.Commanded.CommandProcessor do
  @moduledoc """
  Runs a command's Ash action for a generated aggregate and turns the
  result into the command's event.

  Generated aggregates call `process/8` from their `execute/2`, after the
  command's middleware. It lives here rather than in each generated module
  so the per-command options arrive as data: generated code then has no
  branches on compile-time constants and no helper clause repeated per
  command, which Elixir's type checker reports as warnings in the
  application that compiles the resource.
  """

  alias AshCommanded.Commanded.CommandActionMapper
  alias AshCommanded.Commanded.Error

  @typedoc """
  What the command adds to the action's context: `:include_aggregate?`,
  `:include_command?`, `:include_metadata?`, `:context_prefix` and
  `:static_context`.
  """
  @type context_options :: keyword()

  @doc "The command's metadata, or an empty map when it carries none."
  @spec metadata(struct()) :: map()
  def metadata(command), do: Map.get(command, :metadata, %{})

  @doc """
  Runs `action_name` on `resource_module` for `command` and returns
  `{:ok, event}`, or the action's error. A command whose identity differs
  from the aggregate's is refused.
  """
  @spec process(
          struct(),
          struct(),
          module(),
          atom(),
          atom(),
          module(),
          keyword(),
          context_options()
        ) :: {:ok, struct()} | {:error, term()}
  def process(
        aggregate,
        command,
        resource_module,
        action_name,
        identity_field,
        event_module,
        opts,
        context_options
      ) do
    command_id = Map.get(command, identity_field)
    aggregate_id = Map.get(aggregate, identity_field)

    # A new aggregate has no id yet; an existing one only takes its own commands.
    if is_nil(aggregate_id) or aggregate_id == command_id do
      action_opts =
        opts ++
          [
            identity_field: identity_field,
            context: action_context(opts, aggregate, command, context_options)
          ]

      command
      |> CommandActionMapper.map_to_action(resource_module, action_name, action_opts)
      |> to_event(command, event_module)
    else
      {:error,
       Error.aggregate_error("Invalid identity",
         field: identity_field,
         value: command_id,
         context: %{aggregate_id: aggregate_id, command_id: command_id}
       )}
    end
  end

  # The event carries the command's fields, plus any plain-map data the
  # action returned. A record (a struct) adds nothing.
  defp to_event({:ok, result}, command, event_module) do
    event_data = Map.from_struct(command)

    event_data =
      if is_map(result) and not is_struct(result),
        do: Map.merge(event_data, result),
        else: event_data

    {:ok, struct(event_module, event_data)}
  end

  # Already standardised by CommandActionMapper.
  defp to_event({:error, reason}, _command, _event_module), do: {:error, reason}

  defp action_context(opts, aggregate, command, context_options) do
    prefix = Keyword.get(context_options, :context_prefix)

    opts
    |> Keyword.get(:context, %{})
    |> put_if(
      Keyword.get(context_options, :include_aggregate?),
      key(prefix, :aggregate),
      aggregate
    )
    |> put_if(Keyword.get(context_options, :include_command?), key(prefix, :command), command)
    |> put_metadata(Keyword.get(context_options, :include_metadata?), prefix, command)
    |> Map.merge(Keyword.get(context_options, :static_context) || %{})
  end

  defp put_if(context, true, key, value), do: Map.put(context, key, value)
  defp put_if(context, _include?, _key, _value), do: context

  defp put_metadata(context, true, prefix, %{metadata: metadata}) when is_map(metadata),
    do: Map.put(context, key(prefix, :metadata), metadata)

  defp put_metadata(context, _include?, _prefix, _command), do: context

  defp key(nil, name), do: name
  defp key(prefix, name), do: :"#{prefix}.#{name}"
end
