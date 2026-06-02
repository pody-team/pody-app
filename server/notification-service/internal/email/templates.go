package email

import (
	"bytes"
	"fmt"
	htmltemplate "html/template"
	"text/template"
	"time"
)

var (
	verificationSubjectTemplate = template.Must(template.New("verification-subject").Parse("Verify your Pody account"))
	verificationTextTemplate    = template.Must(template.New("verification-text").Parse(
		`Hello {{.DisplayName}},

Please verify your Pody account by opening this link:
{{.ActionURL}}

This link expires at {{.ExpiresAt}}.
`))
	verificationHTMLTemplate = htmltemplate.Must(htmltemplate.New("verification-html").Parse(
		`<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;padding:24px;background:#0f1115;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#f5f7fa;">
    <div style="max-width:560px;margin:0 auto;background:#151922;border:1px solid #232a36;border-radius:18px;padding:32px;">
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Hello {{.DisplayName}},</p>
      <p style="margin:0 0 20px;font-size:16px;line-height:1.6;">Please verify your Pody account to finish setting things up.</p>
      <p style="margin:0 0 24px;">
        <a href="{{.ActionURL}}" style="display:inline-block;padding:14px 22px;background:#2dd4bf;color:#0b1020;text-decoration:none;font-weight:700;border-radius:12px;">Verify account</a>
      </p>
      <p style="margin:0 0 10px;font-size:14px;line-height:1.6;color:#c8d1dc;">If the button does not work, copy and open this link:</p>
      <p style="margin:0 0 20px;font-size:14px;line-height:1.7;word-break:break-all;"><a href="{{.ActionURL}}" style="color:#8be9de;text-decoration:underline;">{{.ActionURL}}</a></p>
      <p style="margin:0;font-size:13px;line-height:1.6;color:#98a2b3;">This link expires at {{.ExpiresAt}}.</p>
    </div>
  </body>
</html>`))

	passwordResetSubjectTemplate = template.Must(template.New("password-reset-subject").Parse("Reset your Pody password"))
	passwordResetTextTemplate    = template.Must(template.New("password-reset-text").Parse(
		`Hello {{.DisplayName}},

We received a request to reset your Pody password. Use this OTP code in the app to continue:
{{.OTPCode}}

If you did not request this change, you can ignore this email.
This OTP expires at {{.ExpiresAt}}.
`))
	passwordResetHTMLTemplate = htmltemplate.Must(htmltemplate.New("password-reset-html").Parse(
		`<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;padding:24px;background:#0f1115;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#f5f7fa;">
    <div style="max-width:560px;margin:0 auto;background:#151922;border:1px solid #232a36;border-radius:18px;padding:32px;">
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Hello {{.DisplayName}},</p>
      <p style="margin:0 0 20px;font-size:16px;line-height:1.6;">We received a request to reset your Pody password. Enter this OTP in the app to continue.</p>
      <p style="margin:0 0 24px;padding:16px 20px;background:#241824;border:1px solid #4b2436;border-radius:16px;font-size:30px;letter-spacing:0.32em;font-weight:800;text-align:center;color:#ffb4c8;">{{.OTPCode}}</p>
      <p style="margin:0 0 10px;font-size:14px;line-height:1.6;color:#c8d1dc;">Open Pody, choose a new password, then enter the OTP above.</p>
      <p style="margin:0 0 10px;font-size:13px;line-height:1.6;color:#98a2b3;">If you did not request this change, you can ignore this email.</p>
      <p style="margin:0;font-size:13px;line-height:1.6;color:#98a2b3;">This OTP expires at {{.ExpiresAt}}.</p>
    </div>
  </body>
</html>`))
)

type templateData struct {
	DisplayName string
	ActionURL   string
	OTPCode     string
	ExpiresAt   string
}

// RenderVerificationTemplate sinh subject, text và HTML cho email xác minh tài khoản.
func RenderVerificationTemplate(displayName, verificationURL string, expiresAt time.Time) (string, string, string, error) {
	return renderEmailTemplates(
		verificationSubjectTemplate,
		verificationTextTemplate,
		verificationHTMLTemplate,
		templateData{
			DisplayName: displayName,
			ActionURL:   verificationURL,
			ExpiresAt:   expiresAt.Format(time.RFC1123Z),
		},
	)
}

// RenderPasswordResetTemplate sinh subject, text và HTML cho email đặt lại mật khẩu.
func RenderPasswordResetTemplate(displayName, otpCode string, expiresAt time.Time) (string, string, string, error) {
	return renderEmailTemplates(
		passwordResetSubjectTemplate,
		passwordResetTextTemplate,
		passwordResetHTMLTemplate,
		templateData{
			DisplayName: displayName,
			OTPCode:     otpCode,
			ExpiresAt:   expiresAt.Format(time.RFC1123Z),
		},
	)
}

// renderEmailTemplates render đồng bộ 3 template (subject/text/html) từ cùng một dữ liệu.
func renderEmailTemplates(
	subjectTemplate *template.Template,
	textBodyTemplate *template.Template,
	htmlBodyTemplate *htmltemplate.Template,
	data templateData,
) (string, string, string, error) {
	var subjectBuffer bytes.Buffer
	if err := subjectTemplate.Execute(&subjectBuffer, data); err != nil {
		return "", "", "", fmt.Errorf("render email subject: %w", err)
	}

	var textBuffer bytes.Buffer
	if err := textBodyTemplate.Execute(&textBuffer, data); err != nil {
		return "", "", "", fmt.Errorf("render email text body: %w", err)
	}

	var htmlBuffer bytes.Buffer
	if err := htmlBodyTemplate.Execute(&htmlBuffer, data); err != nil {
		return "", "", "", fmt.Errorf("render email html body: %w", err)
	}

	return subjectBuffer.String(), textBuffer.String(), htmlBuffer.String(), nil
}
