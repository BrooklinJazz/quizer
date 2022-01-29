defmodule Quizer.Exercise do
  @enforce_keys [:answer_key]
  defstruct @enforce_keys ++ [:form, :frame]
  require Logger

  def new(answer_key, form \\ nil) do
    %__MODULE__{answer_key: answer_key, form: form, frame: Kino.Frame.new()}
    |> validate_form_matches_answer_key()
  end

  defp validate_form_matches_answer_key(exercise) when is_nil(exercise.form) do
    exercise
  end

  defp validate_form_matches_answer_key(exercise) do
    form_keys =
      Enum.map(exercise.form.attrs.fields, fn {key, _input} ->
        key |> Quizer.Utils.to_integer_key()
      end)

    missing_keys = Map.keys(exercise.answer_key) !== form_keys
    remaining_questions = question_strings(exercise.answer_key) -- question_strings(exercise.form)
    mismatched_keys = length(remaining_questions) > 0

    cond do
      missing_keys ->
        {:error, :missing_keys}

      mismatched_keys ->
        {:error, :mismatched_questions}

      true ->
        exercise
    end
  end

  @doc ~S"""
  Generates questions based on exercise answer key
  iex> Quizer.Exercise.new(%{1 => {"", 1}}) |> Quizer.Exercise.questions()
  %{1 => {"", nil}}
  """
  def questions(exercise) do
    Enum.reduce(exercise.answer_key, %{}, fn {key, {question, _value}}, acc ->
      Map.put(acc, key, {question, nil})
    end)
  end

  def feedback(exercise, answers) do
    with %{} <- answers, {:ok, results} <- standardized_test(exercise, answers) do
      feedback_results =
        Enum.reduce(results, %{}, fn {key, {question, result, message}}, acc ->
          if result do
            acc
          else
            Map.put(acc, key, {question, message})
          end
        end)

      if feedback_results === %{}, do: "success!", else: feedback_results
    else
      _ -> {:restore, questions(exercise)}
    end
  end

  def standardized_test(exercise, form_data) when is_list(form_data) do
    standardized_test(exercise, to_answers(exercise, form_data))
  end

  def standardized_test(exercise, answers) do
    missing_keys = Map.keys(answers) !== Map.keys(exercise.answer_key)

    remaining_questions = question_strings(exercise.answer_key) -- question_strings(answers)
    mismatched_questions = length(remaining_questions) > 0

    cond do
      missing_keys ->
        {:error, :missing_keys}

      mismatched_questions ->
        {:error, :mismatched_questions}

      true ->
        {:ok, test_results(exercise, answers)}
    end
  end

  def form_data(exercise) do
    exercise.form.attrs.fields |> Enum.map(fn {key, _} -> {key, ""} end)
  end

  def form_data_key(exercise) do
    exercise
    |> form_data()
    |> Enum.map(fn {key, _} ->
      {_question, answer} = Map.get(exercise.answer_key, Quizer.Utils.to_integer_key(key))
      {key, answer}
    end)
  end

  def to_answers(exercise, form_data) do
    Enum.reduce(form_data, %{}, fn {key, answer}, acc ->
      integer_key = Quizer.Utils.to_integer_key(key)
      {question, _answer} = Map.get(exercise.answer_key, integer_key)
      Map.put(acc, integer_key, {question, answer})
    end)
  end

  def form(exercise) do
    exercise.form
  end

  def form_feedback(exercise) do
    exercise.frame
  end

  def consume_form(exercise) do
    for %{data: data} <- Kino.Control.stream(exercise.form) do
      data = feedback(exercise, to_answers(exercise, data))
      Kino.Frame.render(exercise.frame, data)
    end
  end

  def format(element) do
    cond do
      is_nil(element) ->
        "nil"

      is_boolean(element) ->
        to_string(element)

      is_bitstring(element) ->
        element

      element === %{} ->
        "%{}"

      element === [] ->
        "[]"

      is_tuple(element) ->
        inner =
          element
          |> Tuple.to_list()
          |> Enum.map(fn each ->
            format(each)
          end)
          |> Enum.join(", ")

        "{#{inner}}"

      Keyword.keyword?(element) ->
        inner =
          Enum.map(element, fn {key, value} ->
            "#{Atom.to_string(key)}: #{format(value)}"
          end)
          |> Enum.join(", ")

        "[#{inner}]"

      is_list(element) ->
        inner = element |> Enum.map(fn each -> format(each) end) |> Enum.join(", ")
        "[#{inner}]"

      is_map(element) ->
        inner =
          Enum.map(element, fn {key, value} ->
            if is_atom(key) do
              "#{Atom.to_string(key)}: #{format(value)}"
            else
              key = format(key)
              value = format(value)
              "#{key} => #{value}"
            end
          end)
          |> Enum.join(", ")

        "%{#{inner}}"

      true ->
        element
    end
  end

  defp question_strings(%Kino.Control{} = form) do
    Enum.map(form.attrs.fields, fn {_key, input} -> input.label end)
  end

  defp question_strings(answers) do
    Enum.map(answers, fn {_key, {question, _}} -> question end)
  end

  defp test_results(exercise, answers) do
    Enum.reduce(exercise.answer_key, %{}, fn
      {key, {question, assertion}}, acc ->
        {_question, actual_answer} = Map.get(answers, key)

        {result, message} =
          cond do
            is_function(assertion) -> assertion.(actual_answer)
            actual_answer === assertion -> {true, ""}
            true -> {false, "expected #{format(actual_answer)} to equal #{format(assertion)}"}
          end

        Map.put(
          acc,
          key,
          {question, result, message}
        )
    end)
  end
end
