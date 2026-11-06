import Config

# This library's tests exercise command mapping without a data layer, so
# commands return a stub instead of running their Ash action.
config :ash_commanded, mock_actions?: true
