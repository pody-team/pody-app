package domain

import "time"

type User struct {
	ID              string     `json:"id"`
	Email           string     `json:"email"`
	DisplayName     string     `json:"display_name"`
	Username        string     `json:"username,omitempty"`
	AvatarURL       string     `json:"avatar_url,omitempty"`
	Bio             string     `json:"bio"`
	AccountType     string     `json:"account_type"`
	Status          string     `json:"status"`
	Locale          string     `json:"locale"`
	Timezone        string     `json:"timezone"`
	EmailVerifiedAt *time.Time `json:"email_verified_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`
}

type Tokens struct {
	AccessToken           string    `json:"access_token"`
	AccessTokenExpiresAt  time.Time `json:"access_token_expires_at"`
	RefreshToken          string    `json:"refresh_token"`
	RefreshTokenExpiresAt time.Time `json:"refresh_token_expires_at"`
	TokenType             string    `json:"token_type"`
}

type AuthResponse struct {
	User   User   `json:"user"`
	Tokens Tokens `json:"tokens"`
}

type VerificationChallenge struct {
	Email                 string    `json:"email"`
	VerificationRequired  bool      `json:"verification_required"`
	VerificationSentAt    time.Time `json:"verification_sent_at"`
	VerificationExpiresAt time.Time `json:"verification_expires_at"`
	Message               string    `json:"message"`
}
