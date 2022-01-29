defmodule Quizer.Utils do
  @moduledoc """
  Quizer is composed of modules related to a specific lesson or core piece of functionality.

  Lessons such as "DataTypes" are then broken up into Exercise, Lesson, and Visualization.
  """

  def to_atom_key(integer) when is_integer(integer) do
    integer |> Integer.to_string() |> String.to_atom()
  end

  def to_integer_key(atom) when is_atom(atom) do
    atom |> Atom.to_string() |> Integer.parse() |> elem(0)
  end
end
