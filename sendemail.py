from email.message import EmailMessage
import sys
import ssl
import smtplib

email_sender = 'my email' # Email wich will send the email
email_password = 'key' # Six-digit key for logining

def send_mail(subject, body, email_receiver):
	em = EmailMessage()
	em['From'] = email_sender
	em['To'] = email_receiver 
	em['Subject'] = subject
	em.set_content(body)
	
	context = ssl.create_default_context()

	with smtplib.SMTP('smtp.gmail.com', 587) as smtp:
		smtp.starttls(context=context)
		smtp.login(email_sender, email_password)
		smtp.sendmail(email_sender, email_receiver, em.as_string())


if __name__=="__main__":
	subject = sys.argv[1]
	body = sys.argv[2]
	email_receiver = sys.argv[3]
	send_mail(subject, body, email_receiver)
	 