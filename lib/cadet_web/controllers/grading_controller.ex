defmodule CadetWeb.GradingController do
  use CadetWeb, :controller
  use PhoenixSwagger

  alias Cadet.Assessments

  def index(conn, %{"options" => options}) do
    # when is_ecto_id(options["pageNo"]) and options["group"] in ["true", "false"] do
    user = conn.assigns[:current_user]

    group =
      if options["group"] in ["true", "false"] do
        String.to_atom(options["group"])
      else
        false
      end

    page_size = options["pageSize"]
    page_no = if options["pageNo"] < 1, do: 1, else: options["pageNo"]
    searchTags = List.first(options["searchTags"])
    filterModel = options["filterModel"]["filterModel"]
    sortModel = options["sortModel"]["sortModel"]

    IO.inspect(searchTags)
    IO.inspect(filterModel)
    IO.inspect(sortModel)

    case Assessments.all_submissions_by_grader(
           user,
           page_size,
           page_no,
           group,
           searchTags,
           filterModel,
           sortModel
         ) do
      {:ok, {submissions, metadata}} ->
        render(
          conn,
          "index.json",
          submissions: submissions,
          metadata: metadata
        )

      {:error, {status, message}} ->
        conn
        |> put_status(status)
        |> text(message)
    end
  end

  def index(conn, _) do
    index(conn, %{"group" => "false"})
  end

  def show(conn, %{"submissionid" => submission_id}) when is_ecto_id(submission_id) do
    user = conn.assigns[:current_user]

    case Assessments.get_answers_in_submission(submission_id, user) do
      {:ok, answers} ->
        render(conn, "show.json", answers: answers)

      {:error, {status, message}} ->
        conn
        |> put_status(status)
        |> text(message)
    end
  end

  def update(
        conn,
        %{
          "submissionid" => submission_id,
          "questionid" => question_id,
          "grading" => raw_grading
        }
      )
      when is_ecto_id(submission_id) and is_ecto_id(question_id) do
    user = conn.assigns[:current_user]

    grading =
      if raw_grading["xpAdjustment"] do
        Map.put(raw_grading, "xp_adjustment", raw_grading["xpAdjustment"])
      else
        raw_grading
      end

    case Assessments.update_grading_info(
           %{submission_id: submission_id, question_id: question_id},
           grading,
           user
         ) do
      {:ok, _} ->
        text(conn, "OK")

      {:error, {status, message}} ->
        conn
        |> put_status(status)
        |> text(message)
    end
  end

  def update(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> text("Missing parameter")
  end

  swagger_path :index do
    post("/grading")

    summary("Get a list of all submissions with current user as the grader.")

    security([%{JWT: []}])

    consumes("application/json")
    produces("application/json")

    parameters do
      options(
        :body,
        Schema.ref(:PaginateOptions),
        "Metadata for server-side pagination",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:Submissions_overview))
    response(400, "Invalid or missing parameter(s) or malformed options JSON")
    response(401, "Unauthorised")
    response(500, "Internal server error")
  end

  swagger_path :show do
    get("/grading/{submissionId}")

    summary("Get information about a specific submission to be graded.")

    security([%{JWT: []}])

    produces("application/json")

    parameters do
      submissionId(:path, :integer, "submission id", required: true)
    end

    response(200, "OK", Schema.ref(:GradingInfo))
    response(400, "Invalid or missing parameter(s) or submission and/or question not found")
    response(401, "Unauthorised")
  end

  swagger_path :update do
    post("/grading/{submissionId}/{questionId}")

    summary(
      "Update comment and/or marks given to the answer of a particular querstion in a submission"
    )

    security([%{JWT: []}])

    consumes("application/json")
    produces("application/json")

    parameters do
      submissionId(:path, :integer, "submission id", required: true)
      questionId(:path, :integer, "question id", required: true)
      grading(:body, Schema.ref(:Grading), "comment given for a question", required: true)
    end

    response(200, "OK")
    response(400, "Invalid or missing parameter(s) or submission and/or question not found")
    response(401, "Unauthorised")
  end

  def swagger_definitions do
    %{
      PaginateOptions:
        swagger_schema do
          properties do
            options(
              Schema.new do
                properties do
                  filterModel(
                    :string,
                    "A JSON object representing the state of filters applied to the grid",
                    required: true
                  )

                  group(
                    :boolean,
                    "Show only students in the grader's group when true",
                    required: true
                  )

                  pageSize(
                    :integer,
                    "Specifies number of results to retrieve",
                    required: true
                  )

                  pageNo(
                    :integer,
                    "Specifies page number of results to retrieve",
                    required: true
                  )

                  searchTags(
                    :string,
                    "An array of strings, each representing a search term",
                    required: true
                  )

                  sortModel(
                    :string,
                    "A JSON object representing the sorting state of the grid",
                    required: true
                  )
                end
              end
            )
          end

          required(:options)
        end,
      Submissions_overview:
        swagger_schema do
          properties do
            submissions(Schema.ref(:Submission), "Array of submissions")
            paginateDets(Schema.ref(:PaginateDets), "Details for browser pagination")
          end
        end,
      PaginateDets:
        swagger_schema do
          properties do
            pageNo(:integer, "Current page of submission entries", required: true)
            maxPages(:integer, "Maximum number of pages of entries", required: true)
          end
        end,
      Submissions:
        swagger_schema do
          type(:array)
          items(Schema.ref(:Submission))
        end,
      Submission:
        swagger_schema do
          properties do
            id(:integer, "submission id", required: true)
            grade(:integer, "grade given")
            xp(:integer, "xp earned")
            xpBonus(:integer, "bonus xp for a given submission")
            xpAdjustment(:integer, "xp adjustment given")
            adjustment(:integer, "grade adjustment given")
            groupName(:string, "name of student's group")

            status(
              :string,
              "one of 'not_attempted/attempting/attempted/submitted' indicating whether the assessment has been attempted by the current user"
            )

            assessment(Schema.ref(:AssessmentInfo))
            student(Schema.ref(:StudentInfo))
          end
        end,
      AssessmentInfo:
        swagger_schema do
          properties do
            id(:integer, "assessment id", required: true)
            type(:string, "Either mission/sidequest/path/contest", required: true)
            title(:string, "Mission title", required: true)
            coverImage(:string, "The URL to the cover picture", required: true)

            maxGrade(
              :integer,
              "The max grade for this assessment",
              required: true
            )

            maxXp(
              :integer,
              "The max xp for this assessment",
              required: true
            )
          end
        end,
      StudentInfo:
        swagger_schema do
          properties do
            id(:integer, "student id", required: true)
            name(:string, "student name", required: true)
          end
        end,
      GraderInfo:
        swagger_schema do
          properties do
            id(:integer, "grader id", required: true)
            name(:string, "grader name", required: true)
          end
        end,
      GradingInfo:
        swagger_schema do
          description(
            "A list of questions with submitted answers, solution and previous grading info " <>
              "if available"
          )

          type(:array)

          items(
            Schema.new do
              properties do
                question(Schema.ref(:Question))
                grade(Schema.ref(:Grade))
                student(Schema.ref(:StudentInfo))

                solution(
                  :string,
                  "the marking scheme and model solution to this question. Only available for programming questions",
                  required: true
                )

                maxGrade(
                  :integer,
                  "the max grade that can be given to this question",
                  required: true
                )

                maxXp(
                  :integer,
                  "the max xp that can be given to this question",
                  required: true
                )
              end
            end
          )
        end,
      Grade:
        swagger_schema do
          properties do
            grade(:integer, "Grade awarded by autograder")
            xp(:integer, "XP awarded by autograder")
            comment(:string, "comment given")
            adjustment(:integer, "grade adjustment given")
            xpAdjustment(:integer, "xp adjustment given")
            grader(Schema.ref(:GraderInfo))
            gradedAt(:string, "Last graded at", format: "date-time", required: false)
          end
        end,
      Grading:
        swagger_schema do
          properties do
            grading(
              Schema.new do
                properties do
                  comment(:string, "comment given")
                  adjustment(:integer, "grade adjustment given")
                  xpAdjustment(:integer, "xp adjustment given")
                end
              end
            )
          end
        end
    }
  end
end
