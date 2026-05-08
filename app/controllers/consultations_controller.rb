class ConsultationsController < ApplicationController
  before_action :set_consultation, only: [:show, :edit, :update, :destroy, :download]

  def index
    @consultations = if params[:sort] == "soonest"
      current_user.consultations.order("scheduled_for ASC NULLS LAST")
    else
      current_user.consultations.order(created_at: :desc)
    end
  end

  def new
    @consultation = current_user.consultations.build
    2.times { @consultation.participants.build }
  end

  def create
    @consultation = current_user.consultations.build(consultation_params)
    if @consultation.save
      redirect_to consultation_path(@consultation), notice: "Consultation saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @plan = @consultation.consultation_plan
  end

  def download
    plan = @consultation.consultation_plan
    redirect_to consultation_path(@consultation), alert: "No plan to download yet." and return unless plan

    markdown = build_markdown_document(@consultation, plan)
    filename = "#{@consultation.topic.parameterize}-consultation-plan.md"
    send_data markdown, filename: filename, type: "text/markdown", disposition: "attachment"
  end

  def edit
  end

  def update
    if @consultation.update(consultation_params)
      redirect_to consultation_path(@consultation), notice: "Consultation updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @consultation.destroy
    redirect_to consultations_path, notice: "Consultation deleted."
  end

  private

  def set_consultation
    @consultation = current_user.consultations.find(params[:id])
  end

  def build_markdown_document(consultation, plan)
    lines = []
    lines << "# #{consultation.topic}"
    lines << ""

    meta = []
    meta << "**Date:** #{consultation.scheduled_for.strftime("%B %-d, %Y at %-I:%M %p")}" if consultation.scheduled_for
    meta << "**Duration:** #{consultation.duration_minutes} min"
    meta << "**Participants:** #{consultation.participants.map(&:name).join(", ")}"
    lines << meta.join(" | ")
    lines << ""

    if consultation.context.present?
      lines << "## Context"
      lines << ""
      lines << consultation.context
      lines << ""
    end

    lines << "## Decision Under Consideration"
    lines << ""
    lines << consultation.decision_paragraph
    lines << ""
    lines << "---"
    lines << ""
    lines << "## Consultation Plan"
    lines << ""
    lines << "### Purpose Statement"
    lines << ""
    lines << plan.purpose_statement
    lines << ""

    lines << "### Success Criteria"
    lines << ""
    plan.success_criteria_array.each_with_index do |criterion, i|
      lines << "#{i + 1}. #{criterion}"
    end
    lines << ""

    lines << "### Pre-Meeting Questions"
    lines << ""
    plan.pre_meeting_questions_array.each do |q|
      lines << "- **#{q["question"]}** *(#{q["principle"]})*"
    end
    lines << ""

    lines << "### Facilitator Prompts"
    lines << ""
    plan.facilitator_prompts_array.each_with_index do |fp, i|
      lines << "#{i + 1}. **#{fp["prompt"]}** *(#{fp["principle"]})*"
      lines << "   *When to use: #{fp["when_to_use"]}*"
      lines << ""
    end

    lines << "### Decision Record Template"
    lines << ""
    lines << plan.decision_record_template
    lines << ""

    lines.join("\n")
  end

  def consultation_params
    params.require(:consultation).permit(
      :topic, :decision_paragraph, :duration_minutes,
      :context, :scheduled_for,
      participants_attributes: [:id, :name, :role, :_destroy]
    )
  end
end
