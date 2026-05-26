package domain

import "time"

// User đại diện cho thực thể người dùng trong hệ thống Pody.
type User struct {
	ID              string     `json:"id"`                         // ID duy nhất của người dùng
	Email           string     `json:"email"`                      // Địa chỉ email
	DisplayName     string     `json:"display_name"`               // Tên hiển thị công khai
	Username        string     `json:"username,omitempty"`         // Tên đăng nhập duy nhất
	AvatarURL       string     `json:"avatar_url,omitempty"`       // Đường dẫn ảnh đại diện
	Bio             string     `json:"bio"`                        // Mô tả tiểu sử bản thân
	AccountType     string     `json:"account_type"`               // Loại tài khoản (ví dụ: "standard", "google", v.v.)
	Status          string     `json:"status"`                     // Trạng thái tài khoản (ví dụ: "pending", "active", "suspended")
	Locale          string     `json:"locale"`                     // Ngôn ngữ cài đặt (ví dụ: "vi", "en")
	Timezone        string     `json:"timezone"`                   // Múi giờ
	EmailVerifiedAt *time.Time `json:"email_verified_at,omitempty"`// Thời điểm email được xác thực thành công
	CreatedAt       time.Time  `json:"created_at"`                 // Thời điểm tạo tài khoản
	UpdatedAt       time.Time  `json:"updated_at"`                 // Thời điểm cập nhật tài khoản gần nhất
}

// Tokens chứa thông tin về JWT Access Token và Refresh Token trả về cho client sau khi đăng nhập thành công.
type Tokens struct {
	AccessToken           string    `json:"access_token"`             // Token dùng để xác thực request gửi tới API Gateway
	AccessTokenExpiresAt  time.Time `json:"access_token_expires_at"`  // Hạn dùng của Access Token
	RefreshToken          string    `json:"refresh_token"`            // Token dùng để lấy Access Token mới mà không cần đăng nhập lại
	RefreshTokenExpiresAt time.Time `json:"refresh_token_expires_at"` // Hạn dùng của Refresh Token
	TokenType             string    `json:"token_type"`               // Loại token (mặc định: "Bearer")
}

// AuthResponse là payload trả về cho client khi đăng nhập/đăng ký thành công.
type AuthResponse struct {
	User   User   `json:"user"`   // Thông tin chi tiết người dùng
	Tokens Tokens `json:"tokens"` // Bộ đôi Access Token và Refresh Token
}

// VerificationChallenge lưu giữ trạng thái yêu cầu xác minh email.
type VerificationChallenge struct {
	Email                 string    `json:"email"`                   // Email cần xác thực
	VerificationRequired  bool      `json:"verification_required"`   // Cho biết tài khoản này có cần xác thực email hay không
	VerificationSentAt    time.Time `json:"verification_sent_at"`    // Thời gian đã gửi mail xác thực
	VerificationExpiresAt time.Time `json:"verification_expires_at"` // Thời gian token xác thực hết hạn
	Message               string    `json:"message"`                 // Thông điệp trả về cho client
}

// PasswordResetChallenge lưu giữ trạng thái yêu cầu đặt lại mật khẩu.
type PasswordResetChallenge struct {
	Email        string    `json:"email"`           // Email cần đổi mật khẩu
	Message      string    `json:"message"`         // Thông điệp gửi tới client
	OTPRequired  bool      `json:"otp_required"`    // Có yêu cầu mã OTP không
	OTPSentAt    time.Time `json:"otp_sent_at"`     // Thời gian đã gửi OTP
	OTPExpiresAt time.Time `json:"otp_expires_at"`  // Thời điểm mã OTP hết hạn
	OTPLength    int       `json:"otp_length"`      // Độ dài của mã OTP
}

