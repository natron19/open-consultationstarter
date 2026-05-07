class ConsultationPlansController < ApplicationController
  before_action :set_consultation

  def create
    result = GeminiService.generate(
      template: "consultationstarter_meeting_plan_v1",
      variables: {
        topic:              @consultation.topic,
        decision_paragraph: @consultation.decision_paragraph,
        duration_minutes:   @consultation.duration_minutes,
        context:            @consultation.context.presence || "(none provided)",
        participants_list:  @consultation.participants.map { |p| "- #{p.name} (#{p.role})" }.join("\n")
      }
    )

    plan = @consultation.consultation_plan || @consultation.build_consultation_plan
    json_start = result.index("{")
    json_end   = result.rindex("}")
    stripped   = (json_start && json_end) ? result[json_start..json_end] : result

    ActiveRecord::Base.transaction do
      parsed = JSON.parse(stripped)
      plan.assign_attributes(
        purpose_statement:        parsed["purpose_statement"],
        success_criteria:         parsed["success_criteria"].to_json,
        pre_meeting_questions:    parsed["pre_meeting_questions"].to_json,
        facilitator_prompts:      parsed["facilitator_prompts"].to_json,
        decision_record_template: parsed["decision_record_template"],
        gemini_raw:               result
      )
      plan.save!
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "consultation_plans/plan",
          locals: { plan: plan, consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation) }
    end

  rescue JSON::ParserError
    plan.update_column(:gemini_raw, result) if plan.persisted?
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "consultation_plans/parse_error",
          locals: { raw_response: result, consultation: @consultation }
        )
      end
      format.html do
        redirect_to consultation_path(@consultation),
                    alert: "Plan generated but response could not be parsed. See raw output."
      end
    end

  rescue GeminiService::BudgetExceededError
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "shared/ai_error",
          locals: { error_type: :budget_exceeded, consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation), alert: "Daily AI limit reached." }
    end

  rescue GeminiService::GatekeeperError
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "shared/ai_error",
          locals: { error_type: :gatekeeper_blocked, consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation), alert: "Input blocked by content filter." }
    end

  rescue GeminiService::TimeoutError
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "shared/ai_error",
          locals: { error_type: :timeout, consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation), alert: "Gemini timed out. Try again." }
    end

  rescue GeminiService::GeminiError
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "shared/ai_error",
          locals: { error_type: :error, consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation), alert: "AI error. Try again." }
    end
  end

  def destroy
    @consultation.consultation_plan&.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "plan-region",
          partial: "consultations/no_plan_cta",
          locals: { consultation: @consultation }
        )
      end
      format.html { redirect_to consultation_path(@consultation), notice: "Plan discarded." }
    end
  end

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:consultation_id])
  end
end
