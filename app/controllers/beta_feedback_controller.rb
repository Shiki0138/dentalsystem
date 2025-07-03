class BetaFeedbackController < ApplicationController
  def create
    @feedback = BetaFeedback.create!(
      message: params[:message],
      page: params[:page],
      clinic: current_clinic,
      user_agent: request.user_agent
    )
    
    redirect_back(fallback_location: root_path)
    flash[:notice] = 'フィードバックありがとうございます！'
  end
end
