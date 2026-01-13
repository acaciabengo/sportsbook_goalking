class Api::V1::ComplaintsController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token

  def create
    complaint = Complaint.new(complaint_params)    

    if complaint.save
      # Send email notification
      ComplaintsMailer.send_mail(
        to: ENV.fetch('COMPLAINTS_EMAIL', 'support@goalkings.com'),
        subject: complaint.subject,
        body: complaint_email_body(complaint)
      ).deliver_later

      render json: { message: 'Complaint submitted successfully', complaint_id: complaint.id }, status: :created
    else
      render json: { errors: complaint.errors.full_messages }, status: :unprocessable_entity
    end
  end


  def show
    complaint = Complaint.find_by(id: params[:id])

    if complaint
      render json: complaint.as_json(except: [:updated_at])
    else
      render json: { error: 'Complaint not found' }, status: :not_found
    end
  end

  private

  def complaint_params
    params.permit(
      :category,
      :sub_category,
      :bet_id,
      :betslip_id,
      :transaction_amount,
      :transaction_date,
      :subject,
      :description,
      :preferred_contact_method
    )
  end

  def complaint_email_body(complaint)
    <<~HTML
      <h2>New Complaint Received</h2>
      <p><strong>User ID:</strong> #{complaint.user_id}</p>
      <p><strong>Phone:</strong> #{complaint.user.phone_number}</p>
      <p><strong>Category:</strong> #{complaint.category}</p>
      <p><strong>Sub Category:</strong> #{complaint.sub_category}</p>
      <p><strong>Subject:</strong> #{complaint.subject}</p>
      <p><strong>Description:</strong> #{complaint.description}</p>
      <p><strong>Bet ID:</strong> #{complaint.bet_id}</p>
      <p><strong>Betslip ID:</strong> #{complaint.betslip_id}</p>
      <p><strong>Transaction Amount:</strong> #{complaint.transaction_amount}</p>
      <p><strong>Transaction Date:</strong> #{complaint.transaction_date}</p>
      <p><strong>Preferred Contact:</strong> #{complaint.preferred_contact_method}</p>
      <p><strong>Submitted At:</strong> #{complaint.created_at}</p>
    HTML
  end
end
