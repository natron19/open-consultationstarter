class ConsultationsController < ApplicationController
  before_action :set_consultation, only: [:show, :edit, :update, :destroy]

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

  def consultation_params
    params.require(:consultation).permit(
      :topic, :decision_paragraph, :duration_minutes,
      :context, :scheduled_for,
      participants_attributes: [:id, :name, :role, :_destroy]
    )
  end
end
