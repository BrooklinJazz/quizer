defmodule Quizer.ExerciseTest do
  use ExUnit.Case
  doctest Quizer.Exercise
  alias Quizer.Exercise

  describe "new" do
    test "valid" do
      answer_key = %{1 => {"question", 1}}
      %{answer_key: ^answer_key} = exercise = Exercise.new(answer_key)

      assert {:ok, %{1 => {"question", true, _}}} =
               Exercise.standardized_test(exercise, answer_key)
    end

    test "valid with function answer key" do
      answer_key = %{1 => {"question", {:assert, [fn each -> each === 3 end], 3}}}
      %{answer_key: ^answer_key} = exercise = Exercise.new(answer_key)

      assert {:ok, %{1 => {"question", true, _}}} =
               Exercise.standardized_test(exercise, answer_key)
    end

    test "valid with form" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      assert Exercise.new(answer_key, form)
    end

    test "form invalid keys" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "2": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      assert {:error, :missing_keys} === Exercise.new(answer_key, form)
    end

    test "form invalid labels" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("mismatched question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      assert {:error, :mismatched_questions} === Exercise.new(answer_key, form)
    end
  end

  describe "standardized_test/2" do
    test "correct answers" do
      answer_key = %{1 => {"question", 1}}
      exercise = Exercise.new(answer_key)

      assert {:ok, %{1 => {"question", true, ""}}} ==
               Exercise.standardized_test(exercise, exercise.answer_key)
    end

    test "one incorrect answer" do
      answer_key = %{1 => {"question", 1}}
      incorrect_answers = %{1 => {"question", 2}}
      exercise = Exercise.new(answer_key)

      assert {:ok, %{1 => {"question", false, "expected 2 to equal 1"}}} ==
               Exercise.standardized_test(exercise, incorrect_answers)
    end

    test "non String.Chars answers are formatted" do
      for item <- [%{}, []] do
        answer_key = %{1 => {"question", 1}}
        incorrect_answers = %{1 => {"question", item}}
        exercise = Exercise.new(answer_key)

        assert {:ok, %{1 => {"question", false, "expected #{Exercise.format(item)} to equal 1"}}} ==
                 Exercise.standardized_test(exercise, incorrect_answers)
      end
    end

    test "correct answers with function in answer key" do
      answer_key = %{
        1 =>
          {"question",
           fn actual ->
             cond do
               actual !== 1 -> {false, ""}
               true -> {true, ""}
             end
           end}
      }

      answers = %{1 => {"question", 1}}
      exercise = Exercise.new(answer_key)

      assert {:ok, %{1 => {"question", true, _}}} = Exercise.standardized_test(exercise, answers)
    end

    test "answers in invalid format" do
      answer_key = %{1 => {"question", 1}}
      exercise = Exercise.new(answer_key)

      assert {:error, :missing_keys} =
               Exercise.standardized_test(exercise, %{2 => {"question", 1}})

      assert {:error, :mismatched_questions} =
               Exercise.standardized_test(exercise, %{1 => {"non-matching_question", 1}})
    end

    test "with form data" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      exercise = Exercise.new(answer_key, form)

      assert {:ok, %{1 => {"question", true, _}}} =
               Exercise.standardized_test(exercise, Exercise.form_data_key(exercise))
    end
  end

  describe "feedback" do
    test "correct answers" do
      answer_key = %{1 => {"question 1", 1}}
      exercise = Exercise.new(answer_key)

      assert "success!" ==
               Exercise.feedback(exercise, exercise.answer_key)
    end

    test "one incorrect answer out of two" do
      answer_key = %{1 => {"question 1", 1}, 2 => {"question 2", 2}}
      incorrect_answers = %{1 => {"question 1", 1}, 2 => {"question 2", 1}}
      exercise = Exercise.new(answer_key)

      assert %{2 => {"question 2", "expected 1 to equal 2"}} ==
               Exercise.feedback(exercise, incorrect_answers)
    end

    test "invalid answers: empty map" do
      answer_key = %{1 => {"question 1", 1}}
      invalid_answers = %{}
      exercise = Exercise.new(answer_key)

      assert {:restore, Exercise.questions(exercise)} ==
               Exercise.feedback(exercise, invalid_answers)
    end

    test "invalid answers: wrong data type" do
      answer_key = %{1 => {"question 1", 1}}
      invalid_answers = ""
      exercise = Exercise.new(answer_key)

      assert {:restore, Exercise.questions(exercise)} ==
               Exercise.feedback(exercise, invalid_answers)
    end
  end

  describe "form_data" do
    test "matches expected format" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      exercise = Exercise.new(answer_key, form)

      assert ["1": ""] = Exercise.form_data(exercise)
    end
  end

  describe "form_data_key" do
    test "returns form data with answers matching key" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      exercise = Exercise.new(answer_key, form)

      assert ["1": 1] = Exercise.form_data_key(exercise)
    end
  end

  describe "to_answers" do
    test "converts form data to answer format" do
      answer_key = %{1 => {"question", 1}}

      inputs = [
        "1": Kino.Input.text("question")
      ]

      form =
        Kino.Control.form(
          inputs,
          submit: "Send"
        )

      exercise = Exercise.new(answer_key, form)

      form_data = Exercise.form_data(exercise)
      assert %{1 => {"question", ""}} === Exercise.to_answers(exercise, form_data)
    end
  end

  describe "format" do
    test "values without String.Chars" do
      assert Exercise.format(nil) === "nil"
      assert Exercise.format(false) === "false"
      assert Exercise.format(true) === "true"
      assert Exercise.format(%{}) === "%{}"
      assert Exercise.format([]) === "[]"
      assert Exercise.format(1) === 1
      assert Exercise.format([1, 1, 1]) === "[1, 1, 1]"
      assert Exercise.format(test: "ok") === "[test: ok]"

      assert Exercise.format({}) === "{}"
      assert Exercise.format({%{}, 1}) === "{%{}, 1}"
      assert Exercise.format("") === ""
      assert Exercise.format("hello") === "hello"
      assert Exercise.format(:atom) === :atom
      assert Exercise.format(%{test: "OK"}) === "%{test: OK}"
      assert Exercise.format(%{"test" => "OK"}) === "%{test => OK}"

      assert Exercise.format(%{%{test: 1} => %{"test" => 1}}) ===
               "%{%{test: 1} => %{test => 1}}"
    end
  end
end
