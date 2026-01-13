class ComplaintsMailer < ApplicationMailer
  def send_mail(to:, subject:, body:, from: nil, cc: nil, bcc: nil)
    @body = body

    mail(
      to: to,
      from: from,
      cc: cc,
      bcc: bcc,
      subject: subject
    )
  end
end
